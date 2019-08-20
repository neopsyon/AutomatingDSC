<#
.DESCRIPTION
Helper function used to catch detailed error - if something happens during the Powershell code execution.
In our case, we are writing errors in the event log and shipping them to Redis/Logstash/Kibana via Winlogbeat agent.
To understand it better, refer to - https://gallery.technet.microsoft.com/Catching-of-detailed-f7573657?redir=0
#>
Function Write-CustomError {
    [cmdletbinding()]
    param (
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true)]
        [string]$Exception,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true)]
        [string]$Category,
        [Parameter(Mandatory = $true,
            ValueFromPipelineByPropertyName = $true)]
        [string]$Line
    )
    process {
        $EventLogName = "Application"
        $Source = "CUSTOMCOMPANY"
        $TimeStamp = [datetime]::Now
        try {
            if ([System.Diagnostics.EventLog]::SourceExists($Source) -eq $false) {
                [System.Diagnostics.EventLog]::CreateEventSource($Source, $EventLogName)
            }
            $Id = New-Object System.Diagnostics.EventInstance(1000, 1);
            $EventObject = New-Object System.Diagnostics.EventLog;
            $EventObject.Log = $EventLogName;
            $EventObject.Source = $Source;
            $EventObject.WriteEvent($Id, @($Exception, $Category, $Line, $TimeStamp))
        }
        catch {
            Write-Error "$_" -ErrorAction Stop
        }
    }
}