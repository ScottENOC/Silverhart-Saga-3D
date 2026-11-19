#!/usr/bin/env python3
"""Apply a review-only tint and alpha to selected garment materials in a GLB."""
import argparse
import assemble_modular_glb as glb

def rgba(hex_colour, alpha):
    value=hex_colour.lstrip("#")
    if len(value)!=6:
        raise ValueError("Colour must be #RRGGBB")
    return [int(value[i:i+2],16)/255.0 for i in (0,2,4)] + [alpha]

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument("--input",required=True)
    parser.add_argument("--output",required=True)
    parser.add_argument("--materials",nargs="+",required=True)
    parser.add_argument("--colour",required=True)
    parser.add_argument("--alpha",type=float,default=1.0)
    args=parser.parse_args()
    if not 0.0 <= args.alpha <= 1.0:
        raise ValueError("Alpha must be between 0 and 1")
    doc,binary=glb.read(args.input)
    wanted=set(args.materials)
    found=set()
    for material in doc.get("materials",[]):
        if material.get("name") in wanted:
            pbr=material.setdefault("pbrMetallicRoughness",{})
            pbr["baseColorFactor"]=rgba(args.colour,args.alpha)
            material["alphaMode"]="BLEND" if args.alpha < 1 else "OPAQUE"
            if args.alpha < 1:
                material["doubleSided"]=True
            found.add(material["name"])
    missing=sorted(wanted-found)
    if missing:
        raise RuntimeError("Requested materials missing from GLB: "+", ".join(missing))
    glb.write(args.output,doc,binary)
    print("Styled materials:",", ".join(sorted(found)),"colour",args.colour,"alpha",args.alpha)

if __name__=="__main__":
    main()
