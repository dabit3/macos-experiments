"""Runtime checks for the GUI scenario; artifacts are read, never injected."""
import inspect
import json
import os
from pathlib import Path
import subprocess
import sys
import time
from PIL import Image, ImageChops, ImageStat
import native as ui

OUT = Path(os.environ.get("SPACE_EVIDENCE", "/Users/devin/Desktop/SpaceEvidence/take1"))
OUT.mkdir(parents=True, exist_ok=True)
STATE = OUT.parent / "live-state.json"
state = {"chapter":"Ready", "status":"RUNNING", "results":[], "lines":[]}
expected = {}


def publish():
    temp=STATE.with_suffix(".tmp")
    temp.write_text(json.dumps(state))
    temp.replace(STATE)


def trace(frame, event, arg):
    if event=="line" and Path(frame.f_code.co_filename).name=="scenario.py":
        source=Path(frame.f_code.co_filename).read_text().splitlines()
        number=frame.f_lineno
        start=max(0, min(number-5, len(source)-19))
        state.update(file="scenario.py", line=number,
                     lines=[[i+1,source[i]] for i in range(start,min(len(source),start+19))])
        publish()
    return trace


def chapter(title, subtitle):
    state.update(chapter=title,subtitle=subtitle)
    publish()
    time.sleep(1)


def check(condition, text):
    status="PASS" if condition else "FAIL"
    state["results"].append({"status":status,"text":text,"time":time.time()})
    publish()
    print(status,text,flush=True)
    if not condition:
        raise AssertionError(text)


def shot(name):
    path=OUT/(name+".png")
    subprocess.run(["/usr/sbin/screencapture","-x","-D","1",str(path)],check=True)
    return path


def scene_count():
    scene=ui.find("AXStaticText","Scene")
    sx,sy,_,_=ui.rect(scene)
    candidates=[e for e,d in ui.walk(ui.get(ui.app(),"AXWindows")[0])
                if ui.get(e,"AXRole")=="AXStaticText"
                and str(ui.get(e,"AXValue","")).isdigit()
                and abs(ui.rect(e)[1]-sy)<5]
    return int(ui.get(candidates[0],"AXValue"))


def new_project():
    ui.key(45,command=True)
    ui.wait_for("Create project","AXButton")
    ui.field("Project name","ORBIT - material study",commit=False)
    ui.click("Create project")
    time.sleep(.6)
    ui.resize()
    check(scene_count()==0,"Blank stage: zero sample objects")


def object(primitive, name, xyz, scale, rotation, hex, metal, rough, add=True):
    if add:
        ui.click(primitive)
    ui.field("Name",name)
    for axis,value in zip("XYZ",xyz):
        ui.field(axis,value)
        check(float(ui.get(ui.find("AXTextField",axis),"AXValue"))==value,
              f"{name.split(' / ')[0]}: {axis} = {value}")
    values=[ui.slider(k,v) for k,v in zip(
        ["Scale","Rotation","Metalness","Roughness"],[scale,rotation,metal,rough])]
    ui.color(hex)
    rgb=str(ui.get(ui.find("AXColorWell"),"AXValue")).split()[1:4]
    desired=[int(hex[i:i+2],16)/255 for i in (0,2,4)]
    check(all(abs(float(a)-b)<.008 for a,b in zip(rgb,desired)),
          f"{name.split(' / ')[0]}: color #{hex}")
    expected[name]={"primitive":primitive.lower(),"x":xyz[0],"y":xyz[1],"z":xyz[2],
                    "scale":values[0],"rotation":values[1],
                    "metalness":values[2],"roughness":values[3],"color":hex}
    check(ui.get(ui.find("AXTextField","Name"),"AXValue")==name,
          f"{name.split(' / ')[0]}: transform + material edited")


def save_project():
    ui.click("Save")
    time.sleep(.5)
    ui.destination(OUT/"ORBIT.devin","Save")
    ui.wait_for("Project saved")
    data=json.loads((OUT/"ORBIT.devin").read_text())
    check(len(data["objects"])==6,"Saved project: six objects")
    for obj in data["objects"]:
        target=expected[obj["name"]]
        for key,value in target.items():
            actual=obj[key]
            if isinstance(value,(float,int)):
                assert abs(actual-value)<.001,(obj["name"],key,actual,value)
            else:
                assert actual.upper()==value.upper(),(key,actual,value)
    check(True,"Disk readback: all transforms/materials match")
    camera=data.get("sceneCamera")
    check(camera is not None and abs(camera["x"]-6)>.01,
          "Nondefault export camera persisted")
    return data


def reopen(data):
    shot("before-reopen")
    ui.key(13,command=True)
    time.sleep(.5)
    ui.key(31,command=True)
    time.sleep(.5)
    ui.destination(OUT/"ORBIT.devin","Open")
    time.sleep(.8)
    ui.resize()
    check(scene_count()==6,"Reopen: six scene rows restored")
    for name in expected:
        ui.find("AXStaticText",name)
    check(True,"Reopen: all six object names restored")
    ui.click("Copper / halo","AXStaticText")
    ui.wait_for("Name","AXTextField")
    check(ui.get(ui.find("AXTextField","Name"),"AXValue")=="Copper / halo",
          "Reopened object remains editable")
    check(json.loads((OUT/"ORBIT.devin").read_text())==data,
          "Reopen leaves saved project unchanged")
    shot("after-reopen")


def export(format):
    ui.click("Export")
    ui.wait_for("Export…","AXButton")
    if format=="scn":
        ui.click(role="AXPopUpButton")
        time.sleep(.25)
        # Select the native SceneKit menu item by its actual title.
        menu=next(e for e,d in ui.walk()
                  if ui.get(e,"AXRole")=="AXMenuItem"
                  and ".scn" in str(ui.get(e,"AXTitle","")))
        x,y,w,h=ui.rect(menu)
        ui.click_at(x+w/2,y+h/2)
    ui.click("Export…")
    time.sleep(.4)
    ui.destination(OUT/("ORBIT."+format),"Save")
    ui.wait_for("Export complete",timeout=20)
    path=OUT/("ORBIT."+format)
    check(path.exists() and path.stat().st_size>1000,
          f"{format.upper()} export written by Space")
    if format=="png":
        with Image.open(path) as image:
            check(image.size==(1600,1200),"PNG dimensions: 1600 x 1200")
            check(sum(ImageStat.Stat(image.convert("RGB")).stddev)>30,
                  "PNG contains varied rendered pixels")
    else:
        check(path.read_bytes().startswith(b"bplist"),"SCN is a binary SceneKit archive")


def finish():
    state["status"]="COMPLETE"
    publish()
    time.sleep(.3)
    shot("final-full-desktop")
    (OUT/"assertions.json").write_text(json.dumps(state,indent=2))
    time.sleep(7)


def fail(error):
    state["status"]="FAILED"
    state["results"].append({"status":"FAIL","text":str(error),"time":time.time()})
    publish()
    time.sleep(.3)
    shot("failure-full-desktop")
    (OUT/"assertions.json").write_text(json.dumps(state,indent=2))


sys.settrace(trace)
