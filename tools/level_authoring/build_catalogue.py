#!/usr/bin/env python3
"""Author-time neutral kit baker. Emits reusable assets, never runs during placement."""
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2] / 'client'
CATALOGUE = [
 ('Room05XJunction',8,8,3,[(0,-4,'north'),(4,0,'east'),(0,4,'south'),(-4,0,'west')],'corridor'),
 ('Room06WideStraight',8,8,6,[(0,-4,'north'),(0,4,'south')],'corridor'),
 ('Room07WideCorner',8,8,6,[(0,-4,'north'),(4,0,'east')],'corridor'),
 ('Room08WideJunction',8,8,6,[(0,-4,'north'),(4,0,'east'),(0,4,'south'),(-4,0,'west')],'corridor'),
 ('Room09WidthAdapter',8,8,6,[(0,-4,'north'),(0,4,'south')],'adapter'),
 ('Room10LongChamber',8,16,3,[(0,-4,'north'),(0,12,'south'),(-4,0,'west_00'),(-4,8,'west_01'),(4,0,'east_00'),(4,8,'east_01')],'chamber'),
 ('Room11LargeChamber',16,16,3,[(x,z,f'{edge}_{i:02d}') for edge in ['north','south','east','west'] for i,(x,z) in enumerate([(0,-4),(8,-4)] if edge=='north' else [(0,12),(8,12)] if edge=='south' else [(12,0),(12,8)] if edge=='east' else [(-4,0),(-4,8)])],'chamber'),
 ('Room13SpecialHall',16,24,3,[(0,-4,'north_00'),(8,-4,'north_01'),(0,20,'south_00'),(8,20,'south_01'),(-4,0,'west_00'),(-4,8,'west_01'),(-4,16,'west_02'),(12,0,'east_00'),(12,8,'east_01'),(12,16,'east_02')],'chamber'),
]
def vec(v): return 'Vector3('+', '.join(str(round(x,5)) for x in v)+')'
def bake(spec):
 name,W,D,width,sockets,kind=spec; h=3.4; xmax=W-4; zmax=D-4
 rects=[]; defs=[]
 if kind=='chamber':rects=[(-3.8,-3.8,xmax-.2,zmax-.2)]
 else:
  r=width/2;rects=[(-r,-r,r,r)]
 for x,z,id in sockets:
  w=3 if kind=='adapter' and id=='north' else (6 if name=='Room13SpecialHall' and id=='east_01' else width)
  side=id.split('_')[0];r=w/2
  if side=='north': rects.append((x-r,-4,x+r,-3.8 if kind=='chamber' else 0));basis=(1,0,0,0,1,0,0,0,1);normal=(0,-1)
  elif side=='south':rects.append((x-r,zmax-.2 if kind=='chamber' else 0,x+r,zmax));basis=(-1,0,0,0,1,0,0,0,-1);normal=(0,1)
  elif side=='east':rects.append((xmax-.2 if kind=='chamber' else 0,z-r,xmax,z+r));basis=(0,0,-1,0,1,0,1,0,0);normal=(1,0)
  else:rects.append((-4,z-r,-3.8 if kind=='chamber' else 0,z+r));basis=(0,0,1,0,1,0,-1,0,0);normal=(-1,0)
  defs.append((id,x,z,w,basis,normal))
 # Union partition; floors never overlap. Merge equal horizontal runs vertically.
 xs=sorted({r[k] for r in rects for k in (0,2)});zs=sorted({r[k] for r in rects for k in (1,3)})
 cells={(i,j) for i in range(len(xs)-1) for j in range(len(zs)-1) if any(a< (xs[i]+xs[i+1])/2<c and b<(zs[j]+zs[j+1])/2<d for a,b,c,d in rects)}
 rectangles=[]; todo=set(cells)
 while todo:
  i,j=min(todo);end=i+1
  while (end,j) in todo:end+=1
  top=j+1
  while all((k,top) in todo for k in range(i,end)):top+=1
  rectangles.append((xs[i],zs[j],xs[end],zs[top]))
  todo.difference_update((k,l) for k in range(i,end) for l in range(j,top))
 edges={}
 for i,j in cells:
  for di,dj in [(1,0),(-1,0),(0,1),(0,-1)]:
   if (i+di,j+dj) in cells:continue
   axis=0 if di else 1; coord=xs[i+1] if di>0 else xs[i] if di else zs[j+1] if dj>0 else zs[j]
   lo,hi=(zs[j],zs[j+1]) if di else (xs[i],xs[i+1]);edges.setdefault((axis,coord,di or dj),[]).append((lo,hi))
 boxes=[]
 for a,b,c,d in rectangles:
  boxes += [('Floor',((a+c)/2,-.1,(b+d)/2),(c-a,.2,d-b),1,None),('Roof',((a+c)/2,h+.1,(b+d)/2),(c-a,.2,d-b),128,None)]
 for (axis,coord,sign),intervals in sorted(edges.items()):
  merged=[]
  for lo,hi in sorted(intervals):
   if merged and abs(merged[-1][1]-lo)<.0001:merged[-1]=(merged[-1][0],hi)
   else:merged.append((lo,hi))
  for lo,hi in merged:
   portal=next((s for s in defs if abs((s[1] if axis==0 else s[2])-coord)<.001 and abs((s[2] if axis==0 else s[1])-(lo+hi)/2)<.001 and abs(s[3]-(hi-lo))<.001),None)
   p=[coord+sign*.1, h/2,(lo+hi)/2] if axis==0 else [(lo+hi)/2,h/2,coord+sign*.1]
   size=[.2,h,hi-lo] if axis==0 else [hi-lo,h,.2]
   if portal:
    p[axis]=coord-sign*.1;p[1]=1.4;size[1]=2.8;boxes.append(('Cap',tuple(p),tuple(size),1,portal[0]))
    p[1]=3.1;size[1]=.6;boxes.append(('Header',tuple(p),tuple(size),1,None))
   else:boxes.append(('Wall',tuple(p),tuple(size),1,None))
 lines=['[gd_scene format=3]','[ext_resource type="Script" path="res://scripts/level/LevelModule.gd" id="1"]','[sub_resource type="StandardMaterial3D" id="mat"]','albedo_color = Color(0.32,0.38,0.41,1)']
 for i,(_,p,size,layer,cap) in enumerate(boxes):lines += [f'[sub_resource type="BoxShape3D" id="s{i}"]',f'size = {vec(size)}',f'[sub_resource type="BoxMesh" id="m{i}"]',f'size = {vec(size)}']
 lines += [f'[node name="{name}" type="Node3D"]','script = ExtResource("1")',f'definition_path = "res://resources/level_modules/{name}.tres"']
 for branch in ['Structure','Structure/Collision','Structure/NavigationSource','Structure/PortalClosures','Visuals','Visuals/Closures','Sockets','Markers','Attachments','Attachments/Props','Attachments/Cover','Attachments/Interactions','Attachments/Spawns']:
  parts=branch.split('/');lines.append(f'[node name="{parts[-1]}" type="Node3D" parent="{"/".join(parts[:-1]) or "."}"]')
 for i,(part_kind,p,size,layer,cap) in enumerate(boxes):
  id=cap or f'{part_kind}{i}';parent='Structure/PortalClosures' if cap else 'Structure/Collision';visual='Visuals/Closures' if cap else 'Visuals'
  lines += [f'[node name="{id}" type="StaticBody3D" parent="{parent}"]',f'position = {vec(p)}',f'collision_layer = {layer}',f'[node name="Shape" type="CollisionShape3D" parent="{parent}/{id}"]',f'shape = SubResource("s{i}")',f'[node name="{id}" type="MeshInstance3D" parent="{visual}"]',f'position = {vec(p)}',f'mesh = SubResource("m{i}")','material_override = SubResource("mat")',f'metadata/visual_slot = "{id}"',f'metadata/dimensions = {vec(size)}']
 resource=['[gd_resource type="Resource" script_class="LevelModuleDefinition" format=3]','[ext_resource type="Script" path="res://scripts/level/LevelModuleDefinition.gd" id="1"]','[ext_resource type="Script" path="res://scripts/level/LevelSocketDefinition.gd" id="2"]',f'[ext_resource type="PackedScene" path="res://scenes/level/modules/{name}.tscn" id="3"]']
 for id,x,z,w,basis,normal in defs:
  transform='Transform3D('+', '.join(map(str,(*basis,x,0,z)))+')'
  lines += [f'[node name="{id}" type="Marker3D" parent="Sockets"]',f'transform = {transform}']
  resource += [f'[sub_resource type="Resource" id="{id}"]','script = ExtResource("2")',f'id = &"{id}"',f'local_transform = {transform}',f'approach = {vec((x-normal[0],0,z-normal[1]))}',f'width = {w}.0',f'family = &"{"passage" if w==3 else "wide_passage"}"']
 for id in ['entry','destination','patrol','prop','interaction','cover']:lines += [f'[node name="{id}" type="Marker3D" parent="Markers"]']
 resource += ['[resource]','script = ExtResource("1")',f'id = &"room{name[4:6]}"',f'scene = ExtResource("3")',f'occupied = AABB(-4,-0.2,-4,{W},3.8,{D})','interiors = Array[AABB](['+', '.join(f'AABB({a},0,{b},{c-a},3.4,{d-b})' for a,b,c,d in rectangles)+'])','sockets = Array[ExtResource("2")](['+', '.join(f'SubResource("{s[0]}")' for s in defs)+'])',f'tags = PackedStringArray("{kind}")']
 (ROOT/'scenes/level/modules'/f'{name}.tscn').write_text('\n'.join(lines)+'\n');(ROOT/'resources/level_modules'/f'{name}.tres').write_text('\n'.join(resource)+'\n')
if __name__=='__main__':
 for spec in CATALOGUE:bake(spec)
