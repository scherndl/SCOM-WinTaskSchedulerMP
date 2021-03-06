# Custom.TaskScheduler2.Task.WorkflowTriggerEvent.ps1
# 
# Writes an entry to SCOM event log (with extra parameters)
#
# Parameters:

param ($scriptName = 'Custom.TaskScheduler2.Task.WorkflowTriggerEvent.ps1',
	$eventId = '1005',
	$waitTime = '300',
	$mpName = 'Custom.Windows.TaskScheduler.Windows2008.Monitoring',
	$mgName = 'none',
	$eventType = 'unknownType',
	$eventCount = '0',
	$timeStart = '',
	$timeEnd = '')

Function WriteEventLogEntry
{
	param ([string]$EventSourceName,
		$EventId,
		[string]$EventSeverity,
		[string]$EventDescription,
		[string]$EventParameter1,
		[string]$EventParameter2,
		[string]$EventParameter3,
		[string]$EventParameter4,
		[string]$EventParameter5,
		[string]$EventParameter6,
		[string]$EventParameter7,
		[string]$EventParameter8
		) 
	# using .NET objects as they allow event parameters
	$newEvent = new-object System.Diagnostics.Eventinstance($EventId, 0, [system.diagnostics.eventlogentrytype]::[string]$EventSeverity) 
	[System.diagnostics.EventLog]::WriteEvent([string]$EventSourceName, $newEvent, $EventDescription, $EventParameter1, $EventParameter2, $EventParameter3, $EventParameter4, $EventParameter5, $EventParameter6, $EventParameter7, $EventParameter8)
	
}

WriteEventLogEntry -EventSourceName 'Health Service Script' -EventId $eventId -EventSeverity 'Information' -EventDescription 'Windows TaskScheduler MP Helper Event.
This event is used to trigger Task Scheduler MP workflows.
Management Pack: %4
Management Group: %5

EventType: %6
EventCount: %7

TimeWindowStart: %8
TimeWindowEnd: %9

' -EventParameter1 $ScriptName -EventParameter2 $waitTime -EventParameter3 $MPName -EventParameter4 $MGName -EventParameter5 $eventType -EventParameter6 $eventCount -EventParameter7 $timeStart -EventParameter8 $timeEnd
