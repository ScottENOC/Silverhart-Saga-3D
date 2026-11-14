#!/usr/bin/env python3
"""Extract fitted modular tack meshes while preserving their glTF node transforms.

The Polyfork source stores the detachable tack below attachment nodes. Their
local transforms are essential: extracting only raw vertex coordinates drops
the placement/orientation authored in the source scene.
"""
from __future__ import annotations
import json, math, pathlib, struct, sys


def read_glb(path: pathlib.Path):
    data = path.read_bytes()
    magic, version, total = struct.unpack_from("<4sII", data, 0)
    if magic != b"glTF" or version != 2 or total != len(data):
        raise ValueError("Not a valid GLB 2.0 file")
    offset, doc, binary = 12, None, None
    while offset < len(data):
        length, kind = struct.unpack_from("<I4s", data, offset)
        offset += 8
        chunk = data[offset:offset + length]
        offset += length
        if kind == b"JSON":
            doc = json.loads(chunk.rstrip(b" \\t\\r\\n\\0"))
        elif kind == b"BIN\\0":
            binary = chunk
    if doc is None or binary is None:
        raise ValueError("GLB is missing JSON or BIN chunk")
    return doc, binary


def identity():
    return [[1.0,0.0,0.0,0.0],[0.0,1.0,0.0,0.0],
            [0.0,0.0,1.0,0.0],[0.0,0.0,0.0,1.0]]


def matmul(a,b):
    return [[sum(a[r][k]*b[k][c] for k in range(4)) for c in range(4)] for r in range(4)]


def node_matrix(node):
    if "matrix" in node:
        m=node["matrix"]
        return [[m[c*4+r] for c in range(4)] for r in range(4)]
    t=node.get("translation",[0,0,0]); s=node.get("scale",[1,1,1]); q=node.get("rotation",[0,0,0,1])
    x,y,z,w=q
    rot=[[1-2*(y*y+z*z),2*(x*y-z*w),2*(x*z+y*w),0],
         [2*(x*y+z*w),1-2*(x*x+z*z),2*(y*z-x*w),0],
         [2*(x*z-y*w),2*(y*z+x*w),1-2*(x*x+y*y),0],
         [0,0,0,1]]
    trs=identity()
    for i in range(3): trs[i][i]=s[i]
    trs[0][3],trs[1][3],trs[2][3]=t
    return matmul([[rot[r][c] for c in range(4)] for r in range(4)],trs)


def world_matrix(doc, index):
    parents={}
    for i,n in enumerate(doc["nodes"]):
        for child in n.get("children",[]): parents[child]=i
    chain=[]; current=index
    while current in parents:
        current=parents[current]; chain.append(current)
    result=identity()
    for i in reversed(chain+[index]):
        result=matmul(result,node_matrix(doc["nodes"][i]))
    return result


def transform_point(m,v):
    x,y,z=v
    return (m[0][0]*x+m[0][1]*y+m[0][2]*z+m[0][3],
            m[1][0]*x+m[1][1]*y+m[1][2]*z+m[1][3],
            m[2][0]*x+m[2][1]*y+m[2][2]*z+m[2][3])


def transform_normal(m,v):
    # Rotation-only approximation; the fitted tack transforms are uniform scale.
    x,y,z=(sum(m[r][c]*v[c] for c in range(3)) for r in range(3))
    length=math.sqrt(x*x+y*y+z*z) or 1.0
    return (x/length,y/length,z/length)


def extract(doc,binary,node_name,output,scale,offset,tint):
    node_index=next((i for i,n in enumerate(doc["nodes"]) if n.get("name")==node_name),None)
    if node_index is None or not doc["nodes"][node_index].get("children"):
        raise ValueError(f"Missing mesh node {node_name}")
    mesh_index=doc["nodes"][node_index]["children"][0]
    mesh_node=doc["nodes"][mesh_index]
    primitive=doc["meshes"][mesh_node["mesh"]]["primitives"][0]
    attrs=primitive["attributes"]
    # Include the attachment node and its mesh child transforms, not just raw vertices.
    transform=matmul(world_matrix(doc,node_index),node_matrix(mesh_node))
    packed,views,accessors=bytearray(),[],[]
    vertex_count=0
    for semantic in ("POSITION","NORMAL","COLOR_0"):
        if semantic not in attrs:
            if semantic=="COLOR_0":
                continue
            raise ValueError(f"Source mesh lacks {semantic}")
        accessor=doc["accessors"][attrs[semantic]]
        view=doc["bufferViews"][accessor["bufferView"]]
        count=accessor["count"]; vertex_count=count
        start=view.get("byteOffset",0)+accessor.get("byteOffset",0)
        if accessor["componentType"]!=5126 or accessor["type"]!="VEC3":
            raise ValueError(f"Unexpected {semantic} accessor layout")
        values=list(struct.iter_unpack("<3f",binary[start:start+count*12]))
        if semantic=="POSITION":
            values=[tuple(transform_point(transform,v)[i]*scale[i]+offset[i] for i in range(3)) for v in values]
            bounds={"min":[min(v[i] for v in values) for i in range(3)],
                    "max":[max(v[i] for v in values) for i in range(3)]}
        elif semantic=="NORMAL":
            values=[transform_normal(transform,v) for v in values]
        byte_start=len(packed)
        for value in values: packed.extend(struct.pack("<3f",*value))
        view_index=len(views)
        views.append({"buffer":0,"byteOffset":byte_start,"byteLength":len(packed)-byte_start,"target":34962,"byteStride":12})
        new_accessor={"bufferView":view_index,"componentType":5126,"count":count,"type":"VEC3"}
        if semantic=="POSITION": new_accessor.update(bounds)
        accessors.append(new_accessor)
    root_name="SaddleAsset" if node_name=="attach-saddle" else "BridleAsset"
    material={"pbrMetallicRoughness":{"baseColorFactor":tint,"metallicFactor":0.0,"roughnessFactor":0.82},"doubleSided":True}
    attribute_map={"POSITION":0,"NORMAL":1}
    if len(accessors)==3: attribute_map["COLOR_0"]=2
    out_doc={"asset":{"version":"2.0","generator":"Silverhart Saga transformed tack extraction"},
        "scene":0,"scenes":[{"nodes":[0]}],
        "nodes":[{"name":root_name,"children":[1]},{"name":node_name+"-mesh","mesh":0}],
        "meshes":[{"primitives":[{"attributes":attribute_map,"material":0}]}],
        "materials":[material],"buffers":[{"byteLength":len(packed)}],
        "bufferViews":views,"accessors":accessors}
    json_chunk=json.dumps(out_doc,separators=(",",":")).encode()
    json_chunk+=b" " *((4-len(json_chunk)%4)%4)
    bin_chunk=bytes(packed); bin_chunk+=b"\\0" *((4-len(bin_chunk)%4)%4)
    total=12+8+len(json_chunk)+8+len(bin_chunk)
    output.write_bytes(struct.pack("<4sII",b"glTF",2,total)+struct.pack("<I4s",len(json_chunk),b"JSON")+json_chunk+struct.pack("<I4s",len(bin_chunk),b"BIN\\0")+bin_chunk)
    print(f"{output}: {len(output.read_bytes())} bytes; {vertex_count} vertices; {bounds}; source transform={transform}")


def main():
    source,output=pathlib.Path(sys.argv[1]),pathlib.Path(sys.argv[2]); output.mkdir(parents=True,exist_ok=True)
    doc,binary=read_glb(source)
    # Keep source-authored relative placement; apply only a modest uniform fit
    # adjustment pending the next visual review. No arbitrary vertical/forward offset.
    extract(doc,binary,"attach-saddle",output/"horse_saddle.glb",(1.0,1.0,1.0),(0.0,0.0,0.0),[0.42,0.22,0.10,1.0])
    extract(doc,binary,"attach-bridle",output/"horse_bridle.glb",(1.0,1.0,1.0),(0.0,0.0,0.0),[0.12,0.075,0.045,1.0])
    (output/"ATTRIBUTION.md").write_text(
        "# Horse tack mesh attribution\\n\\nExtracted and modified from **Saddled Horse** by Polyfork: https://polyfork.dev/asset/saddled-horse-da86d3\\n\\n"
        "Licensed under **Creative Commons Attribution 4.0 International (CC BY 4.0)**: https://creativecommons.org/licenses/by/4.0/\\n\\n"
        "Changes: extracted the named saddle and bridle meshes, preserved source attachment and mesh-node transforms, retained vertex colours and normals, and applied material tints for Silverhart.\\n",encoding="utf-8")


if __name__=="__main__": main()
