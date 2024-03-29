$Public  = @( Get-ChildItem -Path $PSScriptRoot\Public\DSC\*.ps1 -ErrorAction SilentlyContinue )
$Public += @( Get-ChildItem -Path $PSScriptRoot\Public\Generic\*.ps1 -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path $PSScriptRoot\Private\*.ps1 -ErrorAction SilentlyContinue )
    Foreach($import in @($Public + $Private))
    {
        Try
        {
            . $import.fullname
        }
        Catch
        {
            Write-Error -Message "Failed to import function $($import.fullname): $_"
        }
    }

Export-ModuleMember -Function $Public.Basename
