# Returns SCOM PropertyBags of Task Scheduler Tasks and PowerShell Scheduled Jobs
#
#	output is to be used both by discovery, monitors and rules
#
#
# Version 1.0 - 09. May 2014 - initial            			  - Raphael Burri - raburri@bluewin.ch
# Version 2.0 - 04. June 2014 - added PSScheduledJob support  - Raphael Burri - raburri@bluewin.ch

param ( [string]$scriptName = 'Custom.TaskScheduler2.Task.GetTaskProperties.ps1',
		[string]$discoverWindowsTasks = 'false',
		[int]$lastRunDurationLookback = 900,
		[string]$debugParam = 'true'
		)

function Get-AllTasks($path, $lastRunDurationLookback) 
	{
	$tasks = @()
   	#only fetch system tasks (folders in \Microsoft\Windows with the exception of Backup), if asked to
	If (($DiscoverWindowsTasks -eq $true) -or (($discoverWindowsTasks -eq $false) -and (($path -notmatch "^\\Microsoft\\Windows\\") -or ($path -match "^\\Microsoft\\Windows\\(Backup|PowerShell)\\"))))
		{
	   	# Get folder's root tasks
    	$schedule.GetFolder($path).GetTasks(0) | % `
			{
			$isPSScheduledJob = $false
			$TaskTriggerText = ""
			$TaskActionText = ""
			$TaskLastRuntime = -1
			$TaskLastRuntimeMinutes = -1
			$TaskRunningSince = -1
			$cleanTask = New-Object psobject
			$cleanTask | Add-Member -MemberType NoteProperty -Name Name -Value $_.Name
			$cleanTask | Add-Member -MemberType NoteProperty -Name Path -Value $_.Path
			$cleanTask | Add-Member -MemberType NoteProperty -Name Author -Value $_.Definition.RegistrationInfo.Author
			$cleanTask | Add-Member -MemberType NoteProperty -Name Description -Value $_.Definition.RegistrationInfo.Description
			$cleanTask | Add-Member -MemberType NoteProperty -Name User -Value $_.Definition.Principal.userId
			$cleanTask | Add-Member -MemberType NoteProperty -Name Hidden -Value $_.Definition.Settings.Hidden
			
			#if task runtime doesn't have a date then it actually hasn't ever run so far. The timestamp will be 12/30/1899 12:00:00 AM
			If (((Get-Date) - $_.LastRunTime).Days -lt 36500)
				{
				#no SCOM DB overloading --> return static text.
				$cleanTask | Add-Member -MemberType NoteProperty -Name LastRunTime -Value "HasDate"
				}
			Else
				{
				$cleanTask | Add-Member -MemberType NoteProperty -Name LastRunTime -Value "Never"
				}
			
			#likewise for next run (e.g. tasks without a schedule)
			If (((Get-Date) - $_.NextRunTime).Days -lt 36500)
				{
				#no SCOM DB overloading --> return static text.
				$cleanTask | Add-Member -MemberType NoteProperty -Name NextRunTime -Value "HasDate"
				}
			Else
				{
				$cleanTask | Add-Member -MemberType NoteProperty -Name NextRunTime -Value "NotDefined"
				}
			
			#if the task has not run so far then ignore the last result
			If ($cleanTask.LastRunTime -eq "Never") {$cleanTask | Add-Member -MemberType NoteProperty -Name LastTaskResult -Value ""}
			else {$cleanTask | Add-Member -MemberType NoteProperty -Name LastTaskResult -Value $_.LastTaskResult}
			
			$cleanTask | Add-Member -MemberType NoteProperty -Name State -Value $_.State
			#add text for state
			switch ($_.State) {
				0 {$cleanTask | Add-Member -MemberType NoteProperty -Name StateText -Value $TASK_STATE_0}
				1 {$cleanTask | Add-Member -MemberType NoteProperty -Name StateText -Value $TASK_STATE_1}
				2 {$cleanTask | Add-Member -MemberType NoteProperty -Name StateText -Value $TASK_STATE_2}
				3 {$cleanTask | Add-Member -MemberType NoteProperty -Name StateText -Value $TASK_STATE_3}
				4 {$cleanTask | Add-Member -MemberType NoteProperty -Name StateText -Value $TASK_STATE_4}
				default {$cleanTask | Add-Member -MemberType NoteProperty -Name StateText -Value "Unknown"}
				}
			#assume the task has no schedule based triggers	- overwrite if otherwise
			$cleanTask | Add-Member -MemberType NoteProperty -Name TaskIsScheduled -Value 'False'
			#build one string describing the triggers
			
			foreach ($trigger in $_.Definition.Triggers)
				{
				#trigger.Enabled gives localized output. As the monitors are later matching this for 'True' resp. 'False', this need to be changed into an english string
				If ($trigger.Enabled -eq $true) { $TriggerStateText = "True" }
				Else { $TriggerStateText = "False" }
				switch ($trigger.Type) {
					0 {$TaskTriggerText = $TaskTriggerText + $TriggerStateText + ": " + $TRIGGER_TYPE_0 + " ||| "}
					1 {
						$TaskTriggerText = $TaskTriggerText + $TriggerStateText + ": " + $TRIGGER_TYPE_1 + " ||| "
						if ($trigger.Enabled -eq $true) {$cleanTask | Add-Member -MemberType NoteProperty -Name TaskIsScheduled -Value 'True' -Force}
						}
					2 {
						$TaskTriggerText = $TaskTriggerText + $TriggerStateText + ": " + $TRIGGER_TYPE_2 + " ||| "
						if ($trigger.Enabled -eq $true) {$cleanTask | Add-Member -MemberType NoteProperty -Name TaskIsScheduled -Value 'True' -Force}
						}
					3 {
						$TaskTriggerText = $TaskTriggerText + $TriggerStateText + ": " + $TRIGGER_TYPE_3 + " ||| "
						if ($trigger.Enabled -eq $true) {$cleanTask | Add-Member -MemberType NoteProperty -Name TaskIsScheduled -Value 'True' -Force}
						}
					4 {
						$TaskTriggerText = $TaskTriggerText + $TriggerStateText + ": " + $TRIGGER_TYPE_4 + " ||| "
						if ($trigger.Enabled -eq $true) {$cleanTask | Add-Member -MemberType NoteProperty -Name TaskIsScheduled -Value 'True' -Force}
						}
					5 {$TaskTriggerText = $TaskTriggerText + $TriggerStateText + ": " + $TRIGGER_TYPE_5 + " ||| "}
					6 {$TaskTriggerText = $TaskTriggerText + $TriggerStateText + ": " + $TRIGGER_TYPE_6 + " ||| "}
					7 {$TaskTriggerText = $TaskTriggerText + $TriggerStateText + ": " + $TRIGGER_TYPE_7 + " ||| "}
					8 {$TaskTriggerText = $TaskTriggerText + $TriggerStateText + ": " + $TRIGGER_TYPE_8 + " ||| "}
					9 {$TaskTriggerText = $TaskTriggerText + $TriggerStateText + ": " + $TRIGGER_TYPE_9 + " ||| "}
					11 {
						switch ($trigger.StateChange) {
							1 {$TaskTriggerText = $TaskTriggerText + $TriggerStateText + ": " + $TRIGGER_STATE_CHANGE_1 + " ||| "}
							2 {$TaskTriggerText = $TaskTriggerText + $TriggerStateText + ": " + $TRIGGER_STATE_CHANGE_2 + " ||| "}
							3 {$TaskTriggerText = $TaskTriggerText + $TriggerStateText + ": " + $TRIGGER_STATE_CHANGE_3 + " ||| "}
							4 {$TaskTriggerText = $TaskTriggerText + $TriggerStateText + ": " + $TRIGGER_STATE_CHANGE_4 + " ||| "}
							7 {$TaskTriggerText = $TaskTriggerText + $TriggerStateText + ": " + $TRIGGER_STATE_CHANGE_7 + " ||| "}
							8 {$TaskTriggerText = $TaskTriggerText + $TriggerStateText + ": " + $TRIGGER_STATE_CHANGE_8 + " ||| "}
							default {$TaskTriggerText = $TaskTriggerText + "Unknown (StateChange " + $trigger.StateChange + ") ||| "}
							}
						}
					default {$TaskTriggerText = $TaskTriggerText + "Unknown (Type " + $trigger.Type + ") ||| "}
					}
				}
			#clean up string
			if ($TaskTriggerText.length -gt 0) {$TaskTriggerText = ($TaskTriggerText.Substring(0,$TaskTriggerText.length - 5)).trim()}
			$cleanTask | Add-Member -MemberType NoteProperty -Name TriggerText -Value $TaskTriggerText
	
			#build one string describing the actions
			foreach ($action in $_.Definition.Actions) {
				switch ($action.type)	{
					0 {#check if it is a PSScheduledJob
						if (($cleanTask.path -imatch "^\\Microsoft\\Windows\\PowerShell\\") -and `
								($action.arguments -imatch "\[Microsoft\.PowerShell\.ScheduledJob\.ScheduledJobDefinition\]::LoadFromStore\("))
							{
							$isPSScheduledJob = $true
							}
						$TaskActionText = $TaskActionText + $TASK_ACTION_0 + ": " + $action.path + " " + $action.arguments + " ||| "
						}
					5 {$TaskActionText = $TaskActionText + $TASK_ACTION_5 + ": " + $action.classId + " " + $action.data + " ||| "}
					6 {$TaskActionText = $TaskActionText + $TASK_ACTION_6 + ": ""Server: " + $action.Server + ", " + `
								   "From: " + $action.From + ", " + `
								   "To: " + $action.To + ", " + `
								   "Cc:	" + $action.Cc + ", " + `
								   "Bcc: " + $action.Bcc + ", " + `
								   "Subject: " + $action.Subject + ", " + `
								   "Text:    " + $action.Body + """ ||| " 
					  }
					7 {$TaskActionText = $TaskActionText + $TASK_ACTION_7 + ": ""Title: " + $action.Title + ", " + `
								   "Text: " + $action.MessageBody + """ ||| "
						#message boxes always seem to return an exit code of 1. The MP will have to take this into account
					  }
					default {$TaskActionText = $TaskActionText + "Unknown (Type " + $action.Type + ") ||| "} 
					}
				}
			#clean up string
			if ($TaskActionText.length -gt 0) {$TaskActionText = ($TaskActionText.Substring(0,$TaskActionText.length - 5)).trim()}
			
			$cleanTask | Add-Member -MemberType NoteProperty -Name ActionText -Value $TaskActionText
			
			#last completed execution duration (from event log) and current run duration
			#     will be -1 if not applicable or task already running
			# get last end time from event log
			#   note: this only applies to "classic" scheduled task; not PSScheduledJob
		#	if (($lastRunDurationLookback -gt 0) -and ($isPSScheduledJob -eq $false))
			if ($lastRunDurationLookback -gt 0) 
				{
				$taskLastEndTime = (Get-TaskLastEndTime -taskPath $cleanTask.Path)
				#if recently then get the longest run
				if ((((Get-Date) - $taskLastEndTime).TotalSeconds -le $lastRunDurationLookback) -and ($_.State -gt 1))
					{
					#get the longest run observed during lookback timeframe from eventlog
					$TaskLastRuntimes = @(Get-TaskLastRunDurations -taskPath $cleanTask.Path -lookbackSeconds $lastRunDurationLookback |
						Sort-Object @{Expression={$_.RunTimeSeconds}; Ascending=$false})
					$TaskLastRuntime = $TaskLastRuntimes.Get(0).RunTimeSeconds
					$TaskLastRuntimeMinutes = [decimal]::round(($TaskLastRuntime / 60),2)
					Write-Host Observed $TaskLastRuntimes.Count end events of task $_.Name within the last $lastRunDurationLookback seconds. Longest RunTime of those was: $TaskLastRuntime seconds 
					}
				}
			$cleanTask | Add-Member -MemberType NoteProperty -Name LastRunDurationSeconds -Value $TaskLastRuntime
			$cleanTask | Add-Member -MemberType NoteProperty -Name LastRunDurationMinutes -Value $TaskLastRuntimeMinutes
			#if currently running see how long
			if ($_.State -eq 4)
				{
				#get how long since it's been started from Windows event log
				$TaskRunningSince = [decimal]::round(((Get-Date) - $_.LastRunTime).TotalMinutes, 2)
				}	
			$cleanTask | Add-Member -MemberType NoteProperty -Name CurrentRunDurationMinutes -Value $TaskRunningSince
			
			#from SCOM perspective, scheduledtask and PSScheduledJob are mostly identical
			#   however; in order to check on their error, warning and output additional checking on their result.xml is required
			#   note: PSScheduledJob's return code will ALWAYS be 0, regardless of expcetions that might have been thrown.
			$cleanTask | Add-Member -MemberType NoteProperty -Name IsPSScheduledJob -Value $isPSScheduledJob
			if ($isPSScheduledJob -eq $true)
				{
				$psJobResult =  GetScheduledJobResult -scheduledTaskActionParameter $cleanTask.ActionText
				$objAPI.LogScriptEvent($scriptName, 1, 4, "DEBUG: " + $cleanTask.ActionText + "

" + $psJobResult)
				if ($psJobResult -ne $null)
					{
					#overwrite actiontext with PS scriptblock
					$actionText = ($TASK_ACTION_0_PS + ": " + $psJobResult.PSJobCommand)
					$cleanTask | Add-Member -MemberType NoteProperty -Name ActionText -Value $actionText -Force
					#specific PSScheduledJob properties
					$cleanTask | Add-Member -MemberType NoteProperty -Name PSJobOutputCount -Value $psJobResult.PSJobOutputCount
					$cleanTask | Add-Member -MemberType NoteProperty -Name PSJobOutputTypes -Value $psJobResult.PSJobOutputTypes
					$cleanTask | Add-Member -MemberType NoteProperty -Name PSJobOutputContent -Value $psJobResult.PSJobOutputContent
					$cleanTask | Add-Member -MemberType NoteProperty -Name PSJobErrorCount -Value $psJobResult.PSJobErrorCount
					$cleanTask | Add-Member -MemberType NoteProperty -Name PSJobErrorContent -Value $psJobResult.PSJobErrorContent
					$cleanTask | Add-Member -MemberType NoteProperty -Name PSJobWarningCount -Value $psJobResult.PSJobWarningCount
					$cleanTask | Add-Member -MemberType NoteProperty -Name PSJobWarningContent -Value $psJobResult.PSJobWarningContent
				
					}
				}
			else
				{   #return empty strings for classic tasks
					$cleanTask | Add-Member -MemberType NoteProperty -Name PSJobOutputCount -Value 0
					$cleanTask | Add-Member -MemberType NoteProperty -Name PSJobOutputTypes -Value ""
					$cleanTask | Add-Member -MemberType NoteProperty -Name PSJobOutputContent -Value ""
					$cleanTask | Add-Member -MemberType NoteProperty -Name PSJobErrorCount -Value 0
					$cleanTask | Add-Member -MemberType NoteProperty -Name PSJobErrorContent -Value ""
					$cleanTask | Add-Member -MemberType NoteProperty -Name PSJobWarningCount -Value 0
					$cleanTask | Add-Member -MemberType NoteProperty -Name PSJobWarningContent -Value ""
				}
			
			#debug output to event log
			if ($debugParam -eq $true)
				{
				$cleanTaskOutput = "
Task Scheduler Task
-----------
Name: " + [string]$cleanTask.Name + "
Path: " + [string]$cleanTask.Path + "
Author: " + [string]$cleanTask.Author + "
User: " + [string]$cleanTask.User + "
IsPSScheduledJob: " + [string]$cleanTask.IsPSScheduledJob + "

Hidden: " + [string]$cleanTask.Hidden + "
LastRunTime: " + [string]$cleanTask.LastRunTime + "
NextRunTime: " + [string]$cleanTask.NextRunTime + "
LastTaskResult: " + [string]$cleanTask.LastTaskResult + "
State: " + [string]$cleanTask.State + "
StateText: " + [string]$cleanTask.StateText  +  "
TaskIsScheduled: " + [string]$cleanTask.TaskIsScheduled + "
TriggerText: " + [string]$cleanTask.TriggerText + "
ActionText: " + [string]$cleanTask.ActionText + "

LastRunDurationSeconds: " + [string]$cleanTask.LastRunDurationSeconds + "
LastRunDurationMinutes: " + [string]$cleanTask.LastRunDurationMinutes + "
CurrentRunDurationMinutes: " + [string]$cleanTask.CurrentRunDurationMinutes + "

PSJobOutputCount: " + [string]$cleanTask.PSJobOutputCount + "
PSJobErrorCount: " + [string]$cleanTask.PSJobErrorCount + "
PSJobWarningCount: " + [string]$cleanTask.PSJobWarningCount

				$objAPI.LogScriptEvent($scriptName, 9625, 4, "DEBUG: " + $cleanTaskOutput)
				}	
	
			Write-Host adding task $cleanTask.Path
			$tasks += @($cleanTask)
			}	    
    	}

    # Get tasks from subfolders
    $schedule.GetFolder($path).GetFolders(0) | % {
		$tasks += @(Get-AllTasks -path $_.Path -lastRunDurationLookback $lastRunDurationLookback)
    	}

    #Output
    Return $tasks
}

function Get-TaskLastEndTime 
	([string]$taskPath)
	{
	#fetch the most recent success event (102) that occured within a timeframe
	# in case taskpath contains quotes, have to escape (double) them
	$taskPath = $taskPath.Replace("'","''")
	$successXPath = "*[System[((EventID=102) or (EventID=111))]] and *[EventData[Data[1]='" + $taskPath + "']]"
	$taskSuccessEvent = get-winevent -LogName 'Microsoft-Windows-TaskScheduler/Operational' -FilterXPath $successXPath -MaxEvents 1 -ErrorAction SilentlyContinue
	if ($taskSuccessEvent)
		{
		return [datetime]$taskSuccessEvent.TimeCreated
		}
	else
		{
		#no end event found within the timeframe; return null
		return [datetime]"1/1/1600"
		}
	}
	
function Get-TaskLastRunDurations 
	([string]$taskPath, [int]$lookbackSeconds)
	{
	$taskDurations = @()
	# in case taskpath contains quotes, have to escape (double) them
	$taskPath = $taskPath.Replace("'","''")
	#fetch the most recent success (102) or terminated (111) events that occured within a timeframe
	$successXPath = "*[System[((EventID=102) or (EventID=111)) and TimeCreated[timediff(@SystemTime) <= " + $lookbackSeconds * 1000 + "]]] and *[EventData[Data[1]='" + $taskPath + "']]"
	$taskSuccessEvents = @(get-winevent -LogName 'Microsoft-Windows-TaskScheduler/Operational' -FilterXPath $successXPath -ErrorAction SilentlyContinue)
	if ($taskSuccessEvents.Count -gt 0)
		{
		foreach ($taskSuccessEvent in $taskSuccessEvents)
			{
			$taskDuration = New-Object psobject
			$taskDuration | Add-Member -MemberType NoteProperty -Name EndTime -Value $taskSuccessEvent.TimeCreated		
			#get start event (100) with the same TaskName and InstanceId
			$global:taskSuccessEvent = $taskSuccessEvent
			#InstanceId is 3rd on 102 event / 2nd on 111 event
			if ($taskSuccessEvent.Id -eq 102) {$taskInstanceId = $taskSuccessEvent.Properties[2].Value.ToString()}
			else {$taskInstanceId = $taskSuccessEvent.Properties[1].Value.ToString()}
			$startXPath = "*[System[(EventID=100)]] and *[EventData[(Data[1]='" + $taskSuccessEvent.Properties[0].Value.ToString().Replace("'","''") + "' and Data[3]='{" + $taskInstanceId + "}')]]"
			$taskStartEvent = Get-WinEvent -LogName 'Microsoft-Windows-TaskScheduler/Operational' -FilterXPath $startXPath -MaxEvents 1 -ErrorAction SilentlyContinue
			if ($taskStartEvent) 
				{
				$taskDuration | Add-Member -MemberType NoteProperty -Name StartTime -Value $taskStartEvent.TimeCreated
				$taskRunTimeSeconds = [decimal]::round(($taskSuccessEvent.TimeCreated - $taskStartEvent.TimeCreated).TotalSeconds, 2)
				}
			else
				{
				#no start event found within the timeframe; set duration to -1
				$taskDuration | Add-Member -MemberType NoteProperty -Name StartTime -Value "unknown"
				$taskRunTimeSeconds = -1
				}
			$taskDuration | Add-Member -MemberType NoteProperty -Name RunTimeSeconds -Value $taskRunTimeSeconds
			$taskDurations += $taskDuration
			}
		}
	return $taskDurations
	}

#PSScheduledJob related functions
function GetScheduledJobResult
	{
	param ([string]$scheduledTaskActionParameter)
	
	$scheduledJobDefinitionStrings = GetScheduledJobDefinitionStrings -scheduledTaskCommand $scheduledTaskActionParameter
	$objAPI.LogScriptEvent($scriptName, 2, 4, "DEBUG:
" + $scheduledJobDefinitionStrings.Item("jobdefname") + "
" + $scheduledJobDefinitionStrings.Item("jobdefpath"))
	#see if jobdefinition can be loaded (proves that it is indeed a valid job)
	try {
		#import module to get full support
		if (-not (Get-Module -Name PSScheduledJob))	{Import-Module PSScheduledJob}
		$jobDefinition = [Microsoft.PowerShell.ScheduledJob.ScheduledJobDefinition]::LoadFromStore($scheduledJobDefinitionStrings.Item("jobdefname"), $scheduledJobDefinitionStrings.Item("jobdefpath"))
		}
	catch {$jobDefinition = $null}
	$objAPI.LogScriptEvent($scriptName, 3, 4, "DEBUG:
" + $jobDefinition)
	
	if ($jobDefinition -ne $null)
		{
		$jobResult = New-Object psobject
		$jobResult | Add-Member -MemberType NoteProperty -Name PSJobName -Value $jobDefinition.Name
		$jobResult | Add-Member -MemberType NoteProperty -Name PSJobCommand -Value $jobDefinition.Command
		
		#as accessing job results isn't possible for a different user using PSScheduledJob module,
		#   go ahead and parse Results.xml directly
		$jobOutputFolder = $scheduledJobDefinitionStrings.Item("jobdefpath").Trim() + "\" + $scheduledJobDefinitionStrings.Item("jobdefname").Trim() + "\Output"
		
		#sort the output files according to their "Status_StopTime" value
		$sortedResultFiles = @(Get-ChildItem $JobOutputFolder -File -Recurse -Filter "Results.xml" |
			Sort-Object @{Expression={[System.DateTime]([xml](Get-Content -Path $_.FullName -ErrorAction SilentlyContinue)).ScheduledJob.StatusInfo.Status_StopTime.InnerText}; Ascending=$false})	
		#load most recent Results.xml
		if ($sortedResultFiles)
			{
			[xml](Get-Content -Path ($sortedResultFiles.Get(0)).FullName -ErrorAction SilentlyContinue) |
				% {
					$jobInstanceId = [System.Guid]$_.ScheduledJob.StatusInfo.Status_InstanceId.InnerText
					#should be completed always as it has a StopTime value
					$jobStatus = [System.Management.Automation.JobState]$_.ScheduledJob.StatusInfo.Status_State.InnerText
					$jobStartTime = [System.DateTime]$_.ScheduledJob.StatusInfo.Status_StartTime.InnerText
					$jobEndTime = [System.DateTime]$_.ScheduledJob.StatusInfo.Status_StopTime.InnerText
					$jobRunTimeMinutes = [decimal]::round(($jobEndTime - $jobStartTime).TotalMinutes, 2)
			
					#Results to objects built of strings (so SCOM can work with them)
					$outputItems = GetScheduledJobXMLItemsDetail -resultsType "Output" -xmlElement $_.ScheduledJob.ResultsInfo.Results_Output
					$errorItems = GetScheduledJobXMLItemsDetail -resultsType "Error" -xmlElement $_.ScheduledJob.ResultsInfo.Results_Error
					$warningItems = GetScheduledJobXMLItemsDetail -resultsType "Warning" -xmlElement $_.ScheduledJob.ResultsInfo.Results_Warning
					
					$jobResult | Add-Member -MemberType NoteProperty -Name PSJobStatus -Value $jobStatus
					$jobResult | Add-Member -MemberType NoteProperty -Name PSJobLastRunDurationMinutes -Value $jobRunTimeMinutes
					$jobResult | Add-Member -MemberType NoteProperty -Name PSJobOutputCount -Value $outputItems.Size
					$jobResult | Add-Member -MemberType NoteProperty -Name PSJobOutputTypes -Value $outputItems.ItemTypes
					$jobResult | Add-Member -MemberType NoteProperty -Name PSJobOutputContent -Value $outputItems.ItemContents
					
					$jobResult | Add-Member -MemberType NoteProperty -Name PSJobErrorCount -Value $errorItems.Size
					$jobResult | Add-Member -MemberType NoteProperty -Name PSJobErrorContent -Value $errorItems.ItemContents
					
					$jobResult | Add-Member -MemberType NoteProperty -Name PSJobWarningCount -Value $warningItems.Size
					$jobResult | Add-Member -MemberType NoteProperty -Name PSJobWarningContent -Value $warningItems.ItemContents
					
	
				}
			}
		return $jobResult
		}
	}

function GetScheduledJobDefinitionStrings
	{
	param ($scheduledTaskCommand)
	$scheduledJobDefMatch = "\[Microsoft\.PowerShell\.ScheduledJob\.ScheduledJobDefinition\]::LoadFromStore\(('|"")(?<jobname>.+)('|""),.*('|"")(?<jobstore>.+)('|"")\)"
	$scheduledTaskCommand -match $scheduledJobDefMatch | Out-Null
	# make sure double quotes are replaced
	return @{"jobdefname" = ($Matches.jobname).Replace("''", "'"); "jobdefpath" = ($Matches.jobstore).Replace("''", "'")}
	}
	

function GetScheduledJobXMLItemsDetail
	{
	param ([string]$resultsType, [System.Xml.XmlElement]$xmlElement)
	
	$itemCount = 0
	$allItemTypeString = ""
	$allItemContentString = ""
	if ($resultsType -eq "Warning") {$global:xmlElement = $xmlElement}
	
	if ($xmlElement.items._items.Size -gt 0)
		{
		foreach ($item in $xmlElement.items._items.ChildNodes)
			{
			#undo CliXML to get original object back
			if ($item.IsEmpty -eq $false)
				{
				$itemCount ++
				
				switch ($resultsType) {
					"Output" {
						$itemDeserialized = [System.Management.Automation.PSSerializer]::Deserialize($item.clixml.InnerText)
						#return the type
						$allItemTypeString = $allItemTypeString + ($itemDeserialized.GetType().FullName) + " ||| "
						#see if it can be converted to string
						try {
							$itemContentString = [System.String]$itemDeserialized
							}
						catch	{
							$itemContentString = [System.String]"'" + ($itemDeserialized.GetType().FullName) + "' can not be converted to a string object."
							}
						finally	{
							#truncate output if longer than 1024 characters
							if ($itemContentString.length -gt 1024) {$itemContentString = $itemContentString.Substring(0, 1024).trim()}
							$allItemContentString = $allItemContentString + $itemContentString + " ||| "
							}
						}
					"Error" {
						$itemDeserialized = [System.Management.Automation.PSSerializer]::Deserialize($item.clixml.InnerText)
						#return the type
						$global:zException = ($itemDeserialized.Exception)
						$allItemTypeString = $allItemTypeString + $itemDeserialized.Exception.SerializedRemoteInvocationInfo.InvocationName + " ||| "
						
						#see if it can be converted to string
						try {
							$itemContentString = [System.String]$itemDeserialized.Exception.SerializedRemoteException
							}
						catch	{
							$itemContentString = [System.String]"Exception can not be converted to a string object."
							}
						finally	{
							#truncate output if longer than 1024 characters
							if ($itemContentString.length -gt 1024) {$itemContentString = $itemContentString.Substring(0, 1024).trim()}
							$allItemContentString = $allItemContentString + $itemContentString + " ||| "
							}
						}
					"Warning" {
						#warning seems to be string natively
						$allItemTypeString = $allItemTypeString + "System.Management.Automation.WarningRecord" + " ||| "
						
						#see if it can be converted to string
						try {
							$itemContentString = [System.String]$item.message.'#text'
							}
						catch	{
							$itemContentString = [System.String]"Warning can not be converted to a string object."
							}
						finally	{
							#truncate output if longer than 1024 characters
							if ($itemContentString.length -gt 1024) {$itemContentString = $itemContentString.Substring(0, 1024).trim()}
							$allItemContentString = $allItemContentString + $itemContentString + " ||| "
							}
						}
					}		
				}
			}
			#clean last separator and shorten to a total of 8192 characters
			if ($allItemTypeString.length -gt 0) {
				$allItemTypeString = ($allItemTypeString.Substring(0,$allItemTypeString.length - 5)).trim()
				if ($allItemTypeString.length -gt 8192) {$allItemTypeString = $allItemTypeString.Substring(0, 8192)}
				}
			if ($allItemContentString.length -gt 0) {
				$allItemContentString = ($allItemContentString.Substring(0,$allItemContentString.length - 5)).trim()
				if ($allItemContentString.length -gt 8192) {$allItemContentString = $allItemContentString.Substring(0, 8192)}
				}
		}	
	$itemDetail = New-Object psobject
	$itemDetail | Add-Member -MemberType NoteProperty -Name ResultsType -Value $resultsType
	$itemDetail | Add-Member -MemberType NoteProperty -Name Size -Value $itemCount
	$itemDetail | Add-Member -MemberType NoteProperty -Name ItemTypes -Value $allItemTypeString
	$itemDetail | Add-Member -MemberType NoteProperty -Name ItemContents -Value $allItemContentString
	
	Return $itemDetail
	}


#region constvar
#constants & variables
$TASK_STATE_0 = "Unknown"
$TASK_STATE_1 = "Disabled"
# make 2, 3 and 4 use the SAME string (to avoid changing SCOM objet properties too often)
#$TASK_STATE_2 = "Queued""
$TASK_STATE_2 = "Ready / Queued / Running"
#$TASK_STATE_3 = "Ready""
$TASK_STATE_3 = "Ready / Queued / Running"
#$TASK_STATE_4 = "Running"
$TASK_STATE_4 = "Ready / Queued / Running"

$TASK_ACTION_0 = "Start a program" 		#"Exec" 		'"Represents an action that executes a command-line operation
$TASK_ACTION_0_PS = "PS job"
$TASK_ACTION_5 = "Custom handler" 		#"ComHandler"	'"This action fires a handler"
$TASK_ACTION_6 = "Send an e-mail"		#"This action sends an e-mail"
$TASK_ACTION_7 = "Display a message" 	#"ShowMessage"	'"This action shows a message box"


$TRIGGER_TYPE_0 = "On event" 							#"TASK_TRIGGER_EVENT" 				'"Starts the task when a specific event occurs"
$TRIGGER_TYPE_1 = "One time" 							#"TASK_TRIGGER_TIME" 					'"Starts the task at a specific time of day"
$TRIGGER_TYPE_2 = "Daily" 								#"TASK_TRIGGER_DAILY" 				'"Starts the task daily"
$TRIGGER_TYPE_3 = "Weekly" 								#"TASK_TRIGGER_WEEKLY" 				'"Starts the task weekly"
$TRIGGER_TYPE_4 = "Monthly" 							#"TASK_TRIGGER_MONTHLY" 				'"Starts the task monthly"
$TRIGGER_TYPE_5 = "Monthly at day of week"  			#"TASK_TRIGGER_MONTHLYDOW" 			'"Starts the task every month on a specific day of the week"
$TRIGGER_TYPE_6 = "On idle" 							#"TASK_TRIGGER_IDLE" 					'"Starts the task when the computer goes into an idle state"
$TRIGGER_TYPE_7 = "At task creation/modification" 		#"TASK_TRIGGER_REGISTRATION" 			'"Starts the task when the task is registered"
$TRIGGER_TYPE_8 = "At startup" 							#"TASK_TRIGGER_BOOT" 					'"Starts the task when the computer boots"
$TRIGGER_TYPE_9 = "At log on" 							#"TASK_TRIGGER_LOGON" 				'"Starts the task when a specific user logs on"
$TRIGGER_TYPE_11 = "TASK_TRIGGER_SESSION_STATE_CHANGE"	#"Triggers the task when a specific session state changes"
$TRIGGER_STATE_CHANGE_1 = "On connection to console session"		#TASK_CONSOLE_CONNECT
$TRIGGER_STATE_CHANGE_2 = "On disconnect from console session"		#TASK_CONSOLE_DISCONNECT
$TRIGGER_STATE_CHANGE_3 = "On connect to user session"				#TASK_REMOTE_CONNECT
$TRIGGER_STATE_CHANGE_4 = "On disconnect from user session"			#TASK_REMOTE_DISCONNECT
$TRIGGER_STATE_CHANGE_7 = "On workstation lock"						#TASK_SESSION_LOCK
$TRIGGER_STATE_CHANGE_8 = "On workstation unlock"					#TASK_SESSION_UNLOCK
#endregion

#region SCOMvar
#prepare SCOM stuff
$objAPI = New-Object -ComObject "MOM.ScriptAPI"
#convert SCOM "text" boolean
if ($discoverWindowsTasks -eq 'true') {$discoverWindowsTasks = $true} else {$discoverWindowsTasks = $false}
if ($debugParam -eq 'true') {$debugParam = $true} else {$debugParam = $false}
#endregion

#region main

#check if running on Windows 6.x (Server 2008 / Vista) or higher
if ([System.Environment]::OSVersion.Version.Major -lt 6) {
	if ($debugParam -eq $true) {$objAPI.LogScriptEvent($scriptName, 9624, 4, "DEBUG: Script returning empty bag as it is running on Windows " + [System.Environment]::OSVersion.VersionString + ". Windows 6.0 and higher are supported (>= Server 2008 / Vista). For legacy OS the Custom.Windows.TaskScheduler.Windows2003.Monitoring MP can be used.")}
	#return an empty property bag (make undiscovery possible)
	$objTaskBag = $objAPI.CreatePropertyBag() 
	$objTaskBag
	exit 0
	}

#getting scheduled task info in PoSh 2.0 requires COM object "Schedule.Service"
#    the cmdlets were only introduced in Server 2012 / Windows 8
#    as this script needs to run on Server 2008 / Vista as well just continue to use
#    COM.
$schedule = New-Object -ComObject "Schedule.Service"
$schedule.Connect() 

$objRootFolder = $schedule.GetFolder("\")
If ($objRootFolder.Name -eq "")
	{
	#failed to connect this time. Write a warning and quit with an incremental discovery
	#keeps OpsMgr from deleting already discovered objects if the provider failes temporarily
	#by returning Incremental Discovery Data
	$objAPI.LogScriptEvent($scriptName, 9623, 2, "Discovery script failed to access the Task Scheduler COM object ""Schedule.Service"". It is exiting without writing data.")
	}
Else
	{
	#enumerate root folder
	$tasks = @(Get-AllTasks -path $objRootFolder.Path -lastRunDurationLookback $lastRunDurationLookback)
	if ($tasks.Count -gt 0) {
		foreach ($task in $tasks)
			{
			#build a SCOM property bag
			$objTaskBag = $objAPI.CreatePropertyBag() 
			$objTaskBag.AddValue("IsPSScheduledJob", [string]$task.IsPSScheduledJob)
			$objTaskBag.AddValue("Name", [string]$task.Name)
			$objTaskBag.AddValue("Path", [string]$task.Path)
			$objTaskBag.AddValue("Author", [string]$task.Author)
			$objTaskBag.AddValue("User", [string]$task.User)
			$objTaskBag.AddValue("Description", [string]$task.Description)
			$objTaskBag.AddValue("Hidden", [string]$task.Hidden)
			$objTaskBag.AddValue("LastRunTime", [string]$task.LastRunTime)
			$objTaskBag.AddValue("NextRunTime", [string]$task.NextRunTime)
			$objTaskBag.AddValue("LastTaskResult", [string]$task.LastTaskResult)
			$objTaskBag.AddValue("State", [int]$task.State)
			$objTaskBag.AddValue("StateText", [string]$task.StateText)
			$objTaskBag.AddValue("TaskIsScheduled", [string]$task.TaskIsScheduled)
			$objTaskBag.AddValue("TriggerText", [string]$task.TriggerText)
			$objTaskBag.AddValue("ActionText", [string]$task.ActionText)
			$objTaskBag.AddValue("LastRunDurationSeconds", [double]$task.LastRunDurationSeconds)
			$objTaskBag.AddValue("LastRunDurationMinutes", [double]$task.LastRunDurationMinutes)
			$objTaskBag.AddValue("CurrentRunDurationMinutes", [double]$task.CurrentRunDurationMinutes)
			$objTaskBag.AddValue("DiscoverWindowsTasksSetting", [string]$discoverWindowsTasks)
			#PSscheduledJob
			$objTaskBag.AddValue("PSJobOutputCount", [int]$task.PSJobOutputCount)
			$objTaskBag.AddValue("PSJobOutputTypes", [string]$task.PSJobOutputTypes)
			$objTaskBag.AddValue("PSJobOutputContent", [string]$task.PSJobOutputContent)
			$objTaskBag.AddValue("PSJobErrorCount", [int]$task.PSJobErrorCount)
			$objTaskBag.AddValue("PSJobErrorContent", [string]$task.PSJobErrorContent)
			$objTaskBag.AddValue("PSJobWarningCount", [int]$task.PSJobWarningCount)
			$objTaskBag.AddValue("PSJobWarningContent", [string]$task.PSJobWarningContent)

			$objTaskBag
			}
		}
	else {
		#return an empty property bag (make undiscovery possible)
		$objTaskBag = $objAPI.CreatePropertyBag() 
		$objTaskBag
		}
	}

# Close com
[System.Runtime.Interopservices.Marshal]::ReleaseComObject($schedule) | Out-Null
Remove-Variable schedule

