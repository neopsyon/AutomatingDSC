<#
.DESCRIPTION
Function used for publishing of the DSC configuration for the specific or all infrastructure roles specified in the RoleList array.
#>
Function Publish-DSCCustomConfiguration {
    [cmdletbinding(DefaultParameterSetName = 'All')]
    param (
        [Parameter(ParameterSetName = 'RoleName')]
        [ValidateSet('ActiveDirectoryMaster', 'ActiveDirectorySlave')]
        [string]$RoleName,
        [Parameter(ParameterSetName = 'All')]
        [switch]$All
    )
    process {
        try {
            # Helper function for installing and publishing all dependency modules that are found in the configuration data.
            Publish-DSCModule
            # Directory which contains configuration files - they are matching the name of the infrastructure role.
            $ConfigurationDirectory = 'C:\DSCConfiguration'
            # Path to DSC configuration folder.
            $ConfigurationPath = "$env:programfiles\WindowsPowerShell\DscService\Configuration"
            # Credential set which will be used in the MOF files
            $DSCUserName = 'CUSTOM\Administrator'
            $DSCPassword = (Get-SSMParameter -Name '/ad/domain_master' -WithDecryption:$true).Value
            $DSCEncryptedPassword = ConvertTo-SecureString -String $DSCPassword -AsPlainText -Force
            $DSCredential = New-Object System.Management.Automation.PSCredential -ArgumentList $DSCUserName, $DSCEncryptedPassword
            # List of configuration roles
            if ($PSCmdlet.ParameterSetName -eq 'All') {
                $RoleList = @(
                    'ActiveDirectoryMaster'
                    'ActiveDirectorySlave'
                )
                foreach ($Role in $RoleList) {
                    # Query all EC2 instances for the specific infrastructure tag, to retrieve the client unique ID
                    # To better understand this part - refer to Register-DSCClient function
                    [array]$TagList = ((Get-EC2Instance | where-object { $_.Instances.tags.key -contains "$Role" }).Instances.Tags | Where-Object { $_.Key -eq "$Role" }).Value
                    foreach ($Tag in $TagList) {
                        # Define configuration for encrypting the MOF files
                        $ConfigurationData = @"
                        @{
                            AllNodes = @(
                                @{
                                    NodeName = "$Tag"
                                    PSDscAllowDomainUser = `$true
                                    CertificateFile = "$env:programfiles\WindowsPowerShell\DscService\DSCEncryption.cer"
                                }
                            )
                        }
"@
                        # Export configuration data for encrypting the MOF files
                        $ConfigurationData | Out-File "$ConfigurationDirectory\ConfigurationData.psd1"
                        # Dot source infrastructure(DSC) role configuration
                        . "$ConfigurationDirectory\$Role.ps1"
                        # Execute configuration data to generate the MOF
                        & $Role -Credential $DSCredential -ConfigurationData "$ConfigurationDirectory\ConfigurationData.psd1" -OutputPath $ConfigurationPath
                    }
                }
                [array]$ChecksumList = Get-ChildItem "$ConfigurationPath\*.mof"
                # Create checksums for MOF files
                foreach ($File in $ChecksumList) {
                    if ($true -eq $(test-path "$($File.Fullname).checksum")) {
                        Remove-Item "$($File.Fullname).checksum" -Force
                        New-DSCCheckSum -Path $File.FullName
                    }
                    else {
                        New-DSCCheckSum -Path $File.FullName
                    }
                }
            }
            # Same logic, just for the specific infrastructure role
            if ($PSCmdlet.ParameterSetName -eq 'RoleName') {
                [array]$TagList = ((Get-EC2Instance | where-object { $_.Instances.tags.key -contains "$RoleName" }).Instances.Tags | Where-Object { $_.Key -eq "$RoleName" }).Value
                foreach ($Tag in $TagList) {
                    . "$ConfigurationDirectory\$RoleName.ps1"
                    $ConfigurationData = @"
                    @{
                        AllNodes = @(
                            @{
                                NodeName = "$Tag"
                                PSDscAllowDomainUser = `$true
                                CertificateFile = "$env:programfiles\WindowsPowerShell\DscService\DSCEncryption.cer"
                            }
                        )
                    }
"@
                    $ConfigurationData | Out-File "$ConfigurationDirectory\ConfigurationData.psd1"
                    & $Role -Credential $DSCredential -ConfigurationData "$ConfigurationDirectory\ConfigurationData.psd1" -OutputPath $ConfigurationPath
                    [array]$ChecksumList = Get-ChildItem "$ConfigurationPath\*.mof"
                    foreach ($File in $ChecksumList) {
                        if ($true -eq $(test-path "$($File.Fullname).checksum")) {
                            Remove-Item "$($File.Fullname).checksum" -Force
                            New-DSCCheckSum -Path $File.FullName
                        }
                        else {
                            New-DSCCheckSum -Path $File.FullName
                        }
                    }
                }
            }
        }
        catch {
            [PSCustomObject]@{
                Exception = $_.exception.message
                Category  = $_.categoryinfo.category
                Line      = $_.invocationinfo.line
            } | Write-CustomError
        }
    }
}