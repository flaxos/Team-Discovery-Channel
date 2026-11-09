#!/usr/bin/env python3
"""Bake Batch B PackedScenes and definitions explicitly, outside gameplay/editor placement."""
from math import atan, cos, sin, sqrt
from build_catalogue import ROOT, bake, vec


def tall_shells():
    bake(('Room15TransportChamber', 8, 8, 3,
          [(0, -4, 'north'), (0, 4, 'south')], 'chamber'), height=10.4)
    bake(('Room16HangarShell', 24, 32, 3,
          [(8, -4, 'north'), (0, 28, 'south_00'), (8, 28, 'south_01')], 'chamber'),
         height=12.0, socket_sizes={'north': (12, 10.0), 'south_01': (6, 2.8)})
    for name, slots in [
        ('Room15TransportChamber', [('transport', (0, 0, 0), (-2.5, .02, -2.5, 5, 10.2, 5))]),
        ('Room16HangarShell', [('gate', (8, 3.5, 8), (4.5, .02, 6, 7, 7.2, 8)),
                               ('cargo', (8, 0, 20), (-1, .02, 16, 18, 11.5, 10))])]:
        scene = ROOT / 'scenes/level/modules' / (name + '.tscn')
        definition = ROOT / 'resources/level_modules' / (name + '.tres')
        text = definition.read_text()
        anchors, clearances = [], []
        for id, position, bounds in slots:
            transform = 'Transform3D(1,0,0,0,1,0,0,0,1,' + ','.join(map(str,position)) + ')'
            with scene.open('a') as stream:
                stream.write(f'[node name="{id}" type="Marker3D" parent="Attachments/Interactions"]\ntransform = {transform}\n')
            anchors.append(f'"{id}": {transform}')
            clearances.append(f'"{id}": AABB(' + ','.join(map(str,bounds)) + ')')
        text += 'equipment_anchors = {' + ','.join(anchors) + '}\n'
        text += 'equipment_clearances = {' + ','.join(clearances) + '}\n'
        if 'Hangar' in name:
            text += 'connection_default = "open"\n'
        definition.write_text(text)


def ramp():
    name = 'Room14Ramp4m'
    # name, centre, size, X rotation, collision layer, optional portal ID
    boxes = []
    patches = []
    theta = atan(4 / 12)
    for index, (start, length, base, rise) in enumerate([(-4, 2, 0, 0), (-2, 12, 0, 4), (10, 2, 4, 0)]):
        angle = -theta if rise else 0
        normal = (0, cos(angle), sin(angle))
        centre = (0, base + rise / 2, start + length / 2)
        for kind, direction in [('Floor', -1), ('Roof', 1)]:
            p = tuple(centre[k] + normal[k] * .1 * direction + (3.4 if kind == 'Roof' and k == 1 else 0) for k in range(3))
            boxes.append((f'{kind}{index}', p, (3, .2, sqrt(length*length+rise*rise)), angle, 128 if kind == 'Roof' else 1, None))
            patches.append((f'{kind}{index}', (-1.5, base + (3.4 if kind == 'Roof' else 0), start), (3,0,0), (0,rise,length), tuple(n*direction for n in normal), ''))
        for side in [-1,1]:
            patches.append((f'Wall{side}_{index}', (side*1.5,base,start), (0,rise,length), (0,3.4,0), (side,0,0), ''))
            # Rail visuals sit against the collision wall; they add no protruding collider.
            boxes.append((f'Handrail{side}_{index}', (side*1.52,centre[1]+.95,centre[2]), (.04,.06,sqrt(length*length+rise*rise)), angle, 0, None))
    for side in [-1,1]:
        boxes.append((f'Wall{side}', (side*1.6,3.7,4), (.2,7.4,16), 0, 1, None))
    for id,z,y,sign in [('lower',-4,0,-1),('upper',12,4,1)]:
        boxes.append((id,(0,y+1.4,z-sign*.1),(3,2.8,.2),0,1,id))
        boxes.append(('Header'+id,(0,y+3.1,z-sign*.1),(3,.6,.2),0,1,None))
        patches.append(('Portal'+id,(-1.5,y,z),(3,0,0),(0,2.8,0),(0,0,sign),id))
        patches.append(('Header'+id,(-1.5,y+2.8,z),(3,0,0),(0,.6,0),(0,0,sign),''))
    scene = ['[gd_scene format=3]', '[ext_resource type="Script" path="res://scripts/level/LevelModule.gd" id="1"]',
             '[sub_resource type="StandardMaterial3D" id="mat"]','albedo_color = Color(0.32,0.38,0.41,1)']
    for i,(_,_,size,_,layer,_) in enumerate(boxes):
        if layer:
            scene += [f'[sub_resource type="BoxShape3D" id="s{i}"]',f'size = {vec(size)}']
        scene += [f'[sub_resource type="BoxMesh" id="m{i}"]',f'size = {vec(size)}']
    scene += [f'[node name="{name}" type="Node3D"]','script = ExtResource("1")',f'definition_path = "res://resources/level_modules/{name}.tres"']
    for branch in ['Structure','Structure/Collision','Structure/NavigationSource','Structure/PortalClosures','Visuals','Visuals/Closures','Sockets','Markers','Attachments','Attachments/Props','Attachments/Cover','Attachments/Interactions','Attachments/Spawns']:
        parent, _, leaf = branch.rpartition('/')
        scene += [f'[node name="{leaf}" type="Node3D" parent="{parent or "."}"]']
    for i,(id,p,size,angle,layer,portal) in enumerate(boxes):
        parent = 'Structure/PortalClosures' if portal else 'Structure/Collision'
        if layer:
            scene += [f'[node name="{id}" type="StaticBody3D" parent="{parent}"]',f'position = {vec(p)}',f'rotation = Vector3({angle},0,0)',f'collision_layer = {layer}',f'[node name="Shape" type="CollisionShape3D" parent="{parent}/{id}"]',f'shape = SubResource("s{i}")']
        visual = 'Visuals/Closures' if portal else 'Visuals'
        scene += [f'[node name="{id}" type="MeshInstance3D" parent="{visual}"]',f'position = {vec(p)}',f'rotation = Vector3({angle},0,0)',f'mesh = SubResource("m{i}")','material_override = SubResource("mat")',f'metadata/visual_slot = "{id}"',f'metadata/dimensions = {vec(size)}']
    definition = ['[gd_resource type="Resource" script_class="LevelModuleDefinition" format=3]',
                  '[ext_resource type="Script" path="res://scripts/level/LevelModuleDefinition.gd" id="1"]',
                  '[ext_resource type="Script" path="res://scripts/level/LevelSocketDefinition.gd" id="2"]',
                  '[ext_resource type="Script" path="res://scripts/level/LevelBoundaryPatch.gd" id="3"]',
                  f'[ext_resource type="PackedScene" path="res://scenes/level/modules/{name}.tscn" id="4"]']
    for id,z,y,flip in [('lower',-4,0,1),('upper',12,4,-1)]:
        transform = f'Transform3D({flip},0,0,0,1,0,0,0,{flip},0,{y},{z})'
        definition += [f'[sub_resource type="Resource" id="{id}"]','script = ExtResource("2")',f'id = &"{id}"',f'local_transform = {transform}',f'approach = Vector3(0,{y},{z+flip})']
        scene += [f'[node name="{id}" type="Marker3D" parent="Sockets"]',f'transform = {transform}']
    for id,pos in [('entry',(0,0,-3)),('destination',(0,4,11)),('patrol',(0,4,11)),('interaction',(0,0,-3)),('prop',(0,0,-3)),('cover',(0,0,-3))]:
        scene += [f'[node name="{id}" type="Marker3D" parent="Markers"]',f'position = {vec(pos)}']
    for i,(id,origin,u,v,normal,socket) in enumerate(patches):
        definition += [f'[sub_resource type="Resource" id="p{i}"]','script = ExtResource("3")',f'id = &"{id}"',f'origin = {vec(origin)}',f'span_u = {vec(u)}',f'span_v = {vec(v)}',f'normal = {vec(normal)}',f'socket = &"{socket}"']
    definition += ['[resource]','script = ExtResource("1")','id = &"room14"','scene = ExtResource("4")','occupied = AABB(-4,-0.2,-4,8,7.8,16)','sockets = Array[ExtResource("2")]([SubResource("lower"),SubResource("upper")])',
                   'boundary_patches = Array[ExtResource("3")](['+', '.join(f'SubResource("p{i}")' for i in range(len(patches)))+'])','tags = PackedStringArray("corridor","vertical")']
    (ROOT/'scenes/level/modules'/f'{name}.tscn').write_text('\n'.join(scene)+'\n')
    (ROOT/'resources/level_modules'/f'{name}.tres').write_text('\n'.join(definition)+'\n')


if __name__ == '__main__':
    tall_shells()
    ramp()
