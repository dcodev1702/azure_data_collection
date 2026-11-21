[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$ErrorActionPreference = 'Stop'
$repo = (Resolve-Path $RepositoryRoot).Path
$failures = [System.Collections.Generic.List[string]]::new()

function Add-Failure {
    param([string]$Message)
    $failures.Add($Message)
    Write-Host "FAIL: $Message" -ForegroundColor Red
}

function Test-JsonFile {
    param([System.IO.FileInfo]$File)
    try {
        Get-Content -Path $File.FullName -Raw | ConvertFrom-Json -Depth 100 -ErrorAction Stop | Out-Null
    } catch {
        Add-Failure "Invalid JSON in $($File.FullName): $($_.Exception.Message)"
    }
}

Write-Host 'Validating JSON and ARM files...' -ForegroundColor Cyan
Get-ChildItem -Path $repo -Recurse -File -Filter '*.json' |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' } |
    ForEach-Object { Test-JsonFile -File $_ }

Write-Host 'Parsing and inspecting PowerShell files with the built-in AST...' -ForegroundColor Cyan
Get-ChildItem -Path $repo -Recurse -File -Filter '*.ps1' |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' } |
    ForEach-Object {
        $tokens = $null
        $errors = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors)
        foreach ($parseError in $errors) {
            Add-Failure "PowerShell parse error in $($_.FullName): $($parseError.Message)"
        }

        $unsafeCommands = $ast.FindAll(
            {
                param($node)
                $node -is [System.Management.Automation.Language.CommandAst] -and
                $node.GetCommandName() -in @('Invoke-Expression', 'iex')
            },
            $true
        )
        if ($unsafeCommands.Count -gt 0) {
            Add-Failure "Unsafe dynamic command invocation found in '$($_.FullName)'."
        }
    }

Write-Host 'Validating NDJSON fixtures...' -ForegroundColor Cyan
Get-ChildItem -Path (Join-Path $repo 'data/ndjson') -File -Filter '*.ndjson' | ForEach-Object {
    $bytes = [System.IO.File]::ReadAllBytes($_.FullName)
    if ($bytes.Length -eq 0 -or $bytes[-1] -ne 10) {
        Add-Failure "NDJSON file '$($_.FullName)' must end with a newline."
    }
    $lineNumber = 0
    foreach ($line in Get-Content -Path $_.FullName) {
        $lineNumber++
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        try {
            $line | ConvertFrom-Json -Depth 100 -ErrorAction Stop | Out-Null
        } catch {
            Add-Failure "Invalid NDJSON '$($_.FullName)' line ${lineNumber}: $($_.Exception.Message)"
        }
    }
}

Write-Host 'Checking local Markdown links...' -ForegroundColor Cyan
Get-ChildItem -Path $repo -Recurse -File -Filter '*.md' |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' } |
    ForEach-Object {
        $content = Get-Content -Path $_.FullName -Raw
        $matches = [regex]::Matches($content, '(?<!\!)\[[^\]]+\]\((?<target>[^)]+)\)')
        foreach ($match in $matches) {
            $target = $match.Groups['target'].Value.Trim()
            if ($target -match '^(https?:|mailto:|#)') {
                continue
            }
            $target = $target.Split('#')[0]
            if (-not $target) {
                continue
            }
            $target = [uri]::UnescapeDataString($target.Trim('<>').Replace('/', [IO.Path]::DirectorySeparatorChar))
            $resolved = Join-Path $_.DirectoryName $target
            if (-not (Test-Path $resolved)) {
                Add-Failure "Broken local link in '$($_.FullName)': $target"
            }
        }
    }

Write-Host 'Checking curriculum contracts...' -ForegroundColor Cyan
$forbidden = @(
    @{ Pattern = '\*\*\*\*\*\*'; Description = 'masked authorization header' },
    @{ Pattern = 'ENTER YOUR APP (ID|SECRET) HERE'; Description = 'credential placeholder' },
    @{ Pattern = 'mde_data[\\/]dummy_data'; Description = 'obsolete data path' },
    @{ Pattern = 'send_data_to_loga\.ps1'; Description = 'obsolete script name' },
    @{ Pattern = 'project-rename threatTitle'; Description = 'case-mismatched ThreatTitle transform' }
)
$sourceFiles = Get-ChildItem -Path $repo -Recurse -File |
    Where-Object {
        $_.Extension -in '.ps1', '.md', '.json', '.kql', '.sh' -and
        $_.FullName -notmatch '[\\/]\.git[\\/]' -and
        $_.Name -ne 'validate-repository.ps1'
    }
foreach ($file in $sourceFiles) {
    $content = Get-Content -Path $file.FullName -Raw
    foreach ($rule in $forbidden) {
        if ($content -cmatch $rule.Pattern) {
            Add-Failure "$($rule.Description) found in '$($file.FullName)'."
        }
    }
}

Get-ChildItem -Path $repo -Recurse -File -Filter '*.json' |
    Where-Object { $_.FullName -notmatch '[\\/]\.git[\\/]' } |
    ForEach-Object {
        $document = Get-Content $_.FullName -Raw | ConvertFrom-Json -Depth 100
        $resources = @($document.resources)
        foreach ($resource in $resources) {
            if ($resource.type -ne 'Microsoft.Insights/dataCollectionRules') {
                continue
            }
            if ($resource.kind -eq 'Direct' -and $resource.properties.dataCollectionEndpointId) {
                Add-Failure "Direct DCR '$($_.FullName)' unexpectedly references a DCE."
            }
        }
    }

$directTemplate = Get-Content (Join-Path $repo 'data_collection_rules/ARM Templates/DCR_Kind-Direct.json') -Raw | ConvertFrom-Json -Depth 100
if (-not $directTemplate.resources[0].properties.streamDeclarations) {
    Add-Failure 'The Direct DCR template is missing streamDeclarations.'
}

$canonicalTable = Get-Content (Join-Path $repo 'labs/01-direct-ingestion/deploy-lab.ps1') -Raw
foreach ($column in @('TimeGenerated', 'Name', 'Source', 'Hardware', 'Distro')) {
    if ($canonicalTable -notmatch [regex]::Escape($column)) {
        Add-Failure "Canonical lab is missing expected column '$column'."
    }
}

if ($failures.Count -gt 0) {
    throw "$($failures.Count) repository validation failure(s) found."
}

Write-Host 'Repository validation passed.' -ForegroundColor Green
