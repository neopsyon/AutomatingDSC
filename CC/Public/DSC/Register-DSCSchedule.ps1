<#
.DESCRIPTION
Function which is used to schedule the publishing of the DSC configuration.
Why schedule?
Because in the meantime, some of the clients may have registered with the DSC server and they have to receive newly generated configuration.
#>
Function Register-DSCSchedule {
    [cmdletbinding()]
    param ()
    process {
        # Register historical tracking of the task scheduler tasks
        $logName = 'Microsoft-Windows-TaskScheduler/Operational'
        $log = New-Object System.Diagnostics.Eventing.Reader.EventLogConfiguration $logName
        $log.IsEnabled=$true
        $log.SaveChanges()
        $Now = [datetime]::Now
        # Create an action, import the CC module and publish the configuration
        $Action = New-ScheduledTaskAction -Execute 'Powershell.exe' -Argument '-NoProfile -WindowStyle Hidden -command "Import-Module CC;Publish-DSCCustomConfiguration"'
        # Repeat for hundred years
        $Duration = (New-TimeSpan -Days 3650)
        # Create a trigger, repeat each 60 minutes
        $Trigger = New-ScheduledTaskTrigger -Once -At $Now.AddMinutes(30) -RepetitionInterval (New-TimeSpan -Minutes 60) -RepetitionDuration $Duration
        # Splat all options for the scheduled task
        $TaskSplat = @{
            Action = $Action
            Trigger = $Trigger
            TaskName = 'DSC Publishing'
            Description = 'DSC Publishing reocurring job.'
            RunLevel = 'Highest'
            User = 'customcompanyadmin'
            Password = (Get-SSMParameter -Name '/generic/local_admin' -WithDecryption:$true).Value
        }
        # Register task
        Register-ScheduledTask @TaskSplat
    }
}