#!/usr/bin/env python3
"""Pack selectable Ara garment primitives onto the integrated full-skin rig."""
import copy, json, struct, sys
from pathlib import Path

COMP={5120:('b',1),5121:('B',1),5122:('h',2),5123:('H',2),5125:('I',4),5126:('f',4)}
COUNT={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4,'MAT2':4,'MAT3':9,'MAT4':16}

def read(path):
    raw=Path(path).read_bytes(); magic,ver,total=struct.unpack_from('<4sII',raw)
    if magic!=b'glTF' or ver!=2 or total!=len(raw): raise ValueError(f'Invalid GLB: {path}')
    pos=12; doc=None; binary=b''
    while pos<total:
        size,kind=struct.unpack_from('<I4s',raw,pos); pos+=8; chunk=raw[pos:pos+size]; pos+=size
        if kind==b'JSON': doc=json.loads(chunk.decode().rstrip(' \t\r\n\0'))
        elif kind==b'BIN\0': binary=chunk
    return doc,binary

def write(path,doc,binary):
    doc['buffers'][0]['byteLength']=len(binary)
    j=json.dumps(doc,separators=(',',':'),ensure_ascii=False).encode(); j+=b' '*((-len(j))%4); binary+=b'\0'*(-len(binary)%4)
    total=12+8+len(j)+8+len(binary)
    Path(path).write_bytes(struct.pack('<4sII',b'glTF',2,total)+struct.pack('<I4s',len(j),b'JSON')+j+struct.pack('<I4s',len(binary),b'BIN\0')+binary)

def body_node(d):
    hits=[]
    for n in d['nodes']:
        if 'mesh' not in n or 'skin' not in n: continue
        names=[d['materials'][p.get('material',0)].get('name') for p in d['meshes'][n['mesh']]['primitives']]
        if 'Skin' in names: hits.append(n)
    if len(hits)!=1: raise ValueError(f'Expected one skinned body mesh, got {len(hits)}')
    return hits[0]

def append_bytes(target,buf,data,target_type=None):
    buf+=b'\0'*(-len(buf)%4); off=len(buf)
    view={'buffer':0,'byteOffset':off,'byteLength':len(data)}
    if target_type is not None: view['target']=target_type
    vi=len(target.setdefault('bufferViews',[])); target['bufferViews'].append(view)
    return target,buf+data,vi

def compact_accessor(src,sbuf,target,buf,old_ai,vertices,joint_map=None):
    a=copy.deepcopy(src['accessors'][old_ai]); view=src['bufferViews'][a['bufferView']]
    fmt,size=COMP[a['componentType']]; n=COUNT[a['type']]; elem=size*n
    stride=view.get('byteStride',elem); start=view.get('byteOffset',0)+a.get('byteOffset',0)
    pack='<'+fmt*n; data=bytearray(); rows=[]
    for vi in vertices:
        raw=sbuf[start+vi*stride:start+vi*stride+elem]
        vals=list(struct.unpack(pack,raw))
        if joint_map is not None:
            if any(x>=len(joint_map) for x in vals): raise ValueError(f'Invalid source joint index {max(vals)}')
            vals=[joint_map[x] for x in vals]
        rows.append(vals); data.extend(struct.pack(pack,*vals))
    target,buf,vi=append_bytes(target,buf,bytes(data),34962)
    a.pop('sparse',None); a['bufferView']=vi; a.pop('byteOffset',None); a['count']=len(vertices)
    a['min']=[min(row[c] for row in rows) for c in range(n)]
    a['max']=[max(row[c] for row in rows) for c in range(n)]
    ai=len(target.setdefault('accessors',[])); target['accessors'].append(a)
    return target,buf,ai

def add(target,buf,source_path,selector):
    src,sbuf=read(source_path)
    tj=[target['nodes'][i].get('name') for i in target['skins'][0]['joints']]
    sj=[src['nodes'][i].get('name') for i in src['skins'][0]['joints']]
    if set(tj)!=set(sj): raise ValueError(f'Skeleton bones differ in {source_path}')
    joint_map=[tj.index(name) for name in sj]
    tn=body_node(target); sn=body_node(src)
    target_mesh=target['meshes'][tn['mesh']]
    source_mesh=src['meshes'][sn['mesh']]
    for k in ('translation','rotation','scale','matrix'):
        if tn.get(k)!=sn.get(k): raise ValueError(f'Rigged mesh {k} mismatch in {source_path}')

    # Garment primitives must carry the same morph-target contract as the body.
    # Ara exports facial blend shapes on every skinned primitive. Leaving the
    # source target accessor indices untouched makes them point at unrelated
    # accessors in the destination GLB (often scalar indices), which Blender
    # then rejects while importing the assembled character.
    target_names=target_mesh.get('extras',{}).get('targetNames')
    source_names=source_mesh.get('extras',{}).get('targetNames')
    target_count=len(target_mesh.get('weights', target_names or []))
    source_count=len(source_mesh.get('weights', source_names or []))
    if source_count != target_count:
        raise ValueError(f'Morph target count differs in {source_path}: source={source_count}, target={target_count}')
    if target_names is not None and source_names is not None and source_names != target_names:
        raise ValueError(f'Morph target names differ in {source_path}')
    target_name=None
    if '=' in selector: selector,target_name=selector.split('=',1)
    if selector.endswith('*'):
        name=selector[:-1]
        matches=[p for p in src['meshes'][sn['mesh']]['primitives'] if p.get('material') is not None and src['materials'][p['material']].get('name')==name]
        if not matches: raise ValueError(f'{selector}: no matching primitives in {source_path}')
        for occurrence in range(len(matches)):
            sub=f'{name}#{occurrence+1}'+(f'={target_name}' if target_name else '')
            target,buf=add(target,buf,source_path,sub)
        return target,buf
    name=selector; occurrence=0
    if '#' in selector: name,nth=selector.rsplit('#',1); occurrence=int(nth)-1
    matches=[p for p in src['meshes'][sn['mesh']]['primitives'] if p.get('material') is not None and src['materials'][p['material']].get('name')==name]
    if occurrence<0 or occurrence>=len(matches): raise ValueError(f'{selector}: found {len(matches)} in {source_path}; materials={[m.get("name") for m in src["materials"]]}')
    p=copy.deepcopy(matches[occurrence]); sm=copy.deepcopy(src['materials'][p['material']])
    sm['name']=target_name or (f'{name}.{occurrence:03d}' if occurrence else name)
    ia=src['accessors'][p['indices']]; iv=src['bufferViews'][ia['bufferView']]
    if ia['componentType'] not in (5123,5125): raise ValueError('Unsupported index type')
    ifmt,size=COMP[ia['componentType']]; ioff=iv.get('byteOffset',0)+ia.get('byteOffset',0); istride=iv.get('byteStride',size)
    original=[struct.unpack_from('<'+ifmt,sbuf,ioff+i*istride)[0] for i in range(ia['count'])]
    vertices=sorted(set(original)); remap={old:new for new,old in enumerate(vertices)}
    amap={}
    for attr,old_ai in p.get('attributes',{}).items():
        target,buf,new_ai=compact_accessor(src,sbuf,target,buf,old_ai,vertices,joint_map if attr.startswith('JOINTS_') else None)
        amap[old_ai]=new_ai
    new_indices=[remap[x] for x in original]; index_data=struct.pack('<'+ifmt*len(new_indices),*new_indices)
    target,buf,ivi=append_bytes(target,buf,index_data,34963)
    ia2=copy.deepcopy(ia); ia2['bufferView']=ivi; ia2.pop('byteOffset',None); ia2['min']=[min(new_indices)]; ia2['max']=[max(new_indices)]
    new_ia=len(target.setdefault('accessors',[])); target['accessors'].append(ia2)
    p['attributes']={k:amap[v] for k,v in p.get('attributes',{}).items()}; p['indices']=new_ia

    # Copy and compact every morph-target attribute using the same vertex subset
    # as the garment primitive. Accessor indices are document-local: they must
    # never be copied verbatim from the source GLB into the destination GLB.
    source_targets=p.get('targets', [])
    if len(source_targets) != target_count:
        raise ValueError(f'{selector}: expected {target_count} morph targets, found {len(source_targets)}')
    remapped_targets=[]
    for target_attrs in source_targets:
        remapped={}
        for attr,old_ai in target_attrs.items():
            target,buf,new_ai=compact_accessor(src,sbuf,target,buf,old_ai,vertices)
            remapped[attr]=new_ai
        remapped_targets.append(remapped)
    if source_targets:
        p['targets']=remapped_targets

    # Reuse a previously appended material for other primitives that form the
    # same garment (e.g. bikini cups plus several cord sections).
    existing=next((i for i,x in enumerate(target.get('materials',[])) if x.get('name')==sm['name']),None)
    if existing is not None:
        p['material']=existing
        target['meshes'][tn['mesh']]['primitives'].append(p)
        print('Added',selector,'(',len(vertices),'vertices ) using shared material',sm['name'])
        return target,buf

    tex=set()
    def scan(x):
        if isinstance(x,dict):
            if isinstance(x.get('index'),int): tex.add(x['index'])
            for v in x.values(): scan(v)
        elif isinstance(x,list):
            for v in x: scan(v)
    scan(sm)
    imgs={src['textures'][i]['source'] for i in tex if 'source' in src['textures'][i]}
    samps={src['textures'][i]['sampler'] for i in tex if 'sampler' in src['textures'][i]}
    imap={}
    for i in sorted(imgs):
        x=copy.deepcopy(src['images'][i])
        if 'bufferView' in x:
            v=src['bufferViews'][x['bufferView']]; off=v.get('byteOffset',0); data=sbuf[off:off+v['byteLength']]
            target,buf,new_view=append_bytes(target,buf,data); x['bufferView']=new_view
        elif 'uri' in x and not x['uri'].startswith('data:'): raise ValueError('External image URI cannot be packed into GLB')
        imap[i]=len(target.setdefault('images',[])); target['images'].append(x)
    smap={}
    for i in sorted(samps): smap[i]=len(target.setdefault('samplers',[])); target['samplers'].append(copy.deepcopy(src['samplers'][i]))
    tmap={}
    for i in sorted(tex):
        x=copy.deepcopy(src['textures'][i])
        if 'source' in x: x['source']=imap[x['source']]
        if 'sampler' in x: x['sampler']=smap[x['sampler']]
        tmap[i]=len(target.setdefault('textures',[])); target['textures'].append(x)
    def remap_tex(x):
        if isinstance(x,dict):
            if isinstance(x.get('index'),int): x['index']=tmap[x['index']]
            for v in x.values(): remap_tex(v)
        elif isinstance(x,list):
            for v in x: remap_tex(v)
    remap_tex(sm); p['material']=len(target.setdefault('materials',[])); target['materials'].append(sm)
    target['meshes'][tn['mesh']]['primitives'].append(p)
    for k in ('extensionsUsed','extensionsRequired'): target[k]=sorted(set(target.get(k,[]))|set(src.get(k,[])))
    print('Added',selector,'(',len(vertices),'vertices ) from',Path(source_path).name)
    return target,buf

def validate_morph_targets(doc):
    """Reject stale or structurally incompatible morph-target accessors."""
    for mesh in doc.get('meshes', []):
        expected=len(mesh.get('weights', mesh.get('extras', {}).get('targetNames', [])))
        for primitive_index,primitive in enumerate(mesh.get('primitives', [])):
            targets=primitive.get('targets', [])
            if len(targets) != expected:
                raise ValueError(f"{mesh.get('name', '<unnamed>')} primitive {primitive_index}: expected {expected} morph targets, found {len(targets)}")
            position=primitive.get('attributes', {}).get('POSITION')
            vertex_count=doc['accessors'][position]['count'] if position is not None else None
            for target_index,target in enumerate(targets):
                for semantic,accessor_index in target.items():
                    accessor=doc['accessors'][accessor_index]
                    if accessor['count'] != vertex_count:
                        raise ValueError(f"Morph target {target_index} {semantic} has {accessor['count']} vertices; expected {vertex_count}")
                    if semantic in ('POSITION','NORMAL','TANGENT') and accessor['type'] != 'VEC3':
                        raise ValueError(f"Morph target {target_index} {semantic} must be VEC3, got {accessor['type']}")


if __name__=='__main__':
    if len(sys.argv)<3 or (len(sys.argv)-3)%2: raise SystemExit('usage: script BODY.glb OUT.glb SOURCE.glb MATERIAL [SOURCE MATERIAL]...')
    d,b=read(sys.argv[1]); b=b[:d['buffers'][0]['byteLength']]
    for i in range(3,len(sys.argv),2): d,b=add(d,b,sys.argv[i],sys.argv[i+1])
    validate_morph_targets(d)
    write(sys.argv[2],d,b)
    check,_=read(sys.argv[2]); validate_morph_targets(check); n=body_node(check)
    print(f"Wrote {sys.argv[2]} ({Path(sys.argv[2]).stat().st_size:,} bytes), {len(check['meshes'][n['mesh']]['primitives'])} skinned primitives')
