"""Count JVM instruction lines against every tracked text line in this standalone example."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
paths = subprocess.check_output(["git", "ls-files", "-z"], cwd=ROOT).split(b"\0")
total = 0
opcodes = 0
for raw in filter(None, paths):
    path = ROOT / raw.decode()
    data = path.read_bytes()
    if b"\0" in data:
        continue
    lines = data.splitlines()
    total += len(lines)
    if path.suffix == ".jasm":
        opcodes += sum(bool(line.strip()) and not line.lstrip().startswith(b";") for line in lines)
print(f"JVM share: {opcodes:,} / {total:,} tracked text lines ({100 * opcodes / total:.2f}%)")
if 10 * opcodes < total:
    raise SystemExit("The JVM has been diluted below ten percent")
