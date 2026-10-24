"""Boot the distributed Windows binary with its own fresh world and real rendering."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
output = ROOT / "reports" / "export-preview.png"
world = ROOT / "test-runs" / "export-smoke" / "world.sqlite"
world.parent.mkdir(parents=True, exist_ok=True)
if output.exists():
    output.unlink()
command = [
    str(ROOT / "dist" / "Frontline.exe"),
    "--resolution", "1280x720", "--max-fps", "60",
    "--", "--play", "--world", str(world),
    "--capture", str(output), "--capture-quit",
]
result = subprocess.run(
    command, capture_output=True, timeout=90,
    cwd=ROOT / "dist", creationflags=subprocess.CREATE_NO_WINDOW,
)
log = (result.stdout + result.stderr).decode("utf-8", errors="replace")
(ROOT / "reports" / "export-smoke.log").write_text(log, encoding="utf-8")
for line in log.splitlines():
    if any(word in line for word in ("ERROR", "SCRIPT", "FRONTLINE", "Error")):
        print(line)
assert result.returncode == 0, result.returncode
assert "FRONTLINE_CAPTURE_SAVED" in log and output.is_file(), "No rendered frame saved"
assert "SCRIPT ERROR" not in log and "ERROR:" not in log, "See export-smoke.log"
print("Exported Windows executable: PASS")
