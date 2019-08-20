<#
.DESCRIPTION
Function used to install and publish dependency modules used in DSC configuration files and deploy it to the DSC module path
In our case, we always first Import-DSCResource -ModuleName Name in our configuration files, which is by the book.
In order for this function to work, same logic has to be followed.
#>
Function Publish-DSCModule {
    [cmdletbinding(DefaultParameterSetName='All')]
    param (
        [Parameter(ParameterSetName='RoleName')]
        [ValidateSet('ActiveDirectoryMaster','ActiveDirectorySlave')]
        [string]$RoleName,
        [Parameter(ParameterSetName='All')]
        [switch]$All
    )
    process {
        if ($PSCmdlet.ParameterSetName -eq 'RoleName') {
            # Get Module list from the configuration file
            $ModuleList = Get-Content "C:\DSCConfiguration\$RoleName.ps1" | select-string "Import-DSCResource"
            foreach ($Module in $ModuleList.line) {
                # Do some replacement, extract the module name
                $ModuleName = $Module -replace 'Import-DSCResource','' -replace '-ModuleName','' -replace '\s+',''
                # If the module is not installed on the DSC system, install it
                if (-not $(Get-Module -ListAvailable $ModuleName)) {Install-Module $ModuleName -Repository PSGallery -Confirm:$false -Force -Scope AllUsers}
                # Extract module version
                $ModuleVersion = (Get-Module -ListAvailable $ModuleName).Version
                # Get the module path
                $ModulePath = (Get-Module -ListAvailable $ModuleName).ModuleBase+'\*'
                # Define the destination path
                $DestinationPath = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Modules\$($ModuleName)_$($ModuleVersion).zip"
                # If the module is not present on the system as a DSC dependency, deploy it
                if ($false -eq $(Test-Path -Path $DestinationPath)) {
                    Compress-Archive -Path $ModulePath -DestinationPath $DestinationPath -Update
                    if ($true -eq $(Test-Path "$DestinationPath.checksum")) {Remove-Item "$DestinationPath.checksum" -Confirm:$false -Force}
                    New-DscChecksum -Path $DestinationPath
                }
            }
        }
        if ($PSCmdlet.ParameterSetName -eq 'All') {
            [array]$FileList = Get-ChildItem "C:\DSCConfiguration\*.ps1"
            foreach ($File in $FileList) {
                $ModuleList = Get-Content $File.FullName | select-string "Import-DSCResource"
                foreach ($Module in $ModuleList.line) {
                    $ModuleName = $Module -replace 'Import-DSCResource','' -replace '-ModuleName','' -replace '\s+',''
                    if (-not $(Get-Module -ListAvailable $ModuleName)) {Install-Module $ModuleName -Repository PSGallery -Confirm:$false -Force -Scope AllUsers}
                    $ModuleVersion = (Get-Module -ListAvailable $ModuleName).Version
                    $ModulePath = (Get-Module -ListAvailable $ModuleName).ModuleBase+'\*'
                    $DestinationPath = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Modules\$($ModuleName)_$($ModuleVersion).zip"
                    if ($false -eq $(Test-Path -Path $DestinationPath)) {
                        Compress-Archive -Path $ModulePath -DestinationPath $DestinationPath -Update
                        if ($true -eq $(Test-Path "$DestinationPath.checksum")) {Remove-Item "$DestinationPath.checksum" -Confirm:$false -Force}
                        New-DscChecksum -Path $DestinationPath
                    }
                }
            }
        }
    }
}