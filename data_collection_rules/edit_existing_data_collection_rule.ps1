<#####################################################################################
LEGAL DISCLAIMER
This Sample Code is provided for the purpose of illustration only and is not
intended to be used in a production environment.  THIS SAMPLE CODE AND ANY
RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF
MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.  We grant You a
nonexclusive, royalty-free right to use and modify the Sample Code and to
reproduce and distribute the object code form of the Sample Code, provided
that You agree: (i) to not use Our name, logo, or trademarks to market Your
software product in which the Sample Code is embedded; (ii) to include a valid
copyright notice on Your software product in which the Sample Code is embedded;
and (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and
against any claims or lawsuits, including attorneys’ fees, that arise or result
from the use or distribution of the Sample Code.
 
This posting is provided "AS IS" with no warranties, and confers no rights. Use
of included script samples are subject to the terms specified
at https://www.microsoft.com/en-us/legal/copyright.

#####################################################################################>

<#
Author: DCODev, GitHub Co-Pilot, and ChatGPT-4
Date: 4 June 2023
Filename: automated_modify_dcr.ps1

CmdLet:
--------
Invoke-DCRModify -DCR_Action [Get|Set]

Usage:
------
1. Bring the custom defined CmdLet into the PowerShell Host
   . ./automated_modify_dcr.ps1

2. Get a Data Collection Rule via Azure Monitor REST API
   Invoke-DCRModify -DCR_Action Get

3. Use your editor of choice to modify the Data Collection Rule (JSON)

4. Send a Data Collection Rule via Azure Monitor REST API
   Invoke-DCRModify -DCR_Action Set

End-State:
----------
Automate (ish) the getting and setting of Data Collection Rules so they can be
modified appropriately.  That is all this script aims to accomplish. This script does not
create new DCRs, it does not delete DCRs, and it does not associate DCRs with Resources.

Pre-Condition:
---------------
1. Azure PS Modules are installed or you're in the Cloud Shell (PowerShell)
2. Your Cloud Environment is set to the appropriate cloud (AzureCloud or AzureUSGovernment)
3. Log in to your Azure tenant with the necessary permissions
   Connect-AzAccount -UseDeviceAuthentication -Environment <Your Cloud Env>

Assumptions:
------------
Data Collection Rule names take on the name of their corresponding JSON file. If you change
the name of that JSON file, this script will NOT work as intended.  The assumption is made
that you make the necessary changes to the JSON file that resembles the name of the DCR
downloaded from Azure Monitor via the REST API.

TODO:
-----
Very little exception handling exists.  This is a down and dirty PowerShell script designed
to get the job done using GET or SET options supplied to the CmdLet (Invoke-DCRModify). This
script has been slightly refactored, however there is still lot of duplicate code and 
I'm sure, plenty of bugs :|

The intent of the script is to allow you to modify a Data Collection Rule (DCR) that reside
in Azure Monitor via the REST API. That's pretty much the gist of it.
#>

function Invoke-DCRModify {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("Get","Set")]
        [string]$DCR_Action
    )

    
    Begin {

        [string]$resourceGroup = $null
        [string]$DCRName = $null
        $dataCollectionRule = $null

        Write-Host "Welcome to Invoke-DCRModify for your Data Collection Rules (DCR)!" -ForegroundColor Green
        Write-Host "You passed in $DCR_Action`n" -ForegroundColor Green

        # Get the collection of Data Collection Rules
        $dataCollectionRules = (Get-AzDataCollectionRule -WarningAction SilentlyContinue)
        
        # Calculate the length of the highest index for padding purposes
        $idxLen = $dataCollectionRules.Count.ToString().Length

        if ($DCR_Action.ToLower() -eq 'get') {
            
            # Display the resource groups with their index
            for ($i=0; $i -lt $dataCollectionRules.Count; $i++) {

                # Write-Host "$i  $($resourceGroups[$i])"
                $indexFormattedDCRs = "{0,$idxLen} -> {1}" -f $i, $dataCollectionRules[$i].Name
                Write-Host $indexFormattedDCRs
            }

            Write-Host ""
            # Prompt the user to enter an index
            try {
                $index = Read-Host -Prompt 'Enter the index of the Data Collection Rule (DCR) you want to select'
                
                if ($index.Trim() -eq "") {
                    throw "Invalid index entered. Exiting program..."
                }
                $index = [int]$index.Trim()
            }
            catch [System.FormatException] {
                Write-Host "`nInvalid index entered `"$index`". Exiting script." -ForegroundColor Red
                exit 1
            }
            catch {
                Write-Host "An unexpected error occurred: $_" -ForegroundColor Red
                exit 1
            }
            
            # Check if the entered index is valid
            if ($index -ge 0 -and $index -lt $dataCollectionRules.Count) {
                $dataCollectionRule = $dataCollectionRules[$index]
                $DCRName = $dataCollectionRule.Name
            }else{
                Write-Host "Invalid index entered.  Exiting script." -ForegroundColor Red
                Exit
            }
        }

        if ($DCR_Action.ToLower() -eq 'set') {

            $DCRJsonFiles = (Get-ChildItem -Path .\ -Filter *.json).Name

            $idxLen = $DCRJsonFiles.Count.ToString().Length
            
            # List JSON Files by index and prompt user to select an index
            if ($DCRJsonFiles.Count -gt 1) {
                Write-Host "The following JSON files were found in the current directory:" -ForegroundColor Green
                
                for ($i=0; $i -lt $DCRJsonFiles.Count; $i++) {

                    $indexFormattedDCRJsonFiles = "{0,$idxLen} -> {1}" -f $i, $DCRJsonFiles[$i]
                    Write-Host $indexFormattedDCRJsonFiles
                }
            }else{
                $indexFormattedDCRJsonFiles = "0 -> {0}" -f $DCRJsonFiles
                Write-Host $indexFormattedDCRJsonFiles
            }
           
            # Prompt the user to enter an index
            try {
                $index = Read-Host -Prompt 'Enter the index of the modified DCR you want to send to Azure Monitor'
                
                if ($index.Trim() -eq "") {
                    throw "Invalid index entered. Exiting program..."
                }
                $index = [int]$index.Trim()
            }
            catch [System.FormatException] {
                Write-Host "`nInvalid index entered `"$index`". Exiting script." -ForegroundColor Red
                exit 1
            }
            catch {
                Write-Host "An unexpected error occurred: $_" -ForegroundColor Red
                exit 1
            }

            # Check if the entered index is valid
            if ($index -ge 0 -and $index -lt $DCRJsonFiles.Count) {
                if ($DCRJsonFiles.Count -gt 1) {
                    $DCRJsonFile = $DCRJsonFiles[$index]
                }else{
                    $DCRJsonFile = $DCRJsonFiles
                }
                $UserSelectedDCR = (Get-Item $DCRJsonFile).BaseName
            }else{
                Write-Host "Invalid index entered.  Exiting script." -ForegroundColor Red
                Exit
            }

            # Display the resource groups with their index
            for ($i=0; $i -lt $dataCollectionRules.Count; $i++) {

                if ($dataCollectionRules[$i].Name -eq $UserSelectedDCR) {
                    $dataCollectionRule = $dataCollectionRules[$i]
                    $DCRName = $dataCollectionRules[$i].Name
                    break
                }
            }
        }
    }

    Process {
    
        # Setting up REST API call to Azure Monitor to modify the DCR
        $resourceUrl    = (Get-AzContext).Environment.ResourceManagerUrl
        $subscriptionId = (Get-AzContext).Subscription.Id
        
        # Get the access token
        $token = (Get-AzAccessToken -ResourceUrl $resourceUrl).Token
        $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
        $headers.Add("Authorization","Bearer $token")
        
        # Parse the Resource Group from the DCR Resource Id
        $resourceGroup = ($dataCollectionRule.Id -split '/')[4]

        # Output the resource group
        if ($resourceGroup) {
            Write-Host "Resource Group : $resourceGroup" -ForegroundColor Green
        }

        if ($dataCollectionRule) {
            Write-Host "Data Collection Rule : $DCRName`n" -ForegroundColor Green
        }

        if ($DCR_Action.ToLower() -eq 'get') {

            # Construct the URL for the REST API call
            $url_DCRRule = "$resourceUrl/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Insights/dataCollectionRules/$($DCRName)"
            
            $confirm = Read-Host "Do you want to GET Data Collection Rule: `'$DCRName`' via Azure Monitor REST API? (Y/N)"
            
            if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                $GOT_DCRContent = Invoke-RestMethod ($url_DCRRule+"?api-version=2022-06-01") -Method GET -Headers $headers
                Start-Sleep 0.5

                if ($GOT_DCRContent) {
                    ConvertTo-JSON -Depth 64 -InputObject $GOT_DCRContent | Out-File "$DCRName.json"
                
                    Write-Host "`nDCR REST API call to Azure Monitor for `'$DCRName`' was successful!`n" -ForegroundColor Green
                    Write-Host "Your DCR `'$DCRName`' is now ready to be modified -> $DCRName.json" -ForegroundColor Yellow
                    Write-Host "Upon completion, you can run Invoke-DCRModify with the `"-DCR_Action Set`" option." -ForegroundColor Yellow
                } else {
                    Write-Host "DCR REST API call to Azure Monitor for $DCRName returned empty (null)" -ForegroundColor Red
                }
            } else {
                Write-Host "DCR REST API call to Azure Monitor for $DCRName was cancelled by the user." -ForegroundColor Red
            }
        }

        if ($DCR_Action.ToLower() -eq 'set') {

            # Copy the deserialized JSON DCR to a variable
            $DCRContent = Get-Content ./"$DCRJsonFile" -Raw

            Write-Host "Your modified DCR: $DCRName.json, is now ready to be sent via Azure REST API!`n" -ForegroundColor Yellow
            $confirm = Read-Host "Do you want to send `'$DCRName`' to Azure Monitor via a REST API (PUT)? (Y/N)"

            # Construct the URL for the REST API call
            $url_DCRRule = "$resourceUrl/subscriptions/$subscriptionId/resourceGroups/$resourceGroup/providers/Microsoft.Insights/dataCollectionRules/$($DCRName)"

            if ($confirm -eq 'Y' -or $confirm -eq 'y') {
                $result = Invoke-AzRestMethod ($url_DCRRule+"?api-version=2022-06-01") -Method PUT -Payload $DCRContent
                Start-Sleep 0.5

                # Validate the REST API call was successful ($result)
                if ($result.StatusCode -eq 200) {
                    Write-Host "`nREST API [PUT] to Azure Monitor for `'$DCRName`' completed successfully!" -ForegroundColor Green
                    Write-Host "You can now go to Azure Monitor -> DCR and validate the modification of: $DCRName." -ForegroundColor Green
                } else {
                    Write-Host "`nPUT via REST API call for $DCRName failed!" -ForegroundColor Red
                    Write-Host "Error Message: $($result.Content.message)" -ForegroundColor Red
                }
            } else {
                Write-Host "DCR REST API call to Azure Monitor for $DCRName was cancelled by the user." -ForegroundColor Red
            }
        }      
    }
    
    End {}
}
