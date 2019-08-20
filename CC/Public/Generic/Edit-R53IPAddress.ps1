<#
.DESCRIPTION
Function used to update A record in Route53(AWS) DNS zone.
#>
Function Edit-R53IPAddress {
    [CmdletBinding()]
    param (
        # Name of the A record
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,
        # ID of the AWS zone
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ZoneId,
        # Comment that will be added to zone edit batch
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$Comment
    )
    process {
        Import-Module AWSPowershell
        $R53Change = New-Object Amazon.Route53.Model.Change
        $R53Change.Action = "UPSERT"
        $R53Change.ResourceRecordSet = New-Object Amazon.Route53.Model.ResourceRecordSet
        $R53Change.ResourceRecordSet.Name = $Name
        $R53Change.ResourceRecordSet.Type = "A"
        $R53Change.ResourceRecordSet.TTL = "600"
        # This is very specific to our own environment, since the address scope is always starting with the prefix of 10.
        # Change accordingly to your own needs
        $R53Change.ResourceRecordSet.ResourceRecords.Add(@{Value="$((Get-NetIPAddress | where-object {$_.ipaddress -like "10.*"}).ipaddress)"})
        $R53Parameters = @{
          HostedZoneId = "/hostedzone/$ZoneId"
          ChangeBatch_Comment = "Comment"
          ChangeBatch_Change = $R53Change
        }
        Edit-R53ResourceRecordSet @R53Parameters
    }
}