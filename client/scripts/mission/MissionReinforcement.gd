class_name MissionReinforcement
extends Resource
## Jaffa sent in once the alarm is raised, at a room attachment (normally a `spawn` component).
## Each entry arrives once per mission; the sum of `count` is the reinforcement budget.
@export var room: StringName
@export var attachment: StringName
@export_range(1, 4) var count: int = 2
## Seconds after the alarm before this group arrives.
@export var delay: float = 6.0
@export var shock_guard := false
@export var personal_shield := false
## Canonical SW-3 combat role for reinforcement troopers ("trooper", "officer", "heavy", "grenadier", "goauld_lord").
@export var combat_role: String = "trooper"
## Optional SW-3 specialist role applied specifically to rank 0 lead.
@export var lead_role: String = ""
## Optional display name when spawning a Goa'uld System Lord boss.
@export var boss_name: String = ""
