#!/usr/bin/env python3
"""Author typed neutral presets. Does not bake or duplicate structural geometry."""
from pathlib import Path
import json
ROOT = Path(__file__).resolve().parents[2] / 'client'
ROOMS = ['room04','room10','room11','room13','room15']
LONG = ['room10','room11','room13']


def marker(id, position, component='interaction', refs=(), required=True):
    return dict(id=id, position=position, component=component, refs=refs, required=required)


def prop(id, position, size, approach, component='prop', **kwargs):
    return dict(id=id, position=position, size=size, approach=approach, component=component, **kwargs)


def common():
    return [prop('console',(2.6,0,-2.6),(1,1,.8),(-1.2,0,1.2),'console',refs=['systems.control']),
            marker('patrol_entry',(0,0,-1),'patrol'),marker('patrol_exit',(0,0,1),'patrol')]


def cargo():
    return common() + [prop('crate_01',(-2.6,0,-2.6),(1.4,1.2,1.4),(1.2,0,1.2)),
                       prop('crate_02',(-2.6,0,2.6),(1.4,1.2,1.4),(1.2,0,-1.2)),
                       prop('crate_03',(2.6,0,2.6),(1.4,1.2,1.4),(-1.2,0,-1.2)),
                       marker('cover_01',(1.3,0,1.3),'cover',required=False),marker('cargo_interaction',(0,0,0),'objective')]


PRESETS = [
 ('jaffa_barracks','Jaffa barracks',ROOMS, common()+[
     prop('bed_01',(-2.7,0,-2.5),(1.3,.5,1.8),(1.3,0,1.1)),
     prop('bed_02',(-2.7,0,2.5),(1.3,.5,1.8),(1.3,0,-1.1)),
     prop('weapon_rack',(2.7,0,2.7),(1,1.8,.5),(-1.3,0,-1.3)),
     marker('squad_01',(0,0,-1.2),'spawn'),marker('squad_02',(0,0,0),'spawn'),marker('squad_03',(0,0,1.2),'spawn')],['squad.spawn']),
 ('security_checkpoint','Security checkpoint',ROOMS,common()+[
     prop('cover_left',(-2.6,0,2.6),(1.4,1,1.4),(1.2,0,-1.2),'cover'),
     prop('cover_right',(2.6,0,2.6),(1.4,1,1.4),(-1.2,0,-1.2),'cover'),
     marker('guard',(0,0,0),'spawn'),marker('door_control',(-2.6,0,-2.6),'system',['doors.access','alarm.zone'])],['doors.access','alarm.zone']),
 ('armoury','Armoury',ROOMS,common()+[
     dict(id='armour_station',position=(2.6,0,2.6),scene='ArmoryArmorStation',bounds=(-.7,0,-.35,1.4,2.1,.7),approach=(-1.2,0,-1.2),component='equipment'),
     prop('weapon_rack',(-2.6,0,-2.6),(1,1.8,.5),(1.2,0,1.2)),
     marker('inventory',(-2.6,0,2.6),'interaction',['inventory.storage'])],['inventory.storage']),
 ('detention','Detention / holding',ROOMS,common()+[
     prop('cot',(-2.7,0,2.5),(1.3,.5,1.8),(1.3,0,-1.1)),
     marker('prisoner',(2.6,0,2.6),'objective'),marker('guard',(0,0,0),'spawn'),
     marker('cell_access',(-2.6,0,-2.6),'system',['doors.access']),marker('extraction',(1.2,0,1.2),'objective')],['doors.access','objective.extraction']),
 ('generator','Generator / reactor',LONG,common()+[
     prop('machinery',(0,0,5),(2,2.4,3),(0,0,-2.5),'equipment'),
     marker('system_objective',(0,0,2.3),'objective',['systems.power','objective.repair','objective.sabotage'])],['systems.power']),
 ('cargo','Cargo / storage',ROOMS,cargo(),['inventory.cargo']),
 ('engineering','Maintenance / engineering',LONG,common()+[
     prop('equipment_bay',(0,0,5),(2,1.5,3),(0,0,-2.5),'equipment'),
     marker('repair',(0,0,2.3),'objective',['systems.service'])],['systems.service']),
 ('security_control','Security / alarm control',ROOMS,common()+[
     prop('security_console',(-2.6,0,-2.6),(1,1,.8),(1.2,0,1.2),'console'),
     marker('door_network',(0,0,0),'system',['doors.network','alarm.zone'])],['doors.network','alarm.zone']),
 ('ring_transport','Transport rings',['room15'],[
     dict(id='Rings',position=(0,0,0),scene='TransportRings',anchor='transport',bounds=(-2.5,.02,-2.5,5,10.2,5),component='rings',approach=(0,0,0)),
     prop('console',(-3.2,0,-3.2),(.5,1,.5),(.9,0,.9),'console'),
     marker('arrival',(0,0,0),'spawn'),marker('patrol_entry',(0,0,-3),'patrol')],['transport.destination']),
 ('stargate_dhd','Stargate / DHD',['room16'],[
     dict(id='Stargate',position=(0,0,0),scene='Stargate',anchor='gate',bounds=(-3.5,-3.48,-2,7,7.2,8),component='gate',approach=(0,-3.5,7)),
     dict(id='DHD',position=(14,0,13),scene='DHDConsole',bounds=(-.65,0,-.5,1.3,1.3,1),component='dhd',approach=(-1.8,0,0)),
     marker('dialling',(12.2,0,13),'interaction'),marker('entry_extraction',(8,0,15.5),'objective')],['gate.destination','objective.entry','objective.extraction']),
 ('sarcophagus','Sarcophagus chamber',LONG,common()+[
     prop('sarcophagus',(0,0,5),(1.6,.9,2.6),(0,0,-2.4),'equipment',refs=['healing.future','revival.future'])],['healing.future','revival.future']),
 ('laboratory_medical','Laboratory / medical',LONG,common()+[
     prop('examination_table',(-2.6,0,4),(1.2,.9,2.2),(1.2,0,0),'equipment'),
     prop('lab_equipment',(2.6,0,4),(1,1.4,1),(-1.2,0,0),'equipment'),
     marker('intelligence',(0,0,4),'objective')],['objective.intelligence']),
 ('command','Bridge / command',['room11','room13'],common()+[
     prop('secondary_console',(-2.6,0,-2.6),(1,1,.8),(1.2,0,1.2),'console'),
     prop('main_console',(8,0,4),(2,1,1),(0,0,-1.5),'console'),
     marker('commander',(4,0,4),'spawn'),marker('display',(4,0,1),'system',['command.display']),
     marker('security_access',(4,0,0),'system',['doors.access'])],['command.display','doors.access']),
 ('cargo_hangar','Cargo bay / glider hangar',['room16'],[
     dict(id='vehicle_clearance',position=(0,0,0),anchor='cargo',bounds=(-3,.02,-4,6,5,8),component='clearance',approach=(0,0,-6.5)),
     prop('cargo_left',(0,0,20),(2,2,2),(1.8,0,0)),prop('cargo_right',(16,0,20),(2,2,2),(-1.8,0,0)),
     marker('access_control',(0,0,25),'system',['doors.access']),marker('cargo_objective',(8,0,13.5),'objective')],['vehicle.future','doors.access']),
 ('ceremonial','Throne / ceremonial',['room13','room16'],[
     prop('dais',(4,0,12),(3,.15,3),(0,0,-3),'equipment'),
     prop('throne',(4,.15,12),(1,1.8,1),(0,-.15,-3),'equipment'),
     marker('guard_left',(0,0,12),'spawn'),marker('guard_right',(8,0,12),'spawn'),
     marker('side_approach_left',(0,0,8),'patrol'),marker('side_approach_right',(8,0,8),'patrol'),
     marker('character_objective',(4,0,9),'objective')],['objective.character']),
 ('observation_communications','Observation / communications',ROOMS,common()+[
     prop('communications_display',(-2.6,0,-2.6),(2,1.5,.3),(1.2,0,1.2),'equipment'),
     marker('staff_station',(0,0,0),'spawn'),marker('intelligence',(0,0,1.2),'objective')],['communications.network','objective.intelligence']),
]


ALIASES = {'jaffa_barracks': ['barracks', 'sleeping quarters', 'troop quarters', 'dormitory'], 'security_checkpoint': ['checkpoint', 'guard post', 'bottleneck'], 'armoury': ['armory', 'equipment storage', 'weapons'], 'detention': ['holding cells', 'prison', 'extraction'], 'generator': ['reactor', 'power plant', 'power control'], 'cargo': ['storage', 'warehouse', 'crates'], 'engineering': ['maintenance', 'service room', 'repair'], 'security_control': ['control room', 'security office', 'alarm control'], 'ring_transport': ['transport area', 'ring room', 'teleport'], 'stargate_dhd': ['gate room', 'stargate chamber', 'dialling'], 'sarcophagus': ['revival interface', 'healing interface'], 'laboratory_medical': ['medical room', 'laboratory', 'sickbay', 'lab', 'infirmary'], 'command': ['bridge', 'command center', 'command centre', 'control room'], 'cargo_hangar': ['glider bay', 'vehicle bay', 'hangar'], 'ceremonial': ['throne room', 'ceremonial hall'], 'observation_communications': ['observation', 'communications room', 'intelligence']}


def vector(value):
    return 'Vector3('+','.join(map(str,value))+')'


def packed(values):
    return 'PackedStringArray('+','.join(json.dumps(v) for v in values)+')'


def bake():
    output=ROOT/'resources/room_presets'
    output.mkdir(exist_ok=True)
    for id,label,modules,attachments,systems in PRESETS:
        lines=['[gd_resource type="Resource" script_class="LevelRoomPreset" format=3]',
               '[ext_resource type="Script" path="res://scripts/level/LevelRoomPreset.gd" id="1"]',
               '[ext_resource type="Script" path="res://scripts/level/LevelRoomAttachment.gd" id="2"]']
        scenes=sorted({a['scene'] for a in attachments if a.get('scene')})
        for scene in scenes:
            lines.append(f'[ext_resource type="PackedScene" path="res://scenes/props/{scene}.tscn" id="{scene}"]')
        for index,a in enumerate(attachments):
            x,y,z=a['position']
            lines += [f'[sub_resource type="Resource" id="a{index}"]','script = ExtResource("2")',f'id = &"{a["id"]}"',f'component = &"{a.get("component","prop")}"',
                      f'local_transform = Transform3D(1,0,0,0,1,0,0,0,1,{x},{y},{z})',f'approach = {vector(a.get("approach",(0,0,0)))}']
            if not a.get('required',True):lines.append('required = false')
            if a.get('anchor'):lines.append(f'anchor = &"{a["anchor"]}"')
            if a.get('scene'):
                lines.append(f'scene = ExtResource("{a["scene"]}")')
                if a['scene'] in ['ArmoryArmorStation','DHDConsole']:lines.append('blocks_movement = true')
            if a.get('size'):
                sx,sy,sz=a['size']
                lines += [f'placeholder_size = {vector(a["size"])}',f'bounds = AABB({-sx/2},0,{-sz/2},{sx},{sy},{sz})']
            elif a.get('bounds'):
                lines.append('bounds = AABB('+','.join(map(str,a['bounds']))+')')
            if a.get('refs'):lines.append('references = '+packed(a['refs']))
        lines += ['[resource]','script = ExtResource("1")',f'id = &"{id}"',f'label = {json.dumps(label)}','compatible_modules = '+packed(modules),
                  'attachments = Array[ExtResource("2")](['+', '.join(f'SubResource("a{i}")' for i in range(len(attachments)))+'])','system_references = '+packed(systems), 'description = '+json.dumps(label+' configuration with reusable equipment and reachable markers; no mission progression.'), 'synonyms = '+packed(ALIASES[id])]
        (output/(id+'.tres')).write_text('\n'.join(lines)+'\n')


if __name__=='__main__':bake()
