[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [uri]$LogsIngestionEndpoint,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$DcrImmutableId,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$StreamName,

    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ -PathType Leaf })]
    [string]$DataFile,

    [ValidateRange(1, 1000)]
    [int]$BatchSize = 100,

    [ValidateRange(1, 8)]
    [int]$MaxAttempts = 4,

    [ValidateRange(1, 60)]
    [int]$RetryDelaySeconds = 2
)

$ErrorActionPreference = 'Stop'

if (-not (Get-AzContext -ErrorAction SilentlyContinue)) {
    throw 'Connect-AzAccount before sending data.'
}

$raw = Get-Content -Path $DataFile -Raw
$records = try {
    $parsed = $raw | ConvertFrom-Json -Depth 100 -ErrorAction Stop
    if ($parsed -is [System.Array]) {
        @($parsed)
    } else {
        @($parsed)
    }
} catch {
    $lines = Get-Content -Path $DataFile | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    @(
        for ($lineNumber = 0; $lineNumber -lt $lines.Count; $lineNumber++) {
            try {
                $lines[$lineNumber] | ConvertFrom-Json -Depth 100 -ErrorAction Stop
            } catch {
                throw "Invalid NDJSON at line $($lineNumber + 1): $($_.Exception.Message)"
            }
        }
    )
}

if ($records.Count -eq 0) {
    throw "The data file '$DataFile' contains no records."
}

$token = (Get-AzAccessToken -ResourceUrl 'https://monitor.azure.com/' -AsSecureString).Token
$tokenText = if ($token -is [System.Security.SecureString]) {
    [System.Net.NetworkCredential]::new('', $token).Password
} else {
    [string]$token
}

$endpoint = $LogsIngestionEndpoint.AbsoluteUri.TrimEnd('/')
$streamUri = "$endpoint/dataCollectionRules/$DcrImmutableId/streams/$StreamName`?api-version=2023-01-01"
$headers = @{
    Authorization = "Bearer $tokenText"
    'Content-Type' = 'application/json'
}

for ($offset = 0; $offset -lt $records.Count; $offset += $BatchSize) {
    $count = [Math]::Min($BatchSize, $records.Count - $offset)
    $batch = @($records[$offset..($offset + $count - 1)])
    $body = ConvertTo-Json -InputObject $batch -Depth 100 -Compress
    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        $statusCode = 0
        try {
            $result = Invoke-RestMethod -Uri $streamUri -Method POST -Headers $headers -Body $body -SkipHttpErrorCheck -StatusCodeVariable statusCode
        } catch {
            if ($attempt -eq $MaxAttempts) {
                throw "Batch beginning at record $offset failed after $MaxAttempts attempts: $($_.Exception.Message)"
            }
            Start-Sleep -Seconds ($RetryDelaySeconds * $attempt)
            continue
        }

        if ($statusCode -in 200, 202, 204) {
            break
        }
        $transient = $statusCode -eq 429 -or $statusCode -ge 500
        if (-not $transient -or $attempt -eq $MaxAttempts) {
            throw "Batch beginning at record $offset failed with HTTP ${statusCode}: $result"
        }
        Start-Sleep -Seconds ($RetryDelaySeconds * $attempt)
    }
    Write-Host "Uploaded $count record(s), starting at offset $offset." -ForegroundColor Green
}
