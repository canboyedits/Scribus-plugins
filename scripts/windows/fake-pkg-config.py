import os
import re
import sys
from pathlib import Path

PC_DIR = Path(os.environ.get("SCRIBUS_PKGCONFIG_DIR", r"C:\Developer\scribus-v2\pkgconfig"))
ALIASES = {
    "podofo": "podofo", "libpodofo": "libpodofo",
    "poppler": "poppler", "libpoppler": "libpoppler",
    "poppler-cpp": "poppler-cpp", "libpoppler-cpp": "libpoppler-cpp",
}

def module_name(value):
    return re.split(r"(>=|<=|=|>|<)", value.strip().strip('"').strip("'"))[0]

def read_pc(name):
    path = PC_DIR / f"{ALIASES.get(module_name(name), module_name(name))}.pc"
    if not path.exists():
        return None
    values, lines = {}, path.read_text(encoding="ascii", errors="ignore").splitlines()
    for line in lines:
        line = line.strip()
        if line and not line.startswith("#") and "=" in line and ":" not in line.split("=", 1)[0]:
            key, value = line.split("=", 1)
            values[key.strip()] = value.strip()
    def expand(value):
        previous = None
        while value != previous:
            previous = value
            for key, replacement in values.items():
                value = value.replace("${" + key + "}", replacement)
        return value
    for line in lines:
        line = line.strip()
        for field in ("Version", "Libs", "Cflags"):
            if line.startswith(field + ":"):
                values[field] = expand(line.split(":", 1)[1].strip())
    return {key: expand(value) for key, value in values.items()}

args = sys.argv[1:]
if not args:
    raise SystemExit(0)
if "--version" in args:
    print("0.29.2-fake")
    raise SystemExit(0)

modules = [arg for arg in args if not arg.startswith("-")]
records = [read_pc(module) for module in modules]
if any(record is None for record in records):
    raise SystemExit(1)
if "--exists" in args:
    raise SystemExit(0)
if "--modversion" in args:
    print(" ".join(record.get("Version", "0") for record in records))
    raise SystemExit(0)

variable = next((arg.split("=", 1)[1] for arg in args if arg.startswith("--variable=")), None)
if variable:
    print(" ".join(record.get(variable, "") for record in records))
    raise SystemExit(0)

if any(arg.startswith("--libs") for arg in args):
    tokens = [token for record in records for token in record.get("Libs", "").split()]
    if "--libs-only-L" in args:
        tokens = [token for token in tokens if token.startswith("-L")]
    elif "--libs-only-l" in args:
        tokens = [token for token in tokens if token.startswith("-l")]
    elif "--libs-only-other" in args:
        tokens = [token for token in tokens if not token.startswith(("-L", "-l"))]
    print(" ".join(tokens))
    raise SystemExit(0)

if any(arg.startswith("--cflags") for arg in args):
    tokens = [token for record in records for token in record.get("Cflags", "").split()]
    if "--cflags-only-I" in args:
        tokens = [token for token in tokens if token.startswith("-I")]
    elif "--cflags-only-other" in args:
        tokens = [token for token in tokens if not token.startswith("-I")]
    print(" ".join(tokens))

