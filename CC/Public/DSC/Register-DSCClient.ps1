Function Register-DSCClient {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true,
            Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigurationRole
    )
    process {
        # Define hostname of the DSC server
        $TargetHost = "dsc.custom.company.aws.com"
        # Check if the DSC service is available
        $TestConnection = Test-NetConnection -ComputerName $TargetHost -Port 8080
        if ($true -eq $TestConnection.TcpTestSucceeded) {
            try {
                # Get self-signed certificate of the DSC server
                $DSCCertificate = Get-S3Object -BucketName "custom-company" | where-object {$_.Key -like "*DSCCertificate.cer*"}
                $DSCCertificate | Copy-S3Object -LocalFile 'C:\DSCCert.cer'
                # Store it in the cert store in order to trust it
                Import-Certificate C:\DSCCert.cer -CertStoreLocation Cert:\LocalMachine\Root\
                Remove-Item 'C:\DSCCert.cer'
                # Get decryption password for the MOF encryption certificate
                $PFXPassword = (Get-SSMParameter -Name '/dsc/encryption_password' -WithDecryption:$true).Value
                $EncryptedPFX = ConvertTo-SecureString -String $PFXPassword -AsPlainText -Force
                # Get the MOF encryption certificate
                $S3PFX = (Get-S3Object -BucketName 'custom-company' | Where-Object {$_.Key -like "*DSCEncryption.pfx*"})
                $PFXLocalFile = 'C:\DSCEncryption.pfx'
                $S3PFX | Copy-S3Object -LocalFile $PFXLocalFile
                # Import the certificate
                Import-PfxCertificate -FilePath $PFXLocalFile -Password $EncryptedPFX -CertStoreLocation Cert:\LocalMachine\My
                Import-PfxCertificate -FilePath $PFXLocalFile -Password $EncryptedPFX -CertStoreLocation Cert:\LocalMachine\Root
                Remove-Item $PFXLocalFile -Force
                # Retrieve thumbprint of the MOF encryption certificate, to be used to configure LCM
                $EncryptionThumbprint = (get-childitem Cert:\LocalMachine\my | Where-Object {$_.subject -eq 'CN=DSCEncryptionCertificate'}).thumbprint
                # KEY to understand - $ConfigurationName variable value will be stored as a Key=Value pair in the Tag
                $ConfigurationName = [guid]::NewGuid()
                # Configure LCM
                [DSCLocalConfigurationManager()]
                Configuration DSCPullConfig {
                    Node $env:COMPUTERNAME {
                        # Get the registration key, which has been written by DSC server
                        $RegistrationKey = (Get-SSMParameter -Name "/dsc/registration_key" -WithDecryption $true).value
                        # Configure LCM local preferences
                        Settings {
                            ConfigurationMode = 'ApplyAndAutoCorrect'
                            RefreshMode = 'Pull'
                            CertificateId = "$EncryptionThumbprint"
                            RebootNodeIfNeeded = $true
                        }
                        # Configure configuration repository
                        ConfigurationRepositoryWeb PullServer {
                            ServerURL = "https://$($TargetHost):8080/PsDscPullserver.svc"
                            AllowUnsecureConnection = $false
                            RegistrationKey = $RegistrationKey
                            ConfigurationNames = @("$ConfigurationName")
                        }
                        # Configure module repository
                        ResourceRepositoryWeb PullServerModules {
                            ServerURL = "https://$($TargetHost):8080/PsDscPullserver.svc"
                            AllowUnsecureConnection = $false
                            RegistrationKey = $RegistrationKey
                        }
                    }
                }
                # Generate MOF
                DSCPullConfig
                # Execute configuration against LCM
                Set-DscLocalConfigurationManager -ComputerName $env:COMPUTERNAME ./DSCPullConfig -Force
                # Retrieve it's own ID
                $InstanceId = (Invoke-WebRequest -Uri 'http://169.254.169.254/latest/meta-data/instance-id' -UseBasicParsing).content
                Import-Module AWSPowershell
                # Write TAG(CRUCIAL) as InfrastructureRole=ConfigurationID pair
                New-EC2Tag -Tag (New-Object -TypeName Amazon.EC2.Model.Tag -ArgumentList @("$ConfigurationRole","$ConfigurationName")) -ResourceId $InstanceId
                # Trigger the pipeline, so the DSC server generates MOF files for this new client
                $PipelineTrigger = (Get-SSMParameter -Name '/tools/generic/pipeline_token' -WithDecryption:$true).Value
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
        else {
            [PSCustomObject]@{
                Exception = "Can't connect to $TargetHost"
                Category  = "Problem"
                Line      = "Beginning of the Register-DSCClient function."
            } | Write-CustomError
        }
    }
}