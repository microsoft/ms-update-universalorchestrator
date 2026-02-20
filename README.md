# AppOrchestration Powershell Module

#### Table of Contents

*   [Overview](#overview)
*   [Prerequisites](#Prerequisites)
*   [Installation](#installation)
*   [Metadata](#metadata)
*   [Cmdlets](#cmdlets)
*   [Contributing](#contributing)
*   [Trademarks](#trademarks)
*   [License](#license)

## Overview
The `AppOrchestration` PowerShell module provides a set of cmdlets to manage the validation and registration of applications to be expedited through the [Windows Update Universal Orchestrator framework](https://learn.microsoft.com/en-us/windows/win32/updateorchestrator/#expediting-oem-apps-via-universal-orchestrator-framework).
The module includes the following cmdlets:
- [Test-UpdaterRegistration](#Test-UpdaterRegistration)
- [Add-UpdaterRegistration](#Add-UpdaterRegistration)
- [Get-UpdaterRegistration](#Get-UpdaterRegistration)
- [Remove-UpdaterRegistration](#Remove-UpdaterRegistration)

> **_NOTE:_**  **Exercise caution when opting to expedite apps via this framework, as the update operations occur when the device may be in use and can cause a negative performance impact of the user experience on a new device.**

## Prerequisites
Cmdlets need to be executed from an `Admin` privilege powershell window.

## Installation
```
Import-Module -Name 'path\to\scripts\AppOrchestration.psd1' -Force
```

## Metadata
In order to register with the Universal Orchestrator framework to have your application expedited, create a JSON file with application metadata. The following table contains a list of the properties that can be specified in the JSON file:

| Property                  | Description                                                                                                 | State                           | Type      | Enum Values                              | Default Value | Min Value | Max Value | Additional Constraints                                                     |
| ------------------------- | ----------------------------------------------------------------------------------------------------------- | ------------------------------- | --------- | ---------------------------------------- | ------------- | --------- | --------- | -------------------------------------------------------------------------- |
| PFN                       | The Package Family Name of the app.                                                                         | Required                        | String    |                                          |               |           |           |                                                                            |
| OEMName                   | The OEM creating this registration.                                                                         | Required                        | String    |                                          |               |           |           | Must contain only alphanumeric characters, underscores, and hyphens.       |
| UpdaterName               | Unique name to track this expedited registration.                                                           | Required                        | String    |                                          |               |           |           | Must contain only alphanumeric characters, underscores, and hyphens.       |
| RegistrationVersion       | The version of the app registration.                                                                        | Required                        | Integer   |                                          |               |           |           |                                                                            |
| Source                    | The source of the app.                                                                                      | Required                        | String    | `CustomURL`,`Store`                      |               |           |           |                                                                            |
| Endpoint                  | URI pointing to location hosting an MSIX package. Note: Must be an SSL URI that begins with `https`.        | Required if Source == CustomURL | String    |                                          |               |           |           |                                                                            |
| ProductId                 | The productId of the Store app.                                                                             | Required if Source == Store     | String    |                                          |               |           |           |                                                                            |
| Scenario                  | The scenario can be either `Update`, `Acquisition`, or `StubAcquisition`.                                   | Required                        | String    | `Update`,`Acquisition`,`StubAcquisition` |               |           |           |                                                                            |
| AllowedInOobe             | A boolean specifying whether this app should be run during user OOBE.                                       | Optional                        | Boolean   |                                          |     false     |           |           |                                                                            |
| MaxRetryCount             | The number of times the app is allowed to retry after failure.                                              | Optional                        | Integer   |                                          |     1         |     1     |     5     |                                                                            |
| TimeoutDurationInMinutes  | The duration in minutes to wait for this app to complete work.                                              | Optional                        | Integer   |                                          |     15        |     1     |    30     |                                                                            |
| IncludedRegions           | A list of regions where the app should be installed.                                                        | Optional                        | String[]  |                                          |               |           |           | If specified, must contain at least 1 item. All items much be unique.      |
| ExcludedRegions           | A list of regions where the app should not be installed.                                                    | Optional                        | String[]  |                                          |               |           |           | If specified, must contain at least 1 item. All items much be unique.      |
| IncludedEditions          | A list of editions where the app should be installed.                                                       | Optional                        | Integer[] |                                          |               |           |           | If specified, must contain at least 1 item. All items much be unique.      |
| ExcludedEditions          | A list of editions where the app should not be installed.                                                   | Optional                        | Integer[] |                                          |               |           |           | If specified, must contain at least 1 item. All items much be unique.      |
| Architecture              | Specifies the allowed architectures where the app can be expedited.                                         | Optional                        | String    | `amd64`,`arm64`                          |     all       |           |           |                                                                            |
| MinimumAllowedBuildVersion| The minimum build version of the OS that the app can be installed on.                                       | Optional                        | Integer   |                                          |               |           |           |                                                                            |
| HonorDeprovisioning       | Specifies whether the app should be skipped if previously deprovisioned.                                    | Optional                        | Boolean   |                                          |     false     |           |           | Can only be specified for the `Acquisition` or `StubAcquisition` scenario. |
| SkipIfPresent             | Specifies whether the app should be skipped if it is already installed.                                     | Optional                        | Boolean   |                                          |     false     |           |           |                                                                            |
| Priority                  | A numeric value from 1-100 to indicate relative priority of this app update.                                | Optional                        | Integer   |                                          |     100       |     1     |    100    |                                                                            |

Example of an updater_Contoso.json file:
```
{
    "PFN": "Microsoft.MicrosoftContoso_8wekyb3d8bbwe",
    "OEMName": "MS",
    "UpdaterName": "Contoso",
    "RegistrationVersion": 1,
    "Source": "Store",
    "ProductId": "1A2B3C4D5E6F",
    "Scenario": "Update",
    "Priority": 50
}
```

## Cmdlets
### Test-UpdaterRegistration
The `Test-UpdaterRegistration` cmdlet validates the JSON file against a schema. The validation performed by this cmdlet includes:
- The provided JSON file is not malformed.
- Required fields are provided.
- The specified fields are of the correct data type and within bounds.
- Registration is not attempted on Server Editions.
- A new registration does not conflict with an existing one.
- Conflicting properties are not specified.

#### Parameters
- `updaterJsonPath` (string, mandatory): Path to the updater JSON file.

#### Usage
```
Test-UpdaterRegistration 'path\to\updater_Contoso.json'
```

### Add-UpdaterRegistration
The `Add-UpdaterRegistration` cmdlet performs the registration of the application given the provided JSON is valid.

#### Parameters
- `updaterJsonPath` (string, mandatory): Path to the updater JSON file.

#### Usage
```
Add-UpdaterRegistration -updaterJsonPath 'path\to\updater_Contoso.json'
```

### Get-UpdaterRegistration
The `Get-UpdateRegistation` cmdlet provides a registration summary of a given updater. If an updater is not specified, then Get-UpdaterRegistration will output the registration summary of all updaters registered with the Universal Orchestrator framework.

#### Parameters
- `oemName` (string, optional): OEM name of the updater registration.
- `updaterName` (string, optional): Updater name of the updater registration.

#### Usage
```
Get-UpdaterRegistration -oemName 'MS' -updaterName 'Contoso'
```

```
Get-UpdaterRegistration
```

### Remove-UpdaterRegistration
The `Remove-UpdaterRegistration` cmdlet removes an existing updater registration. This will result in the respective application not being expedited by the Universal Orchestration framework.

#### Parameters
- `oemName` (string, mandatory): OEM name of the updater registration.
- `updaterName` (string, mandatory): Updater name of the updater registration.

#### Usage
```
Remove-UpdaterRegistration -oemName 'MS' -updaterName 'Contoso'
```

## Contributing

This project welcomes contributions and suggestions.  Most contributions require you to agree to a
Contributor License Agreement (CLA) declaring that you have the right to, and actually do, grant us
the rights to use your contribution. For details, visit https://cla.opensource.microsoft.com.

When you submit a pull request, a CLA bot will automatically determine whether you need to provide
a CLA and decorate the PR appropriately (e.g., status check, comment). Simply follow the instructions
provided by the bot. You will only need to do this once across all repos using our CLA.

This project has adopted the [Microsoft Open Source Code of Conduct](https://opensource.microsoft.com/codeofconduct/).
For more information see the [Code of Conduct FAQ](https://opensource.microsoft.com/codeofconduct/faq/) or
contact [opencode@microsoft.com](mailto:opencode@microsoft.com) with any additional questions or comments.

## Trademarks

This project may contain trademarks or logos for projects, products, or services. Authorized use of Microsoft
trademarks or logos is subject to and must follow
[Microsoft's Trademark & Brand Guidelines](https://www.microsoft.com/en-us/legal/intellectualproperty/trademarks/usage/general).
Use of Microsoft trademarks or logos in modified versions of this project must not cause confusion or imply Microsoft sponsorship.
Any use of third-party trademarks or logos are subject to those third-party's policies.


## License
Copyright (c) Microsoft Corporation. All rights reserved.

Licensed under the [MIT](LICENSE) license.
