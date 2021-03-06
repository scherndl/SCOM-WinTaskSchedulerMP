# Enables Task Scheduler History
#
#	sets event log flag
#
# Version 1.0 - 01. July 2014 - initial            			  - Raphael Burri - raburri@bluewin.ch

param ( [string]$scriptName = 'Custom.TaskScheduler2.Task.EnableTaskSchedulerHistory.ps1')

#region constvar
#constants & variables
$FLAG_KEY = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WINEVT\Channels\Microsoft-Windows-TaskScheduler/Operational"
$FLAG_VALUE = "Enabled"
#endregion

#region main
$currentvalue = (Get-ItemProperty -Path $FLAG_KEY -Name $FLAG_VALUE -ErrorAction SilentlyContinue).Enabled

if ($currentvalue -eq $null) { Write-Host "WARNING: Task Scheduler History Event Log key does not exist." }
elseif ($currentvalue -eq 1) { Write-Host "INFORMATION: Task Scheduler History is already enabled. No action required." }
else {
	#enable history
	Set-ItemProperty -Path $FLAG_KEY -Name $FLAG_VALUE -Value 1 -ErrorAction SilentlyContinue
	#verify
	$currentvalue = (Get-ItemProperty -Path $FLAG_KEY -Name $FLAG_VALUE -ErrorAction SilentlyContinue).Enabled
	if ($currentvalue -eq 1) { Write-Host "SUCCESS: Task Scheduler History is now enabled." }
	else { Write-Host "WARNING: Failed to enable Task Scheduler History. The current user does not have write access to the system's registry. Make sure you run this task/recovery with a user account that has administrative access rights." }
	}

#endregion
