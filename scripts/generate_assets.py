"""Reproducible CC0 texture adaptation and original mesh/UI/sound generation."""
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import math
from pathlib import Path
import random
import shutil
import struct
import subprocess
import urllib.request
import wave

from PIL import Image, ImageDraw, ImageEnhance, ImageOps
from bootstrap import ROOT, CACHE, download

MOD = ROOT / "mods" / "frontline"
TEXTURES = MOD / "textures"
MODELS = MOD / "models"
SOUNDS = MOD / "sounds"
SOURCES = ROOT / "assets" / "sources.json"
ASSETS = ["concrete_floor_02", "brown_planks_03", "brown_mud_02", "rock_06", "aerial_grass_rock"]


def source_texture(asset):
    metadata = CACHE / f"polyhaven-{asset}.json"
    download(f"https://api.polyhaven.com/files/{asset}", metadata)
    files = json.loads(metadata.read_text())
    color = next(files[key] for key in ("Diffuse", "diff", "diffuse") if key in files)
    info = color["1k"]["jpg"]
    target = CACHE / f"{asset}.jpg"
    download(info["url"], target)
    if hashlib.md5(target.read_bytes()).hexdigest() != info["md5"]:
        raise RuntimeError(f"Texture integrity failure: {asset}")
    return asset, target, {"asset":asset, "page":f"https://polyhaven.com/a/{asset}",
        "url":info["url"], "license":"CC0-1.0", "sha256":hashlib.sha256(target.read_bytes()).hexdigest()}


def save(image, name):
    image.save(TEXTURES / f"frontline_{name}.png")


def surface_assets(sources):
    images = {name:Image.open(path).convert("RGB").resize((256,256),Image.Resampling.LANCZOS)
              for name, path, _ in sources}
    concrete = images["concrete_floor_02"]
    save(concrete,"concrete")
    asphalt = ImageEnhance.Brightness(ImageEnhance.Color(concrete).enhance(0.35)).enhance(0.32)
    save(asphalt,"asphalt")
    save(images["brown_planks_03"],"timber")
    metal = ImageOps.colorize(ImageOps.grayscale(concrete),"#242a30","#b2bac3")
    draw=ImageDraw.Draw(metal)
    for line in range(0,256,32):
        draw.line((line,0,line,255), fill="#343b42",width=3)
        draw.line((line+4,0,line+4,255), fill="#899098",width=2)
    save(metal,"steel")
    for name,dark,light in [("blue","#103849","#4d8d9b"),("orange","#733223","#d18a52")]:
        container=ImageOps.colorize(ImageOps.grayscale(metal),dark,light)
        d=ImageDraw.Draw(container)
        for y in (6,249): d.line((0,y,255,y),fill="#343a3f",width=6)
        save(container,"container_"+name)
        pad=asphalt.copy(); d=ImageDraw.Draw(pad)
        d.rectangle((12,12,243,243),outline=light,width=16)
        d.line((78,128,178,128),fill=light,width=12)
        d.line((128,78,128,178),fill=light,width=12)
        save(pad,name+"_pad")
    stripe=asphalt.copy(); d=ImageDraw.Draw(stripe)
    d.rectangle((98,0,158,255),fill="#bb9850")
    stripe=Image.blend(stripe,concrete,0.12)
    save(stripe,"stripe")
    light=Image.new("RGB",(256,256),"#303a42"); d=ImageDraw.Draw(light)
    d.rectangle((16,34,239,222),fill="#fff1cc")
    for x in range(24,240,30): d.line((x,34,x,222),fill="#c1bda9",width=3)
    save(light,"light")
    # Replace commonly visible VoxeLibre world textures by exact pinned names.
    game = ROOT / "runtime/luanti/games/voxelibre"
    pack = ROOT / "assets" / "frontline_realism"
    pack.mkdir(parents=True,exist_ok=True)
    (pack/"texture_pack.conf").write_text("title = Frontline Realism 256\ndescription = CC0 photographic surfaces for VoxeLibre 0.92.3\n",encoding="utf-8")
    mappings={"default_stone.png":images["rock_06"],"default_dirt.png":images["brown_mud_02"],
        "mcl_core_grass_block_top.png":ImageOps.grayscale(images["aerial_grass_rock"]),
        "default_wood.png":images["brown_planks_03"]}
    for filename,image in mappings.items():
        if not next(game.rglob(filename),None):
            raise RuntimeError(f"VoxeLibre texture was renamed: {filename}")
        image.save(pack/filename)
    (pack/"LICENSE.txt").write_text("Photographic source surfaces: Poly Haven, CC0-1.0.\nSee ../../assets/sources.json and THIRD_PARTY.md in the project root.\n",encoding="utf-8")


def ui_assets():
    for name,color in [("crosshair","#f2efdf"),("hit","#f0b74a")]:
        image=Image.new("RGBA",(32,32)); d=ImageDraw.Draw(image)
        if name=="crosshair":
            for line in [(16,2,16,10),(16,22,16,30),(2,16,10,16),(22,16,30,16)]:
                d.line(line,fill="#152028",width=3); d.line(line,fill=color,width=1)
            d.rectangle((15,15,16,16),fill=color)
        else:
            for line in [(5,5,11,11),(21,21,27,27),(5,27,11,21),(21,11,27,5)]: d.line(line,fill=color,width=2)
        save(image,name)
    save(Image.new("RGBA",(1,1)),"blank")
    save(Image.new("RGBA",(4,4),"#ffe8a6"),"tracer")
    target=Image.new("RGB",(256,256),"#b4b4a9"); d=ImageDraw.Draw(target)
    for radius,color in [(110,"#303b40"),(85,"#b4b4a9"),(60,"#303b40"),(35,"#c28244"),(10,"#e3bc6d")]:
        d.ellipse((128-radius,128-radius,128+radius,128+radius),fill=color)
    save(target,"target")
    ammo=Image.new("RGBA",(128,128)); d=ImageDraw.Draw(ammo)
    for x in (30,56,82):
        d.rounded_rectangle((x,30,x+18,112),radius=3,fill="#b99a5e",outline="#dfcd99",width=2)
        d.polygon([(x,30),(x+9,8),(x+18,30)],fill="#a9704b")
    save(ammo,"ammo")


def gun_assets():
    # Each box: bounds, palette color. Units are nodes; all geometry is original.
    rifle=[((-0.09,-0.02,-0.3,0.09,0.13,0.22),0),
        ((-0.075,0.02,-0.55,0.075,0.15,-0.25),2),
        ((-0.035,0.065,-0.88,0.035,0.105,-0.5),1),
        ((-0.05,0.045,-0.94,0.05,0.125,-0.85),0),
        ((-0.05,0.025,0.2,0.05,0.1,0.42),1),
        ((-0.085,-0.04,0.38,0.085,0.14,0.62),2),
        ((-0.055,-0.28,0.05,0.055,0,0.18),0),
        ((-0.06,-0.27,-0.2,0.06,-0.02,-0.06),2),
        ((-0.055,0.13,-0.28,0.055,0.17,0.18),1),
        ((-0.045,0.17,0.02,0.045,0.24,0.1),0),
        ((-0.02,0.15,-0.51,0.02,0.22,-0.46),1)]
    pistol=[((-0.07,0.02,-0.38,0.07,0.14,0.13),1),
        ((-0.06,-0.04,-0.3,0.06,0.025,0.13),0),
        ((-0.055,-0.3,0.01,0.055,0.02,0.14),2),
        ((-0.03,0.065,-0.41,0.03,0.105,-0.36),0),
        ((-0.02,0.14,-0.32,0.02,0.18,-0.27),0),
        ((-0.04,0.14,0.07,0.04,0.18,0.11),0)]
    colors=[(37,43,46),(69,77,81),(126,114,85),(187,157,95)]
    atlas=Image.new("RGB",(256,64)); rng=random.Random(37)
    for x in range(256):
        for y in range(64):
            noise=rng.randint(-7,7); color=colors[x//64]
            atlas.putpixel((x,y),tuple(max(0,min(255,c+noise)) for c in color))
    save(atlas,"gun")
    for name,boxes in [("rifle",rifle),("pistol",pistol)]:
        lines=["# Original Frontline mesh; generated by scripts/generate_assets.py"]
        vertices=[]; faces=[]
        for bounds,material in boxes:
            x0,y0,z0,x1,y1,z1=bounds
            verts=[(x0,y0,z0),(x1,y0,z0),(x1,y1,z0),(x0,y1,z0),(x0,y0,z1),(x1,y0,z1),(x1,y1,z1),(x0,y1,z1)]
            base=len(vertices); vertices.extend(verts)
            for face in [(0,3,2,1),(4,5,6,7),(0,4,7,3),(1,2,6,5),(0,1,5,4),(3,7,6,2)]:
                faces.append(([base+i+1 for i in face],material))
        # Undo the engine's hard-coded (-100,120,-100) wield rotation, then
        # orient the barrel into the scene. This keeps a normal unpatched client.
        def cross(a,b): return (a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0])
        def normalize(v):
            length=math.sqrt(sum(c*c for c in v)); return tuple(c/length for c in v)
        axis_z=normalize((0.48,-0.30,-0.82))
        axis_x=normalize(cross((0,1,0),axis_z))
        axis_y=cross(axis_z,axis_x)
        ax,ay,az=map(math.radians,(-100,120,-100))
        cx,sx,cy,sy,cz,sz=math.cos(ax),math.sin(ax),math.cos(ay),math.sin(ay),math.cos(az),math.sin(az)
        rotation=((cy*cz,sx*sy*cz-cx*sz,cx*sy*cz+sx*sz),
            (cy*sz,sx*sy*sz+cx*cz,cx*sy*sz-sx*cz),(-sy,sx*cy,cx*cy))
        for vertex in vertices:
            desired=tuple(axis_x[i]*vertex[0]+axis_y[i]*vertex[1]+axis_z[i]*vertex[2] for i in range(3))
            transformed=tuple(sum(rotation[j][i]*desired[j] for j in range(3)) for i in range(3))
            # Luanti 5.17's OBJ loader changes handedness by reversing X.
            lines.append("v %.5f %.5f %.5f"%(-transformed[0],transformed[1],transformed[2]))
        for material in range(4):
            u0=(material*64+2)/256;u1=(material*64+62)/256
            for u,v in [(u0,0.03),(u1,0.03),(u1,0.97),(u0,0.97)]: lines.append(f"vt {u:.5f} {v:.5f}")
        for face,material in faces:
            lines.append("f "+" ".join(f"{vertex}/{material*4+i+1}" for i,vertex in enumerate(face)))
        (MODELS/f"frontline_{name}.obj").write_text("\n".join(lines)+"\n",encoding="ascii")
        # Original inventory thumbnail from the same geometry.
        image=Image.new("RGBA",(256,128)); d=ImageDraw.Draw(image)
        for bounds,material in boxes:
            x0,y0,z0,x1,y1,z1=bounds
            left=int(24+(z0+0.95)*126); right=int(24+(z1+0.95)*126)
            top=int(58-y1*125); bottom=int(58-y0*125)
            d.rectangle((left,top,right,bottom),fill=colors[material],outline="#9b9c8e",width=1)
        save(image,name+"_icon")


def sound_assets():
    ffmpeg=shutil.which("ffmpeg")
    if not ffmpeg: raise RuntimeError("ffmpeg is needed only to regenerate the bundled .ogg sounds")
    rng=random.Random(782)
    for name,duration in [("rifle",0.18),("pistol",0.22),("reload",0.65),("empty",0.08)]:
        count=int(22050*duration); samples=[]; low=0
        for index in range(count):
            t=index/22050; noise=rng.uniform(-1,1); low=low*0.65+noise*0.35
            if name in ("rifle","pistol"):
                value=(0.6*noise+0.4*math.sin(t*math.tau*85))*math.exp(-t*35)
                value += low*math.exp(-t*16)*0.25
            else:
                value=noise*(math.exp(-t*90)+0.7*math.exp(-abs(t-0.3)*100))*0.35
            samples.append(struct.pack("<h",int(max(-1,min(1,value))*25000)))
        wav_path=CACHE/f"frontline_{name}.wav"
        with wave.open(str(wav_path),"wb") as out:
            out.setparams((1,2,22050,count,"NONE","not compressed")); out.writeframes(b"".join(samples))
        subprocess.run([ffmpeg,"-y","-loglevel","error","-i",str(wav_path),"-c:a","libvorbis","-q:a","4",str(SOUNDS/f"frontline_{name}.ogg")],check=True)


def main():
    for directory in (TEXTURES,MODELS,SOUNDS,SOURCES.parent): directory.mkdir(parents=True,exist_ok=True)
    with ThreadPoolExecutor(max_workers=3) as pool: sources=list(pool.map(source_texture,ASSETS))
    SOURCES.write_text(json.dumps([source[2] for source in sources],indent=2)+"\n",encoding="utf-8")
    surface_assets(sources); ui_assets(); gun_assets(); sound_assets()
    print("Generated photographic surfaces, original 3D weapons, HUD, targets and OGG audio.")


if __name__=="__main__": main()
