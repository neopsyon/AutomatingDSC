Install-Module PowershellGet -Repository PSGallery -Confirm:$false -Force -Scope AllUsers
New-Alias -Name Nuget -Value "/usr/local/bin/nuget.exe"
$DSCHost = 'dsc.custom.company.aws.com'
Register-PSRepository -Name $TargetHost -SourceLocation "http://$($TargetHost):8443/nuget" -PublishLocation "http://$($TargetHost):8443/nuget"
Install-Module AWSPowershell -Repository $TargetHost -Confirm:$false -Force -Scope AllUsers; Import-Module AWSPowershell
$SshKey = (Get-SSMParameter -Name "/nuget/ci_key" -WithDecryption:$true).value
$SshKey | out-file .\id_rsa
chmod 400 id_rsa
mkdir ~/.ssh
ssh-keyscan -H $DSCHost >> ~/.ssh/known_hosts
$DSCSession = New-PSSession -HostName $DSCHost -UserName "administrator" -KeyFilePath .\id_rsa
Copy-Item -ToSession $DSCSession -Path .\CC\ -Recurse -Destination "C:\Windows\System32\WindowsPowerShell\v1.0\Modules\" -Force
Invoke-Command -Session $DSCSession -ScriptBlock {
    if ($false -eq (Test-Path C:\TempDirectory)) { New-Item -Path C:\TempDirectory -ItemType Directory }
    else {
        Remove-Item C:\TempDirectory\* -Recurse -Force -Confirm:$false
    }
}
Copy-Item -ToSession $DSCSession  -Path .\CC\Public\Configurations\*.ps1 -Recurse -Destination C:\TempDirectory -Force
Copy-Item -ToSession $DSCSession  -Path .\CC\Public\Configurations\ConfigurationData.psd1 -Destination C:\DSCConfiguration\ -Force
Invoke-Command -Session $DSCSession -ScriptBlock {
    $env:PSModulePath += ';C:\Program Files\WindowsPowerShell\Modules'
    $env:PSModulePath += ';C:\Program Files (x86)\AWS Tools\PowerShell\'
    Import-Module CC, AWSPowershell -SkipEditionCheck
    $FileList = (Get-ChildItem C:\TempDirectory\*.ps1).name
    foreach ($File in $FileList) {
        if ($null -ne $(Compare-Object -ReferenceObject C:\TempDirectory\$File -DifferenceObject C:\DSCConfiguration\$File)) {
            Copy-Item C:\TempDirectory\$File -Destination C:\DSCConfiguration\$File -Force
            Publish-DSCModule -RoleName $($File.Split('.')[0])
            Publish-DSCCustomConfiguration -RoleName $($File.Split('.')[0])
        }
    }
}