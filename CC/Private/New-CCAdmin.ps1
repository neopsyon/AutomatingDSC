<#
.DESCRIPTION
Helper function used to deploy the local administrative user.
#>
Function New-CCAdmin {
    [CmdletBinding()]
    param ()
    process {
        try {
            $Password = (Get-SSMParameter -Name '/generic/local_admin' -WithDecryption:$true).Value
            $EncryptedPassword = Convertto-SecureString $Password -AsPlainText -Force
            New-LocalUser -Name 'customcompanyadmin' -Password $EncryptedPassword -FullName 'CC Administrator' -Description 'Used for deployment purposes.'
            Add-LocalGroupMember -Group 'Administrators' -Member 'customcompanyadmin'
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