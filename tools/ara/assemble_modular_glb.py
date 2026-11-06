#!/usr/bin/env python3
"""Combine Ara garment primitives into the body-only GLB while sharing its rig."""
import copy, json, struct, sys
from pathlib import Path

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

def add(target,buf,source_path,mat_name):
    src,sbuf=read(source_path)
    tj=[target['nodes'][i].get('name') for i in target['skins'][0]['joints']]
    sj=[src['nodes'][i].get('name') for i in src['skins'][0]['joints']]
    if tj!=sj: raise ValueError(f'Skeleton mismatch in {source_path}')
    tn=body_node(target); sn=body_node(src)
    for k in ('translation','rotation','scale','matrix'):
        if tn.get(k)!=sn.get(k): raise ValueError(f'Rigged mesh {k} mismatch in {source_path}')
    matches=[p for p in src['meshes'][sn['mesh']]['primitives'] if p.get('material') is not None and src['materials'][p['material']].get('name')==mat_name]
    if len(matches)!=1: raise ValueError(f'{mat_name}: found {len(matches)} in {source_path}; materials={[m.get("name") for m in src["materials"]]}')
    p=copy.deepcopy(matches[0]); sm=copy.deepcopy(src['materials'][p['material']])
    used=set(p.get('attributes',{}).values())
    if 'indices' in p: used.add(p['indices'])
    for t in p.get('targets',[]): used.update(t.values())
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
    views={src['accessors'][i]['bufferView'] for i in used if 'bufferView' in src['accessors'][i]}
    for i in used:
        sp=src['accessors'][i].get('sparse')
        if sp: views|={sp['indices']['bufferView'],sp['values']['bufferView']}
    views|={src['images'][i]['bufferView'] for i in imgs if 'bufferView' in src['images'][i]}
    buf=buf[:target['buffers'][0]['byteLength']]; buf+=b'\0'*(-len(buf)%4); base=len(buf)
    payload=bytearray(); vm={}
    for i in sorted(views,key=lambda x:src['bufferViews'][x].get('byteOffset',0)):
        v=src['bufferViews'][i]; off=v.get('byteOffset',0); payload+=b'\0'*(-len(payload)%4); vm[i]=len(target.setdefault('bufferViews',[]))
        nv=copy.deepcopy(v); nv['buffer']=0; nv['byteOffset']=base+len(payload); target['bufferViews'].append(nv); payload+=sbuf[off:off+v['byteLength']]
    buf+=payload
    am={}
    for i in sorted(used):
        a=copy.deepcopy(src['accessors'][i])
        if 'bufferView' in a: a['bufferView']=vm[a['bufferView']]
        if 'sparse' in a:
            a['sparse']['indices']['bufferView']=vm[a['sparse']['indices']['bufferView']]; a['sparse']['values']['bufferView']=vm[a['sparse']['values']['bufferView']]
        am[i]=len(target.setdefault('accessors',[])); target['accessors'].append(a)
    im={}
    for i in sorted(imgs):
        x=copy.deepcopy(src['images'][i])
        if 'bufferView' in x: x['bufferView']=vm[x['bufferView']]
        im[i]=len(target.setdefault('images',[])); target['images'].append(x)
    smap={}
    for i in sorted(samps): smap[i]=len(target.setdefault('samplers',[])); target['samplers'].append(copy.deepcopy(src['samplers'][i]))
    tm={}
    for i in sorted(tex):
        x=copy.deepcopy(src['textures'][i])
        if 'source' in x: x['source']=im[x['source']]
        if 'sampler' in x: x['sampler']=smap[x['sampler']]
        tm[i]=len(target.setdefault('textures',[])); target['textures'].append(x)
    def remap(x):
        if isinstance(x,dict):
            if isinstance(x.get('index'),int): x['index']=tm[x['index']]
            for v in x.values(): remap(v)
        elif isinstance(x,list):
            for v in x: remap(v)
    remap(sm); mi=len(target.setdefault('materials',[])); target['materials'].append(sm)
    p['attributes']={k:am[v] for k,v in p.get('attributes',{}).items()}
    if 'indices' in p: p['indices']=am[p['indices']]
    for t in p.get('targets',[]):
        for k,v in list(t.items()): t[k]=am[v]
    p['material']=mi; target['meshes'][tn['mesh']]['primitives'].append(p)
    for k in ('extensionsUsed','extensionsRequired'): target[k]=sorted(set(target.get(k,[]))|set(src.get(k,[])))
    print('Added',mat_name,'from',Path(source_path).name)
    return target,buf

if __name__=='__main__':
    if len(sys.argv)<3 or (len(sys.argv)-3)%2: raise SystemExit('usage: script BODY.glb OUT.glb SOURCE.glb MATERIAL [SOURCE MATERIAL]...')
    d,b=read(sys.argv[1])
    for i in range(3,len(sys.argv),2): d,b=add(d,b,sys.argv[i],sys.argv[i+1])
    write(sys.argv[2],d,b); check,_=read(sys.argv[2]); n=body_node(check)
    print(f'Wrote {sys.argv[2]} ({Path(sys.argv[2]).stat().st_size:,} bytes), {len(check["meshes"][n["mesh"]]["primitives"])} skinned primitives')
