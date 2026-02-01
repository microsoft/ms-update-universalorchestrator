#
# Copyright (c) Microsoft Corporation.  All rights reserved.
#
# Version: 1.0.0.0
# Revision 2024.11.20
#

# Ensure that the command is run with Administrator privileges
function VerifyIsAdmin() {
    $principal = New-Object System.Security.Principal.WindowsPrincipal([System.Security.Principal.WindowsIdentity]::GetCurrent())
    if (!$principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw "The command must run with Administrator privileges."
    }
}

# Return true if OS is Server
function IsServer() {
    $editionID = (Get-ItemProperty 'hklm:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').EditionID
    $installationType = (Get-ItemProperty 'hklm:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').InstallationType
    return $editionID -like "*Server*" -or $installationType -eq "Server Core"
}

function Test-UpdaterRegistration {
    <#
    .SYNOPSIS
    Validates the JSON file created for updater registration.

    .DESCRIPTION
    The Test-UpdaterRegistration function verifies that the provided JSON file is valid.
    The function throws an error detailing the reason for the invalid JSON file.

    .PARAMETER UpdaterJsonPath
    Path to the updater JSON file.

    .EXAMPLE
    Test-UpdaterRegistration -UpdaterJsonPath "C:\path\to\updater_UpdaterName.json"

    .NOTES
    The function throws errors if the JSON file is malformed, missing required properties, or if the OS is a Server edition.
    #>

    [CmdletBinding()]
    param (
        [parameter(HelpMessage = 'Path to the updater JSON file.', Mandatory = $true, Position = 0)]
        [string]$UpdaterJsonPath
    )

    VerifyIsAdmin

    if (IsServer) {
        throw "App Expedition is not supported on Server Editions."
    }

    $properties = @{}
    foreach ($match in ([regex]::Matches((Get-Content -Path $UpdaterJsonPath -Raw), '"([^"]+)"\s*:'))) {
        if ($properties.ContainsKey($match.Groups[1].Value)) {
            throw "Duplicate property found: $($match.Groups[1].Value)"
        }
        $properties[$match.Groups[1].Value] = $true
    }

    try {
        $updaterMetadata = Get-Content -Path $UpdaterJsonPath -Raw | ConvertFrom-Json
    } catch {
        throw $_.Exception.Message
    }

    $supportedProperties = @(
        "PFN",
        "OEMName",
        "UpdaterName",
        "RegistrationVersion",
        "Source",
        "Endpoint",
        "ProductId",
        "Scenario",
        "AllowedInOobe",
        "MaxRetryCount",
        "TimeoutDurationInMinutes",
        "IncludedRegions",
        "ExcludedRegions",
        "IncludedEditions",
        "ExcludedEditions",
        "Architecture",
        "MinimumAllowedBuildVersion",
        "HonorDeprovisioning",
        "SkipIfPresent",
        "Priority"
    )

    foreach ($property in $supportedProperties) {
        if ($updaterMetadata.PSObject.Properties[$property] -and $updaterMetadata.PSObject.Properties[$property].Name -cne $property) {
            throw "The property '$($updaterMetadata.PSObject.Properties[$property].Name)' does not match the expected case-sensitive property name '$property'."
        }
    }

    if (-not ($updaterMetadata.PSObject.Properties["OEMName"] -and
            $updaterMetadata.PSObject.Properties["UpdaterName"] -and
            $updaterMetadata.PSObject.Properties["PFN"] -and
            $updaterMetadata.PSObject.Properties["RegistrationVersion"] -and
            $updaterMetadata.PSObject.Properties["Scenario"] -and
            $updaterMetadata.PSObject.Properties["Source"])) {
        throw "OEMName, UpdaterName, PFN, RegistrationVersion, Scenario and Source are required properties."
    }

    if (-not ($updaterMetadata.OEMName -is [String] -and
            $updaterMetadata.UpdaterName -is [String] -and
            $updaterMetadata.PFN -is [String] -and
            $updaterMetadata.RegistrationVersion -is [Int32] -or $updaterMetadata.RegistrationVersion -is [Int64])) {
        throw "OEMName, UpdaterName, and PFN need to be Strings. RegistrationVersion needs to be an Integer."
    }

    if ($updaterMetadata.OEMName -notmatch '^[a-zA-Z0-9_-]+$') {
        throw "OEMName can only contain alphanumeric characters, underscores, and hyphens."
    }

    if ($updaterMetadata.UpdaterName -notmatch '^[a-zA-Z0-9_-]+$') {
        throw "UpdaterName can only contain alphanumeric characters, underscores, and hyphens."
    }

    if ($updaterMetadata.RegistrationVersion -lt 1) {
        throw "RegistrationVersion must be greater than 0."
    }

    if ($updaterMetadata.Scenario -cnotin @("Update", "Acquisition", "StubAcquisition")) {
        throw "Scenario can only be 'Update', 'Acquisition', or 'StubAcquisition'. Ensure the casing is correct."
    }

    if ($updaterMetadata.Source -cnotin @("CustomURL", "Store")) {
        throw "Source can only be 'CustomURL' or 'Store'. Ensure the casing is correct."
    }

    if ($updaterMetadata.Source -ceq "CustomURL" -and -not $updaterMetadata.Endpoint) {
        throw "Endpoint needs to be specified for CustomURL source."
    }

    if ($updaterMetadata.Source -ceq "CustomURL" -and $updaterMetadata.Endpoint -cnotmatch '^https://') {
        throw "CustomURL must be an SSL URI that begins with 'https://'."
    }

    if ($updaterMetadata.Source -ceq "Store" -and -not $updaterMetadata.ProductId) {
        throw "Product ID needs to be specified for Store source."
    }

    if ($updaterMetadata.PSObject.Properties["MaxRetryCount"]) {
        if (-not (($updaterMetadata.MaxRetryCount -is [Int32] -or $updaterMetadata.MaxRetryCount -is [Int64]) -and
            ($updaterMetadata.MaxRetryCount -gt 0 -and $updaterMetadata.MaxRetryCount -lt 6))) {
            throw "MaxRetryCount needs to be an Integer between 1 and 5."
        }
    }

    if ($updaterMetadata.PSObject.Properties["TimeoutDurationInMinutes"]) {
        if (-not (($updaterMetadata.TimeoutDurationInMinutes -is [Int32] -or $updaterMetadata.TimeoutDurationInMinutes -is [Int64]) -and
            ($updaterMetadata.TimeoutDurationInMinutes -gt 0 -and $updaterMetadata.TimeoutDurationInMinutes -lt 31))) {
            throw "TimeoutDurationInMinutes needs to be an Integer between 1 and 30."
        }
    }

    if ($updaterMetadata.PSObject.Properties["IncludedRegions"] -and $updaterMetadata.PSObject.Properties["ExcludedRegions"]) {
        throw "IncludedRegions and ExcludedRegions cannot be specified together."
    }

    if ($updaterMetadata.PSObject.Properties["IncludedRegions"]) {
        if (-not ($updaterMetadata.IncludedRegions -is [Object[]] -and
                $updaterMetadata.IncludedRegions.Length -gt 0 -and
            ($updaterMetadata.IncludedRegions | ForEach-Object { $_ -is [String] }) -notcontains $false -and
            ($updaterMetadata.IncludedRegions | Select-Object -Unique).Count -eq $updaterMetadata.IncludedRegions.Length)) {
            throw "IncludedRegions needs to be a non-empty array of unique strings."
        }
    }

    if ($updaterMetadata.PSObject.Properties["ExcludedRegions"]) {
        if (-not ($updaterMetadata.ExcludedRegions -is [Object[]] -and
                $updaterMetadata.ExcludedRegions.Length -gt 0 -and
            ($updaterMetadata.ExcludedRegions | ForEach-Object { $_ -is [string] }) -notcontains $false -and
            ($updaterMetadata.ExcludedRegions | Select-Object -Unique).Count -eq $updaterMetadata.ExcludedRegions.Length)) {
            throw "ExcludedRegions needs to be a non-empty array of unique strings."
        }
    }

    if ($updaterMetadata.PSObject.Properties["IncludedEditions"] -and $updaterMetadata.PSObject.Properties["ExcludedEditions"]) {
        throw "IncludedEditions and ExcludedEditions cannot be specified together."
    }

    if ($updaterMetadata.PSObject.Properties["IncludedEditions"]) {
        if (-not ($updaterMetadata.IncludedEditions -is [Object[]] -and
                $updaterMetadata.IncludedEditions.Length -gt 0 -and
            ($updaterMetadata.IncludedEditions | ForEach-Object { $_ -is [Int32] -or $_ -is [Int64] }) -notcontains $false -and
            ($updaterMetadata.IncludedEditions | Select-Object -Unique).Count -eq $updaterMetadata.IncludedEditions.Length)) {
            throw "IncludedEditions needs to be a non-empty array of unique integers."
        }
    }

    if ($updaterMetadata.PSObject.Properties["ExcludedEditions"]) {
        if (-not ($updaterMetadata.ExcludedEditions -is [Object[]] -and
                $updaterMetadata.ExcludedEditions.Length -gt 0 -and
            ($updaterMetadata.ExcludedEditions | ForEach-Object { $_ -is [Int32] -or $_ -is [Int64] }) -notcontains $false -and
            ($updaterMetadata.ExcludedEditions | Select-Object -Unique).Count -eq $updaterMetadata.ExcludedEditions.Length)) {
            throw "ExcludedEditions needs to be a non-empty array of unique integers."
        }
    }

    if ($updaterMetadata.PSObject.Properties["Architecture"]) {
        if ($updaterMetadata.Architecture -cnotin @("amd64", "arm64")) {
            throw "Architecture can only be 'amd64' or 'arm64'. Ensure the casing is correct."
        }
    }

    if ($updaterMetadata.PSObject.Properties["MinimumAllowedBuildVersion"]) {
        if (-not (($updaterMetadata.MinimumAllowedBuildVersion -is [Int32] -or $updaterMetadata.MinimumAllowedBuildVersion -is [Int64]) -and
            ($updaterMetadata.MinimumAllowedBuildVersion -gt 0 -and $updaterMetadata.MinimumAllowedBuildVersion -lt 100001))) {
            throw "MinimumAllowedBuildVersion needs to be an Integer between 1 and 100,000."
        }
    }

    if ($updaterMetadata.PSObject.Properties["HonorDeprovisioning"]) {
        if ($updaterMetadata.HonorDeprovisioning -is [Boolean] -eq $false) {
            throw "HonorDeprovisioning needs to be a Boolean."
        }

        if ($updaterMetadata.HonorDeprovisioning -eq $true -and $updaterMetadata.Scenario -ceq "Update") {
            throw "HonorDeprovisioning can only be specified for the 'Acquisition' or 'StubAcquisition' scenario."
        }
    }

    if ($updaterMetadata.PSObject.Properties["SkipIfPresent"]) {
        if ($updaterMetadata.SkipIfPresent -is [Boolean] -eq $false) {
            throw "SkipIfPresent needs to be a Boolean."
        }
    }

    if ($updaterMetadata.PSObject.Properties["AllowedInOobe"]) {
        if ($updaterMetadata.AllowedInOobe -is [Boolean] -eq $false) {
            throw "AllowedInOobe needs to be a Boolean."
        }
    }

    if ($updaterMetadata.PSObject.Properties["Priority"]) {
        if (-not (($updaterMetadata.Priority -is [Int32] -or $updaterMetadata.Priority -is [Int64]) -and
            ($updaterMetadata.Priority -gt 0 -and $updaterMetadata.Priority -lt 101))) {
            throw "Priority needs to be an Integer between 1 and 100."
        }
    }

    Write-Output "Updater Registration is valid."
}

function Add-UpdaterRegistration {
    <#
    .SYNOPSIS
    Adds a new updater registration using a provided JSON file.

    .DESCRIPTION
    The Add-UpdaterRegistration function registers a new updater using the provided JSON file.

    .PARAMETER UpdaterJsonPath
    Path to the updater JSON file.

    .EXAMPLE
    Add-UpdaterRegistration -UpdaterJsonPath "C:\path\to\updater_UpdaterName.json"

    .NOTES
    The function throws errors if the JSON file provided is invalid or if the registration store does not exist.
    #>

    [CmdletBinding()]
    param (
        [parameter(HelpMessage = 'Path to the updater JSON file.', Mandatory = $true, Position = 0)]
        [string]$UpdaterJsonPath
    )

    Write-Warning "Exercise caution when opting to expedite apps via this framework, as the update operations occur when the device may be in use and can cause a negative performance impact of the user experience on a new device."

    VerifyIsAdmin

    if (IsServer) {
        throw "App Expedition is not supported on Server Editions."
    }

    $manifestedUpdaterPath = Join-Path -Path ([System.Environment]::GetFolderPath('CommonApplicationData')) -ChildPath "USOPrivate\ExpeditedAppRegistrations"

    if (-not (Test-Path $manifestedUpdaterPath)) {
        throw "$manifestedUpdaterPath does not exist."
    }

    if (Test-UpdaterRegistration -UpdaterJsonPath $UpdaterJsonPath) {
        $updateMetadataJson = Get-Content -Path $UpdaterJsonPath -Raw | ConvertFrom-Json
        $oemName = $updateMetadataJson.OEMName.ToLower()
        $updaterName = $updateMetadataJson.UpdaterName.ToLower()

        $existingRegistration = Get-ChildItem -Path $manifestedUpdaterPath -Directory | Where-Object { $_.Name -eq "${oemName}_${updaterName}" }
        if ($existingRegistration) {
            throw "An updater for OEMName:$oemName and UpdaterName:$updaterName already exists."
        }

        $uschedulerOobeRegistryPath = "HKLM\SOFTWARE\Microsoft\WindowsUpdate\Orchestrator\UScheduler_Oobe"
        $regQueryResult = Invoke-Expression "reg query $uschedulerOobeRegistryPath"
        $regQueryResult | ForEach-Object {
            if ($_ -match "\\([^\\]+)$" -and $matches[1] -eq "${oemName}_${updaterName}") {
                throw "An updater for OEMName:$oemName and UpdaterName:$updaterName already exists."
            }
        }

        $manifestedUpdaterPath = Join-Path -Path $manifestedUpdaterPath -ChildPath "${oemName}_${updaterName}"
        New-Item -Path $manifestedUpdaterPath -ItemType Directory -Force

        $manifestedUpdaterFilePath = Join-Path -Path $manifestedUpdaterPath -ChildPath (Split-Path -Path $UpdaterJsonPath -Leaf)
        Copy-Item -Path $UpdaterJsonPath -Destination $manifestedUpdaterFilePath -Force

        $updaterJsonFilePath = Join-Path -Path $manifestedUpdaterPath -ChildPath "updater_${updaterName}.json"
        Rename-Item -Path $manifestedUpdaterFilePath -NewName $updaterJsonFilePath -Force

        Get-UpdaterRegistration -oemName $oemName -updaterName $updaterName
    } else {
        Write-Error "The JSON file is not valid. Please verify the JSON file and try again."
    }
}

function Get-UpdaterRegistration {
    <#
    .SYNOPSIS
    Retrieves the details of updater registrations.

    .DESCRIPTION
    The Get-UpdaterRegistration function retrieves the details of an updater registration using the provided OEMName and UpdaterName.
    In case the OEMName and UpdaterName are not provided, the function retrieves the details of all available updater registrations on the device.

    .PARAMETER OEMName
    The name of the OEM to retrieve.

    .PARAMETER UpdaterName
    The name of the updater to retrieve.

    .EXAMPLE
    Get-UpdaterRegistration -OEMName "MS" -UpdaterName "Contoso"
    This command retrieves the details for the updater registration with name "MS_Contoso".

    Get-UpdaterRegistration
    This command retrieves the details for all available updater registrations on the device.

    .NOTES
    The function throws if an error occurs while retrieving the registration summary.
    #>
    [CmdletBinding()]
    param (
        [Parameter(HelpMessage = 'The name of the OEM', Mandatory = $false, Position = 0)]
        [string]$OEMName,
        [Parameter(HelpMessage = 'The name of the updater', Mandatory = $false, Position = 1)]
        [string]$UpdaterName
    )

    VerifyIsAdmin

    if (IsServer) {
        throw "App Expedition is not supported on Server Editions."
    }

    if (($OEMName -and -not $UpdaterName) -or ($UpdaterName -and -not $OEMName)) {
        throw "Both OEMName and UpdaterName must be specified together."
    }

    $manifestedUpdaterPath = Join-Path -Path ([System.Environment]::GetFolderPath('CommonApplicationData')) -ChildPath "USOPrivate\ExpeditedAppRegistrations"

    if (-not (Test-Path $manifestedUpdaterPath)) {
        throw "$manifestedUpdaterPath does not exist."
    }

    if (-not $OEMName -and -not $UpdaterName) {
        try {
            $manifestedUpdaters = Get-ChildItem -Path $manifestedUpdaterPath -Recurse -Filter "*.json" -File -ErrorAction Stop
            $manifestedUpdaters = $manifestedUpdaters | Where-Object { $_.DirectoryName -ne $manifestedUpdaterPath }
            $manifestedUpdaters | ForEach-Object {
                try {
                    Set-UpdaterRegistrationObject -updaterJsonPath $_.FullName
                } catch {
                    throw "An error occurred while retrieving the registration summary."
                }
            }
        } catch {
            throw "An error occurred while retrieving the registration summary."
        }
        return
    }

    $updaterJsonPath = Join-Path -Path $manifestedUpdaterPath -ChildPath "${OEMName}_${UpdaterName}\updater_${UpdaterName}.json"
    if (-not (Test-Path $updaterJsonPath)) {
        throw "Updater registration for OEMName:$OEMName and UpdaterName:$UpdaterName does not exist."
    }

    Set-UpdaterRegistrationObject -updaterJsonPath $updaterJsonPath
}

function Set-UpdaterRegistrationObject {
    [CmdletBinding()]
    param (
        [parameter(HelpMessage = 'Path to the updater JSON file.', Mandatory = $true, Position = 0)]
        [string]$UpdaterJsonPath
    )

    try {
        $updateMetadataJson = Get-Content -Path $updaterJsonPath -Raw | ConvertFrom-Json

        $updaterRegistrationSummary = [PSCustomObject]@{
            OEMName                    = $updateMetadataJson.OEMName
            UpdaterName                = $updateMetadataJson.UpdaterName
            PFN                        = $updateMetadataJson.PFN
            RegistrationVersion        = $updateMetadataJson.RegistrationVersion
            Source                     = $updateMetadataJson.Source
            Scenario                   = $updateMetadataJson.Scenario
            Endpoint                   = if ($updateMetadataJson.Source -eq "CustomURL") { $updateMetadataJson.Endpoint } else { $null }
            ProductId                  = if ($updateMetadataJson.Source -eq "Store") { $updateMetadataJson.ProductId } else { $null }
            MaxRetryCount              = if ($updateMetadataJson.PSObject.Properties["MaxRetryCount"]) { $updateMetadataJson.MaxRetryCount } else { $null }
            TimeoutDurationInMinutes   = if ($updateMetadataJson.PSObject.Properties["TimeoutDurationInMinutes"]) { $updateMetadataJson.TimeoutDurationInMinutes } else { $null }
            AllowedInOobe              = if ($updateMetadataJson.PSObject.Properties["AllowedInOobe"]) { $updateMetadataJson.AllowedInOobe } else { $null }
            IncludedRegions            = if ($updateMetadataJson.PSObject.Properties["IncludedRegions"]) { $updateMetadataJson.IncludedRegions } else { $null }
            ExcludedRegions            = if ($updateMetadataJson.PSObject.Properties["ExcludedRegions"]) { $updateMetadataJson.ExcludedRegions } else { $null }
            IncludedEditions           = if ($updateMetadataJson.PSObject.Properties["IncludedEditions"]) { $updateMetadataJson.IncludedEditions } else { $null }
            ExcludedEditions           = if ($updateMetadataJson.PSObject.Properties["ExcludedEditions"]) { $updateMetadataJson.ExcludedEditions } else { $null }
            Architecture               = if ($updateMetadataJson.PSObject.Properties["Architecture"]) { $updateMetadataJson.Architecture } else { $null }
            MinimumAllowedBuildVersion = if ($updateMetadataJson.PSObject.Properties["MinimumAllowedBuildVersion"]) { $updateMetadataJson.MinimumAllowedBuildVersion } else { $null }
            HonorDeprovisioning        = if ($updateMetadataJson.PSObject.Properties["HonorDeprovisioning"]) { $updateMetadataJson.HonorDeprovisioning } else { $null }
            SkipIfPresent              = if ($updateMetadataJson.PSObject.Properties["SkipIfPresent"]) { $updateMetadataJson.SkipIfPresent } else { $null }
            Priority                   = if ($updateMetadataJson.PSObject.Properties["Priority"]) { $updateMetadataJson.Priority } else { $null }
        }
        Write-Output $updaterRegistrationSummary
    } catch {
        throw "An error occurred while retrieving the registration summary."
    }
}

function Remove-UpdaterRegistration {
    <#
    .SYNOPSIS
    Removes an existing updater registration.

    .DESCRIPTION
    The Remove-UpdaterRegistration function removes an existing updater registration using the provided OEM nam and updater name.

    .PARAMETER OEMName
    The name of the OEM.

    .PARAMETER UpdaterName
    The name of the updater to remove.

    .EXAMPLE
    Remove-UpdaterRegistration -OEMName "MS" -UpdaterName "Contoso"
    This command removes the updater registration with the name "MS_Contoso".

    .NOTES
    The function throws errors if the Updater is not found.
    #>

    [CmdletBinding()]
    param (
        [Parameter(HelpMessage = 'The name of the OEM', Mandatory = $true, Position = 0)]
        [string]$OEMName,
        [Parameter(HelpMessage = 'The name of the updater', Mandatory = $true, Position = 1)]
        [string]$UpdaterName
    )

    VerifyIsAdmin

    if (IsServer) {
        throw "App Expedition is not supported on Server Editions."
    }

    $manifestedUpdaterPath = Join-Path -Path ([System.Environment]::GetFolderPath('CommonApplicationData')) -ChildPath "USOPrivate\ExpeditedAppRegistrations"

    if (-not (Test-Path $manifestedUpdaterPath)) {
        throw "$manifestedUpdaterPath does not exist."
    }

    $manifestedUpdaterFolderPath = Join-Path -Path $manifestedUpdaterPath -ChildPath "${OEMName}_${UpdaterName}"
    if (-not (Test-Path $manifestedUpdaterFolderPath)) {
        throw "Updater registration for OEMName:$OEMName and UpdaterName:$UpdaterName does not exist."
    }

    Remove-Item -Path $manifestedUpdaterFolderPath -Recurse -Force -ErrorAction Stop
    Write-Output "Updater registration for OEMName:$OEMName and UpdaterName:$UpdaterName has been removed successfully."
}
