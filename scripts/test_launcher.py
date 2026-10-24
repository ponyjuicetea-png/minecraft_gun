"""Smoke-test the actual Windows launcher and graceful background-server stop."""
import ctypes
from ctypes import wintypes
from pathlib import Path
import subprocess
import re
import time
from bootstrap import ROOT
from test_integration import capture_window


def window_pids():
    pids=[]
    user32=ctypes.windll.user32
    callback_type=ctypes.WINFUNCTYPE(wintypes.BOOL,wintypes.HWND,wintypes.LPARAM)
    @callback_type
    def callback(hwnd,_):
        length=user32.GetWindowTextLengthW(hwnd)
        if length:
            title=ctypes.create_unicode_buffer(length+1);user32.GetWindowTextW(hwnd,title,length+1)
            if title.value.startswith("Luanti 5.17.0"):
                process=wintypes.DWORD();user32.GetWindowThreadProcessId(hwnd,ctypes.byref(process));pids.append(process.value)
        return True
    user32.EnumWindows(callback,0)
    return set(pids)


def main():
    initial=window_pids()
    log_path=ROOT/"logs/server.log"
    log_offset=len(log_path.read_text(encoding="utf-8",errors="replace")) if log_path.exists() else 0
    launcher=["powershell","-NoProfile","-ExecutionPolicy","Bypass","-File",str(ROOT/"scripts/launch.ps1")]
    try:
        for mode,name in [("Play","LaunchSmokeA"),("Player2","LaunchSmokeB")]:
            result=subprocess.run([*launcher,"-Mode",mode,"-PlayerName",name],capture_output=True,text=True,encoding="utf-8",errors="replace",timeout=60)
            print(result.stdout,flush=True)
            if result.returncode: raise RuntimeError(result.stderr)
        deadline=time.monotonic()+100
        while time.monotonic()<deadline:
            log=log_path.read_text(encoding="utf-8",errors="replace")[log_offset:]
            if re.search(r"LaunchSmokeA .*joins game",log) and re.search(r"LaunchSmokeB .*joins game",log):
                print("PASS actual launchers start a server and authenticate two clients",flush=True)
                time.sleep(3)
                for pid in window_pids()-initial:
                    try:
                        if capture_window(pid,ROOT/"logs/launcher-preview.png"): break
                    except Exception as error: print("Optional preview unavailable:",error)
                break
            time.sleep(0.4)
        else: raise RuntimeError("Players did not join; see logs")
        subprocess.run([*launcher,"-Mode","Stop"],check=True,timeout=20)
        deadline=time.monotonic()+20
        while time.monotonic()<deadline:
            log=log_path.read_text(encoding="utf-8",errors="replace")[log_offset:]
            if "Server: Shutting down" in log:
                print("PASS background server saves and shuts down",flush=True)
                break
            time.sleep(0.2)
        else: raise RuntimeError("Graceful shutdown not observed")
    finally:
        (ROOT/"worlds/frontline/frontline-stop-request").write_text("stop")
        for pid in window_pids()-initial:
            subprocess.run(["taskkill","/PID",str(pid)],capture_output=True)


if __name__=="__main__":main()
