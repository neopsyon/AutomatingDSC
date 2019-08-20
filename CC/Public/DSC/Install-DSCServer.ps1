<#
.DESCRIPTION
Function used to install DSC pull server with SSL support, prepare it with the certificate for MOF encryption and schedule publishing of DSC configuration.
#>
Function Install-DSCServer {
    [cmdletbinding()]
    param ()
    process {
        # Install required modules used in the DSC configuration.
        $ModuleList = @(
            'NetworkingDsc'
            'xPSDesiredStateConfiguration'
        )
        foreach ($Module in $ModuleList) {
            if (-not $(Get-Module -ListAvailable $Module)){Install-Module -Name $Module -Confirm:$false -Force -Scope AllUsers}
        }
        # Define configuration data for the DSC pull server.
        $ConfigurationData = @'
        configuration DscPullServer
        {
        param(
            [string[]]$NodeName = 'localhost'
        )
        $Now = [datetime]::now
        $Certificate = (New-SelfSignedCertificate -CertStoreLocation Cert:\LocalMachine\My\ -DnsName $env:COMPUTERNAME,"dsc.custom.company.aws.com" -NotAfter $Now.AddYears(+100))
        Export-Certificate -Cert Cert:\LocalMachine\My\$($Certificate.PSChildName) -FilePath C:\DSCCertificate.cer
        Import-DSCResource -ModuleName PSDesiredStateConfiguration
        Import-DSCResource -ModuleName xPSDesiredStateConfiguration
        Import-DSCResource -ModuleName NetworkingDsc
            Node $NodeName
            {
                WindowsFeature DSCServiceFeature
                {
                Ensure = 'Present'
                Name = 'DSC-Service'
                }
        
                xDscWebService PSDSCPullServer
                {
                Ensure = 'present'
                EndpointName = 'PSDSCPullServer'
                Port = 8080
                PhysicalPath = "$env:SystemDrive\inetpub\PSDSCPullServer\"
                CertificateThumbPrint = $Certificate.ThumbPrint
                ModulePath = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Modules"
                ConfigurationPath = "$env:PROGRAMFILES\WindowsPowerShell\DscService\Configuration"
                State = 'Started'
                DependsOn = '[WindowsFeature]DSCServiceFeature'
                UseSecurityBestPractices = $true
                }
                File RegistrationKeyFile
                {
                Ensure = 'Present'
                Type = 'File'
                DestinationPath = "$env:ProgramFiles\WindowsPowerShell\DscService\RegistrationKeys.txt"
                Contents = [guid]::newguid()
                }
                Firewall AddInboundRule {
                    Name                  = 'PSDSCPullServer'
                    DisplayName           = 'Firewall Rule for DSC Pull Server'
                    Ensure                = 'Present'
                    Enabled               = 'True'
                    Profile               = ('Public', 'Domain', 'Private')
                    Direction             = 'Inbound'
                    LocalPort             = ('8080')
                    Protocol              = 'TCP'
                    Description           = 'Firewall Rule for DSC Pull Server'
                    DependsOn = '[xDscWebService]PSDSCPullServer'
                }
                File ConfigurationFolder {
                    DestinationPath = "C:\DSCConfiguration"
                    Type = "Directory"
                    Ensure = "Present"
                }
            }
        }
'@
        try {
        # Load the configuration data
        Invoke-Expression $ConfigurationData
        # Generate the MOF file
        DscPullServer -NodeName Localhost -OutputPath C:\DSCPullServer
        # Start the configuration
        Start-DscConfiguration -Path C:\DSCPullServer -ComputerName localhost -Wait
        # Copy self-signed DSC certificate to the root store
        Copy-Certificate -SourceStoreName My -SourceStoreScope LocalMachine -DestinationStoreName Root -DestinationStoreScope LocalMachine -SubjectFilter "CN=$($env:COMPUTERNAME)"
        Import-Module AWSPowershell
        # Import certificate to the S3 bucket, so it can be dowloaded and trusted by the client
        Write-S3Object -BucketName 'custom-company' -File 'C:\DSCCertificate.cer' -Key "install-files/Microsoft/Certificates/DSCCertificate.cer"
        Remove-Item 'C:\DSCCertificate.cer' -Force
        # Write registration key to the SSM parameter store
        $RegistrationKey = Get-Content "C:\Program Files\WindowsPowerShell\DscService\RegistrationKeys.txt"
        Write-SSMParameter -Name "/dsc/registration_key" -type SecureString -Value $RegistrationKey -Overwrite:$true
        # Execute helper function for generating the self-signed certificate for MOF file encryption
        New-DSCEncryptionCertificate
        # Create local admin for scheduling the tasks
        New-CCAdmin
        # Register schedule of publishing DSC configuration
        Register-DSCSchedule
        # Trigger the deployment of the pipeline - deploy configurations that are already stored in the GIT repository
        $PipelineTrigger = (Get-SSMParameter -Name '/generic/pipeline_token' -WithDecryption:$true).Value
        Invoke-WebRequest -Uri "https://git.custom.company/api/v4/projects/100/trigger/pipeline?token=$($PipelineTrigger)&ref=master" -Method Post -UseBasicParsing
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