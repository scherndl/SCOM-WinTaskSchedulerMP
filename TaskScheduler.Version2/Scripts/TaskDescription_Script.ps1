#
#	Enable or Disable monitoring of
#					scheduled tasks
#	use in SCOM task workflows
#
#		System requirements: Powershell >= 2.0 / .NET >= 2.0
#
#		Parameters
#			$computerName		
#			$operation			ENABLE|DISABLE|REDISCOVER
#
# Version 1.0 - 18. June 2015 - initial            - Raphael Burri - raburri@bluewin.ch

#region parameters
param([string]$computerName = "localhost",
	[string]$operation = "Enable",
	[string]$folder = "Lenovo\Lenovo Settings Power",
	[string]$taskName = "Lenovo Settings Power",
	[string]$disableKey = "_DoNotMonitor")
#endregion


#region just examples and placeholders for debug
#endregion

#region variables and constants
# get script name
# SCOM agent calls them dynamically, assigning random names
#$scriptName = $MyInvocation.MyCommand.Name
$scriptName = "TaskDescription_Script.ps1"
$userName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name

#endregion

# Get access to the scripting API
$scomAPI = new-object -comObject "MOM.ScriptAPI"

#region check if the parameters are valid
$scriptParamValid = $false
if (($operation -imatch "^(ENABLE|DISABLE|REDISCOVER)$") -and ($folder -imatch ".+") -and ($taskName -imatch ".+")) { $scriptParamValid = $true }
if ($scriptParamValid -eq $false)
	{
	"Script parameters were invalid:

Parameters:
-----------
operation: " + $operation + "
folder: " + $folder + "
taskName: " + $taskName | Write-Output	
	}
#endregion

function main	{
	#load COM object (PoSh 2.0 does not offer anything else)
	$schedule = New-Object -ComObject "Schedule.Service"
	$schedule.Connect() 
	
	#folder may be a full path
	try{ $folderObj = $schedule.GetFolder($folder) }
	catch { 
		$folder -imatch '(?<folder>.+)\\(?<taskName>.+)$' | Out-Null
		if ($Matches) {
			$folder = $Matches.folder
			try{ $folderObj = $schedule.GetFolder($folder) }
			catch {	Write-Output ("Failed to load task folder " + $folder); exit }
		}
		else {	Write-Output ("Failed to load task folder " + $folder); exit }
	}
	if ($folderObj) {
		try { $tasks = $folderObj.GetTasks(0) | where {$_.Name -eq $taskName} }
		catch { Write-Output ("Failed to load task " + $taskName); exit }
		if ($tasks) {
			foreach ($task in $tasks) {
				# pre-release MP versions used _disable - so make sure that is removed as well
				if ($operation -eq 'ENABLE') { Set-TaskEnabled -taskFolder $folderObj -task $task -disableKey ('(' + $disableKey + '|_disabled)') }
				if ($operation -eq 'DISABLE') { Set-TaskDisabled -taskFolder $folderObj -task $task -disableKey $disableKey }
				if ($operation -eq 'REDISCOVER') { 
					Write-EventLogEntry -EventLogName 'Operations Manager' -EventSourceName 'Health Service Script' -EventId 221 -EventSeverity 'Information' -EventDescription ("
Task to ask for re-discovery of scheduled tasks was run.

Computer: %3") -EventParameter1 $ScriptName -EventParameter2 $computerName -EventParameter3 ""
		
			Write-Output ("Asked for re-discovery of the certificate store by writing local event.")
		}
			}
		}
	}
	else
		{
		$scomAPI.LogScriptEvent($scriptName, 120, 2, ("Failed access task folder.`n`Folder: {0}" -f $folder)) 
		}
}

#removes "disable" flag from certificate's friendly name
function Set-TaskEnabled	{
	param($taskFolder = $null,
		$task = $null,
		[string]$disableKey = '_(disabled|DoNotMonitor)')
		
	$taskDescriptionUpdated = $true
	$taskDefinition = $task.Definition
	
	if ($taskDefinition.RegistrationInfo.Description -imatch ( '(?<descriptionCore>.*)' + $disableKey + '$')) {
		#task is currently disabled
		#remove disable key from the end
		$taskDefinition.RegistrationInfo.Description = [string]($matches.descriptionCore)
		
		#update task object
		try{ $taskFolder.RegisterTaskDefinition($task.Name, $taskDefinition, 36, $null, $null, $null) | Out-Null }
		catch [System.Management.Automation.MethodInvocationException] {
			$taskDescriptionUpdated = $false
			switch -regex ($Error[0].Exception.InnerException.InnerException.Message) {
				'0x80070005' { # access denied
					Write-Output $Error[0].Exception.InnerException.InnerException.Message }
				'0x80070002' {	# task not found
					Write-Output $Error[0].Exception.InnerException.InnerException.Message }
				default { $Error[0].Exception.Message }
			}
		}
		catch {
			$taskDescriptionUpdated = $false
			Write-Output "Other Error"
			Write-Output $Error[0].Exception.Message
		}
	}
	else { $taskDescriptionUpdated = $false
		Write-Output ("     description does not contain " + $disableKey )
	}
	if ($taskDescriptionUpdated -eq $true) {
		Write-Output ("Task Description set to: " + $taskDefinition.RegistrationInfo.Description)
		Write-EventLogEntry -EventLogName 'Operations Manager' -EventSourceName 'Health Service Script' -EventId 222 -EventSeverity 'Information' -EventDescription ("
Description tag of scheduled task was removed via SCOM task by user " + $userName + ". Monitoring will resume following the next discovery cycle.

Computer: %3") -EventParameter1 $ScriptName -EventParameter2 $computerName -EventParameter3 ""
	}
	else { Write-Output "Task description was not updated." }
}
	
#adds "disable" flag to certificate's friendly name
function Set-TaskDisabled	{
	param($taskFolder = $null,
		$task = $null,
		[string]$disableKey = '_(disabled|DoNotMonitor)')
		
	$taskDescriptionUpdated = $true
	$taskDefinition = $task.Definition
	if ($taskDefinition.RegistrationInfo.Description -inotmatch ($disableKey + '$')) {
		#task is currently enabled
		#add disable key to the end
		$taskDefinition.RegistrationInfo.Description = $taskDefinition.RegistrationInfo.Description + $disableKey
		#update task object
		try{ $taskFolder.RegisterTaskDefinition($task.Name, $taskDefinition, 36, $null, $null, $null) | Out-Null }
		catch [System.Management.Automation.MethodInvocationException] {
			$taskDescriptionUpdated = $false
			switch -regex ($Error[0].Exception.InnerException.InnerException.Message) {
				'0x80070005' { # access denied
					Write-Output $Error[0].Exception.InnerException.InnerException.Message }
				'0x80070002' {	# task not found
					Write-Output $Error[0].Exception.InnerException.InnerException.Message }
				default { $Error[0].Exception.Message }
			}
		}
		catch {
			$taskDescriptionUpdated = $false
			Write-Output Other Error
			Write-Output $Error[0].Exception.Message
		}
	}
	else { $taskDescriptionUpdated = $false
		Write-Output ("     description already contains " + $disableKey )
	}
	if ($taskDescriptionUpdated -eq $true) {
		Write-Output ("Added " + $disableKey + " to task description: " + $taskDefinition.RegistrationInfo.Description)
		Write-EventLogEntry -EventLogName 'Operations Manager' -EventSourceName 'Health Service Script' -EventId 223 -EventSeverity 'Information' -EventDescription ("
Description tag of scheduled task was added via SCOM task by user " + $userName + ". Monitoring will resume following the next discovery cycle.

Computer: %3") -EventParameter1 $ScriptName -EventParameter2 $computerName -EventParameter3 ""
	}
	else { Write-Output "Task description was not updated." }
}


Function Write-EventLogEntry
{
	param ([string]$EventLogName, [string]$EventSourceName, $EventId ,[string]$EventSeverity, [string]$EventDescription, [string]$EventParameter1, [string]$EventParameter2, [string]$EventParameter3) 
	# using .NET objects as they allow event parameters
	$newEvent = new-object System.Diagnostics.Eventinstance($EventId, 0, [system.diagnostics.eventlogentrytype]::[string]$EventSeverity) 
	[system.diagnostics.EventLog]::WriteEvent([string]$EventSourceName, $newEvent, $EventDescription, $EventParameter1, $EventParameter2, $EventParameter3)
}

#call main function
Main