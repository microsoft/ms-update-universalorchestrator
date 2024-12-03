#
# Module manifest for module 'AppOrchestration'
#

@{

# Version number of this module.
ModuleVersion = '1.0.0.0'

# ID used to uniquely identify this module
GUID = '787f17f4-973b-4ad0-a29b-9f827276bebb'

# Author of this module
Author = 'Microsoft Corporation'

# Company or vendor of this module
CompanyName = 'Microsoft Corporation'

# Copyright statement for this module
Copyright = '(c) Microsoft Corporation. All rights reserved.'

# List of all modules packaged with this module
ModuleList = @('.\AppOrchestration.psm1')

# Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
NestedModules = @('.\AppOrchestration.psm1')

# Functions to export from this module
FunctionsToExport = @('Test-UpdaterRegistration', 'Add-UpdaterRegistration', 'Get-UpdaterRegistration', 'Remove-UpdaterRegistration')
AliasesToExport = @()
CmdletsToExport = @()

# HelpInfo URI of this module
HelpInfoURI = 'https://aka.ms/winsvr-2025-pshelp'

CompatiblePSEditions = @('Desktop')
}
