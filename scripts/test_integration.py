"""Exercise two genuine Luanti clients against an isolated VoxeLibre server."""
import ctypes
from ctypes import wintypes
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

from bootstrap import ROOT, ENGINE
from prepare import prepare


def capture_window(pid, destination):
    from PIL import Image
    user32=ctypes.windll.user32
    gdi32=ctypes.windll.gdi32
    user32.GetDC.argtypes=[wintypes.HWND]
    user32.ReleaseDC.argtypes=[wintypes.HWND,wintypes.HDC]
    user32.GetClientRect.argtypes=[wintypes.HWND,ctypes.POINTER(wintypes.RECT)]
    user32.ShowWindow.argtypes=[wintypes.HWND,ctypes.c_int]
    user32.GetWindowThreadProcessId.argtypes=[wintypes.HWND,ctypes.POINTER(wintypes.DWORD)]
    handles=[]
    callback_type=ctypes.WINFUNCTYPE(wintypes.BOOL,wintypes.HWND,wintypes.LPARAM)
    @callback_type
    def enumerate_window(hwnd,_):
        window_pid=wintypes.DWORD()
        user32.GetWindowThreadProcessId(hwnd,ctypes.byref(window_pid))
        if window_pid.value==pid:
            rect=wintypes.RECT(); user32.GetClientRect(hwnd,ctypes.byref(rect))
            if rect.right>500 and rect.bottom>300: handles.append(hwnd)
        return True
    user32.EnumWindows(enumerate_window,0)
    if not handles: return False
    hwnd=handles[0]
    user32.ShowWindow(hwnd,4) # Display for capture without taking keyboard focus.
    time.sleep(0.5)
    rect=wintypes.RECT(); user32.GetClientRect(hwnd,ctypes.byref(rect))
    width,height=rect.right,rect.bottom
    user32.GetDC.restype=wintypes.HDC
    gdi32.CreateCompatibleDC.argtypes=[wintypes.HDC];gdi32.CreateCompatibleDC.restype=wintypes.HDC
    gdi32.CreateCompatibleBitmap.argtypes=[wintypes.HDC,ctypes.c_int,ctypes.c_int];gdi32.CreateCompatibleBitmap.restype=wintypes.HBITMAP
    gdi32.SelectObject.argtypes=[wintypes.HDC,wintypes.HGDIOBJ];gdi32.SelectObject.restype=wintypes.HGDIOBJ
    gdi32.BitBlt.argtypes=[wintypes.HDC,ctypes.c_int,ctypes.c_int,ctypes.c_int,ctypes.c_int,wintypes.HDC,ctypes.c_int,ctypes.c_int,wintypes.DWORD]
    dc=user32.GetDC(hwnd); memory=gdi32.CreateCompatibleDC(dc)
    bitmap=gdi32.CreateCompatibleBitmap(dc,width,height); old=gdi32.SelectObject(memory,bitmap)
    gdi32.BitBlt(memory,0,0,width,height,dc,0,0,0x00CC0020)
    class Header(ctypes.Structure):
        _fields_=[("size",wintypes.DWORD),("width",wintypes.LONG),("height",wintypes.LONG),
            ("planes",wintypes.WORD),("bits",wintypes.WORD),("compression",wintypes.DWORD),
            ("image_size",wintypes.DWORD),("x",wintypes.LONG),("y",wintypes.LONG),
            ("used",wintypes.DWORD),("important",wintypes.DWORD)]
    header=Header(ctypes.sizeof(Header),width,-height,1,32,0,0,0,0,0,0)
    buffer=ctypes.create_string_buffer(width*height*4)
    gdi32.GetDIBits.argtypes=[wintypes.HDC,wintypes.HBITMAP,wintypes.UINT,wintypes.UINT,ctypes.c_void_p,ctypes.c_void_p,wintypes.UINT]
    gdi32.GetDIBits(memory,bitmap,0,height,buffer,ctypes.byref(header),0)
    Image.frombytes("RGB",(width,height),buffer.raw,"raw","BGRX").save(destination)
    gdi32.SelectObject(memory,old)
    gdi32.DeleteObject.argtypes=[wintypes.HGDIOBJ];gdi32.DeleteObject(bitmap)
    gdi32.DeleteDC.argtypes=[wintypes.HDC];gdi32.DeleteDC(memory)
    user32.ReleaseDC(hwnd,dc)
    return True


def main():
    run=ROOT/"tests/artifacts"/time.strftime("%Y%m%d-%H%M%S")
    run.mkdir(parents=True)
    world=run/"world"
    prepare(world)
    shutil.copytree(ROOT/"tests/frontline_qa",world/"worldmods/frontline_qa")
    settings=(ROOT/"config/server.conf").read_text()+"\nport = 30001\nbind_address = 127.0.0.1\nfrontline_test_mode = true\n"
    (run/"server.conf").write_text(settings,encoding="utf-8")
    processes=[]; outputs=[]
    def start(arguments,name):
        output=(run/f"{name}-console.log").open("wb"); outputs.append(output)
        process=subprocess.Popen([str(ENGINE/"bin/luanti.exe"),*arguments],stdout=output,stderr=subprocess.STDOUT,
            creationflags=subprocess.CREATE_NO_WINDOW)
        processes.append(process)
        return process
    try:
        server=start(["--server","--world",str(world),"--config",str(run/"server.conf"),"--logfile",str(run/"server.log")],"server")
        deadline=time.monotonic()+140
        while time.monotonic()<deadline:
            log=(run/"server.log").read_text(encoding="utf-8",errors="replace") if (run/"server.log").exists() else ""
            if "Server for gameid=" in log: break
            if server.poll() is not None: raise RuntimeError("Server exited; see "+str(run/"server.log"))
            time.sleep(0.4)
        else: raise RuntimeError("Server startup timed out")
        print("Server listening. Starting two real clients.",flush=True)
        clients=[]
        for name in ("QAAlpha","QABravo"):
            client_settings=(ROOT/"config/client.conf").read_text()
            client_settings+="\nenable_dynamic_shadows = false\ntexture_path = "+str(ROOT/"assets/frontline_realism")+"\n"
            (run/f"{name}.conf").write_text(client_settings,encoding="utf-8")
            clients.append(start(["--go","--address","127.0.0.1","--port","30001","--name",name,
                "--password","Disposable-QA-Only","--config",str(run/f"{name}.conf"),"--logfile",str(run/f"{name}.log")],name))
        deadline=time.monotonic()+140
        report_path=world/"qa-results.json"
        while time.monotonic()<deadline:
            if report_path.exists():
                report=json.loads(report_path.read_text())
                for client,name in zip(clients,("alpha","bravo")):
                    try: capture_window(client.pid,run/f"{name}.png")
                    except Exception as error: print("Capture unavailable:",error)
                shutil.copyfile(report_path,run/"results.json")
                print(json.dumps(report,ensure_ascii=False,indent=2),flush=True)
                (ROOT/"tests/artifacts/latest.txt").write_text(str(run),encoding="utf-8")
                server.wait(timeout=20)
                return 0 if report["passed"] else 1
            if server.poll() is not None: raise RuntimeError("Server exited before results")
            for client in clients:
                if client.poll() is not None: raise RuntimeError("A client exited before results; see client logs")
            time.sleep(0.3)
        raise RuntimeError("Integration test timed out; see "+str(run))
    finally:
        (world/"frontline-stop-request").write_text("stop")
        for process in reversed(processes):
            if process.poll() is None:
                if process is server:
                    try: process.wait(timeout=10); continue
                    except subprocess.TimeoutExpired: pass
                process.terminate(); process.wait(timeout=10)
        for output in outputs: output.close()
        print("Artifacts:",run,flush=True)


if __name__=="__main__": sys.exit(main())
