#!/usr/bin/env python3
"""Read-only structural audit of Ara and Hollowmere character GLBs."""
import argparse, hashlib, json, math, struct
from pathlib import Path

COMP={5121:("B",1),5123:("H",2),5125:("I",4),5126:("f",4)}
TOKENS=("head","neck","spine","chest","shoulder","clavicle","upperarm","lowerarm","forearm","hand","wrist","finger","thumb","hip","pelvis","upleg","upperleg","thigh","lowerleg","calf","foot","toe","weapon","root")

def read_glb(path):
    raw=path.read_bytes()
    if len(raw)<20: raise ValueError(f"{path}: short GLB")
    magic,ver,total=struct.unpack_from("<4sII",raw)
    if magic!=b"glTF" or ver!=2 or total!=len(raw): raise ValueError(f"{path}: invalid GLB")
    pos=12; doc=None; binary=b""
    while pos+8<=total:
        size,kind=struct.unpack_from("<II",raw,pos); pos+=8
        chunk=raw[pos:pos+size]; pos+=size
        if len(chunk)!=size: raise ValueError(f"{path}: truncated chunk")
        if kind==0x4E4F534A: doc=json.loads(chunk.decode("utf-8").rstrip(" \\t\\r\\n\\0"))
        elif kind==0x004E4942: binary=chunk
    if doc is None: raise ValueError(f"{path}: missing JSON")
    return doc,binary

def accessor(doc,bin,index):
    a=doc["accessors"][index]
    if "bufferView" not in a or "sparse" in a: raise ValueError(f"unsupported accessor {index}")
    fmt,size=COMP[a["componentType"]]
    n={"SCALAR":1,"VEC2":2,"VEC3":3,"VEC4":4,"MAT2":4,"MAT3":9,"MAT4":16}[a["type"]]
    elem=size*n; view=doc["bufferViews"][a["bufferView"]]
    stride=view.get("byteStride",elem); start=view.get("byteOffset",0)+a.get("byteOffset",0)
    return [struct.unpack_from("<"+fmt*n,bin,start+i*stride) for i in range(a["count"])]

def norm(s): return "".join(c.lower() for c in s if c.isalnum())
def local_matrix(n):
    if "matrix" in n:
        m=n["matrix"]; return [[m[c*4+r] for c in range(4)] for r in range(4)]
    x,y,z,w=n.get("rotation",[0,0,0,1]); sx,sy,sz=n.get("scale",[1,1,1]); tx,ty,tz=n.get("translation",[0,0,0])
    r=[[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w)],[2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w)],[2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y)]]
    return [[r[i][j]*[sx,sy,sz][j] for j in range(3)]+[[tx,ty,tz][i]] for i in range(3)]+[[0,0,0,1]]
def mul(a,b): return [[sum(a[i][k]*b[k][j] for k in range(4)) for j in range(4)] for i in range(4)]

def audit(path):
    doc,bin=read_glb(path); nodes=doc.get("nodes",[]); parents={}
    for i,n in enumerate(nodes):
        for c in n.get("children",[]): parents[c]=i
    cache={}
    def world(i,seen=None):
        if i in cache:return cache[i]
        seen=set() if seen is None else seen
        if i in seen:raise ValueError("node hierarchy cycle")
        seen.add(i); lm=local_matrix(nodes[i])
        v=mul(world(parents[i],seen),lm) if i in parents else lm
        cache[i]=v;return v
    skins=[]
    for si,s in enumerate(doc.get("skins",[])):
        joints=[]
        for ji in s.get("joints",[]):
            n=nodes[ji]; p=parents.get(ji); wm=world(ji)
            joints.append({"name":n.get("name",f"node_{ji}"),"parent":nodes[p].get("name") if p is not None else None,
                "local_translation":n.get("translation",[0,0,0]),"rest_world_position":[round(wm[k][3],6) for k in range(3)]})
        skins.append({"name":s.get("name",f"skin_{si}"),"joint_count":len(joints),"joints":joints})
    meshes=[]
    for ni,n in enumerate(nodes):
        if "mesh" not in n:continue
        m=doc["meshes"][n["mesh"]]; prims=[]
        for pi,p in enumerate(m.get("primitives",[])):
            a=p.get("attributes",{}); vc=doc["accessors"][a["POSITION"]]["count"] if "POSITION" in a else 0
            ih=None; ic=0
            if "indices" in p:
                rows=accessor(doc,bin,p["indices"]); ic=len(rows)
                ih=hashlib.sha256(b"".join(struct.pack("<I",v[0]) for v in rows)).hexdigest()
            mi=p.get("material"); mat=doc.get("materials",[])[mi].get("name") if mi is not None else None
            prims.append({"primitive":pi,"material":mat,"vertices":vc,"indices":ic,"index_topology_sha256":ih,
                "joint_attributes":{k:doc["accessors"][v]["count"] for k,v in a.items() if k.startswith("JOINTS_")},
                "weight_attributes":{k:doc["accessors"][v]["count"] for k,v in a.items() if k.startswith("WEIGHTS_")},
                "morph_target_count":len(p.get("targets",[]))})
        meshes.append({"node":n.get("name",f"node_{ni}"),"mesh":m.get("name",f"mesh_{n['mesh']}"),
            "skinned":"skin" in n,"primitive_count":len(prims),"primitives":prims,
            "morph_target_names":m.get("extras",{}).get("targetNames",[])})
    animations=[]
    for a in doc.get("animations",[]):
        targets=[]
        for c in a.get("channels",[]):
            t=c.get("target",{}); ni=t.get("node")
            targets.append({"node":nodes[ni].get("name") if ni is not None else None,"path":t.get("path")})
        animations.append({"name":a.get("name","unnamed"),"channel_count":len(targets),"targets":targets})
    markers=[]
    for i,n in enumerate(nodes):
        name=n.get("name",""); low=name.lower()
        if any(t in low for t in ("socket","anchor","landmark","target","attachment")):
            wm=world(i); p=parents.get(i)
            markers.append({"name":name,"parent":nodes[p].get("name") if p is not None else None,
                "world_position":[round(wm[k][3],6) for k in range(3)]})
    candidates=[b for s in skins for b in s["joints"] if any(t in norm(b["name"]) for t in TOKENS)]
    return {"file":str(path),"bytes":path.stat().st_size,"node_count":len(nodes),"mesh_count":len(doc.get("meshes",[])),
        "mesh_nodes":meshes,"skins":skins,"landmark_bone_candidates":candidates,"spatial_markers":markers,
        "animations":animations,"animation_count":len(animations)}

def compare(reports):
    base=next((r for r in reports if r["skins"]),None)
    if not base:return {"baseline":None,"comparisons":[]}
    bj=base["skins"][0]["joints"]; out=[]
    for r in reports:
        if not r["skins"]:out.append({"file":r["file"],"compatible":False,"reason":"no skin"});continue
        jj=r["skins"][0]["joints"]; names=[b["name"] for b in bj]==[b["name"] for b in jj]
        parents=[b["parent"] for b in bj]==[b["parent"] for b in jj]
        delta=max((math.dist(a["rest_world_position"],b["rest_world_position"]) for a,b in zip(bj,jj)),default=0) if names else None
        out.append({"file":r["file"],"bone_count":len(jj),"same_bone_names_and_order":names,
            "same_parent_hierarchy":parents,"max_world_rest_position_delta_m":round(delta,6) if delta is not None else None,
            "within_25mm":delta<=.025 if delta is not None else False})
    return {"baseline":base["file"],"comparisons":out}

def main():
    ap=argparse.ArgumentParser();ap.add_argument("--root",default="art/characters");ap.add_argument("--output",default="character-spatial-audit");a=ap.parse_args()
    root=Path(a.root); files=sorted(list((root/"ara_runtime").glob("*.glb"))+list((root/"hollowmere").glob("*.glb")))
    if not files:raise SystemExit(f"No GLBs under {root}")
    reports=[audit(p) for p in files]; result={"schema_version":1,"asset_count":len(reports),"assets":reports,"rig_comparison":compare(reports)}
    out=Path(a.output);out.mkdir(parents=True,exist_ok=True)
    (out/"character-spatial-audit.json").write_text(json.dumps(result,indent=2)+"\\n")
    rows=result["rig_comparison"]["comparisons"]
    md=["# Character spatial foundation audit","",f"Audited {len(reports)} committed Ara runtime and Hollowmere GLBs.","",
        "## Rig compatibility","","| Asset | Bones | Names/order | Hierarchy | Max rest-position delta |","|---|---:|---|---|---:|"]
    for r in rows:md.append(f"| {Path(r['file']).name} | {r.get('bone_count','—')} | {r.get('same_bone_names_and_order','—')} | {r.get('same_parent_hierarchy','—')} | {r.get('max_world_rest_position_delta_m','—')} |")
    md += ["","## Per-asset summary","","| Asset | Mesh nodes | Skin rigs | Animations | Spatial markers |","|---|---:|---:|---:|---:|"]
    for r in reports:md.append(f"| {Path(r['file']).name} | {len(r['mesh_nodes'])} | {len(r['skins'])} | {r['animation_count']} | {len(r['spatial_markers'])} |")
    md += ["","Detailed primitive, vertex-count, topology-hash, morph-target, joint, landmark-candidate and animation-channel data is in character-spatial-audit.json.","",
        "Read-only structural audit; does not establish visual deformation quality or semantic correctness of anatomical landmarks."]
    (out/"character-spatial-audit.md").write_text("\\n".join(md)+"\\n")
    print(json.dumps({"asset_count":len(reports),"rig_comparison":result["rig_comparison"],"report":str(out/"character-spatial-audit.md")},indent=2))
if __name__=="__main__":main()
