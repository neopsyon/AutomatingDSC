Function Install-PSCore {
    [cmdletbinding()]
    param ()
    process {
        # This function is based on - https://docs.microsoft.com/en-us/powershell/scripting/learn/remoting/ssh-remoting-in-powershell-core?view=powershell-6
        Import-Module AWSPowershell
        $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False
        # Link to the Powershell core
        $PSCore = 'https://github.com/PowerShell/PowerShell/releases/download/v6.2.2/PowerShell-6.2.2-win-x64.msi'
        $PSCoreFile = $PSCore.Split("/")[-1]
        # Download the file
        Invoke-WebRequest -Uri $PSCore -Outfile "C:\$PSCoreFile"
        # Install the package
        msiexec.exe /package "C:\$PSCoreFile" /quiet ; start-sleep 3
        # Install SSH role
        Get-WindowsCapability -Online | where-object {$_.name -like '*ssh*'} | Add-WindowsCapability -Online
        # Create symbolinc link accordingly
        New-Item -ItemType SymbolicLink -Path C:\pwsh -Value 'C:\Program Files\PowerShell\6'
        # Configure SSH for auto startup
        Set-Service SSHD -StartupType Automatic ; Start-Service SSHD
        # Download the preconfigured SSHD config file
        $SSHConfig = Get-S3object -BucketName 'custom-company' | Where-Object {$_.key -like "*sshd_config*"}
        # Store it in the appropraite directory
        $SSHConfig | Copy-S3Object -LocalFile $env:programdata\ssh\sshd_config
        # Get the ssh public key for the ssh access, private key is used from the initiators like - GitLab Runner
        $CIKey = (Get-SSMParameter -Name "/tools/nuget/ci_public_key" -WithDecryption $true).value
        New-Item -Path $env:userprofile\.ssh\ -ItemType Directory
        # Store private key
        [system.io.file]::WriteAllLines("$env:userprofile\.ssh\authorized_keys",$CIKey,$Utf8NoBomEncoding)
        # Restart service after completion
        Restart-Service SSHD
    }
}