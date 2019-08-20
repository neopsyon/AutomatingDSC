<#
.DESCRIPTION
Function used for generating and storing the certificate used for MOF file encryption.
#>
Function New-DSCEncryptionCertificate {
    [cmdletbinding()]
    param ()
    process {
        # Generate self signed certificate for 
        $Now = [datetime]::now
        $Certificate = New-SelfSignedCertificate -Type DocumentEncryptionCertLegacyCsp -DnsName 'DSCEncryptionCertificate' -HashAlgorithm SHA256 -NotAfter $Now.AddYears(+100)
        # Generate password that will be used to encrypt the certificate
        $Password = New-Password
        # Create secure string from the password
        $EncryptedPassword = ConvertTo-SecureString -String $Password -Force -AsPlainText
        # Write password to SSM parameter store
        Write-SSMParameter -Name '/dsc/encryption_password' -type SecureString -Value $Password -Overwrite:$true
        # Export certificate, along with the private key and encrypt it
        $Certificate | Export-PFXCertificate -FilePath 'C:\DSCEncryption.pfx' -Password $EncryptedPassword -Force
        # Store certificate in the S3 bucket
        Write-S3Object -BucketName 'custom-company' -Key 'install-files/Microsoft/Certificates/DSCEncryption.pfx' -File 'C:\DSCEncryption.pfx'
        # Remove it from the file system
        Remove-Item 'C:\DSCEncryption.pfx'
        # Export certificate without the private key
        $Certificate | Export-Certificate -FilePath 'C:\DSCEncryption.cer'
        # Import it in both stores
        Import-Certificate 'C:\DSCEncryption.cer' -CertStoreLocation Cert:\LocalMachine\My
        Import-Certificate 'C:\DSCEncryption.cer' -CertStoreLocation Cert:\LocalMachine\Root
        # Remove the certificate with the private key
        $Certificate | Remove-Item -Force
        # Store certificate file, this will be used to encrypt the MOF files
        Copy-Item 'C:\DSCEncryption.cer' -Destination "$env:programfiles\WindowsPowerShell\DscService\"
        # Remove the copy
        Remove-Item 'C:\DSCEncryption.cer'
    }
}