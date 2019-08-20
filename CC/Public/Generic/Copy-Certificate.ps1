<#
.SYNOPSIS
Function for copying certificates from one store location to another.

.DESCRIPTION
Copy one or multiple certificates from one to another certificate store.

.PARAMETER SourceStoreName
Name of the source store - where your certificate or certificates are located, like My or Root.

.PARAMETER SourceStoreScope
Scope of the source store - like LocalMachine or CurrentUser.

.PARAMETER DestinationStoreName
Name of the destination store - where you want to copy your certificates, like My or Root.

.PARAMETER DestinationStoreScope
Scope of the destination store - like LocalMachine or CurrentUser.

.PARAMETER SubjectFilter
Subject name of the certificate, this will be used as a filter property to find certificates in the source store.

.EXAMPLE
Copy-Certificate -SourceStoreName My -SourceStoreScope LocalMachine -DestinationStoreName Root -DestinationStoreScope LocalMachine -SubjectFilter CN=MyName
#>
Function Copy-Certificate {
    [cmdletbinding()]
    param (        
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$SourceStoreName,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("LocalMachine","CurrentUser")]
        [string]$SourceStoreScope,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$DestinationStoreName,
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [ValidateSet("LocalMachine","CurrentUser")]
        [string]$DestinationStoreScope,
        [parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$SubjectFilter
    )
    process {
        try {
            $ErrorActionPreference = "Stop"
            $SourceStore = New-Object -TypeName System.Security.Cryptography.X509Certificates.X509Store -ArgumentList $SourceStoreName,$SourceStoreScope
            $SourceStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
            [array]$Certificate = $SourceStore.Certificates | Where-Object -FilterScript {$_.Subject -like "*$SubjectFilter*"}
            $DestinationStore = New-Object  -TypeName System.Security.Cryptography.X509Certificates.X509Store -ArgumentList $DestinationStoreName,$DestinationStoreScope
            $DestinationStore.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
            foreach ($Cert in $Certificate) {
                $DestinationStore.Add($Cert)
            }
            $SourceStore.Close()
            $DestinationStore.Close()
        }
        catch {
            Write-Error "$_" -ErrorAction Stop
        }
    }
}