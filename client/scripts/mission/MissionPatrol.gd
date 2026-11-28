class_name MissionPatrol
extends Resource
## A looping hostile patrol over named rooms; each room contributes its `marker`.
@export var rooms: PackedStringArray = []
@export var marker: StringName = &"patrol"
@export_range(1, 4) var size: int = 2
@export var shock_guard := false
@export var personal_shield := false
## Canonical SW-3 combat role for patrol members ("trooper", "officer", "heavy", "grenadier", "goauld_lord").
@export var combat_role: String = "trooper"
## Optional SW-3 specialist role applied specifically to rank 0 lead (overrides `combat_role` for lead).
@export var lead_role: String = ""
## Optional display name when spawning a Goa'uld System Lord boss.
@export var boss_name: String = ""
