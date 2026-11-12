class_name MissionAlarm
extends Resource
## An alarm console: an existing room attachment, named by room and attachment id. An alerted
## Jaffa that reaches it and works it for `raise_time` seconds raises the alarm. An operative
## can disable it first, after which it can never raise the alarm.
@export var room: StringName
@export var attachment: StringName = &"console"
## Seconds a Jaffa must stand at the console, uninterrupted, to raise the alarm.
@export var raise_time: float = 2.5
@export var prompt: String = "DISABLE ALARM"
