"""Build a PopTracker ZIP from runtime files and validate its references."""
import json
import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def parse_json(text):
    return json.loads(re.sub(r"(?m)^\s*//.*$", "", text))


def build():
    manifest = parse_json((ROOT / "manifest.json").read_text(encoding="utf-8-sig"))
    version = manifest["package_version"]
    if not re.fullmatch(r"[A-Za-z0-9._-]+", version):
        raise ValueError("Invalid package_version for archive filename")
    output = ROOT / ".local-notes" / "releases"
    output.mkdir(parents=True, exist_ok=True)
    target = output / f"ae2-poptracker-pack-{version}.zip"
    temporary = target.with_suffix(".zip.tmp")
    files = [ROOT / name for name in ("manifest.json", "settings.json", "README.md", "LICENSE")]
    for directory in ("images", "items", "layouts", "locations", "maps", "scripts"):
        files.extend(path for path in (ROOT / directory).rglob("*")
                     if path.is_file() and path.suffix in (".png", ".json", ".jsonc", ".lua"))
    try:
        with zipfile.ZipFile(temporary, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
            for path in sorted(files):
                archive.write(path, path.relative_to(ROOT).as_posix())
        with zipfile.ZipFile(temporary) as archive:
            damaged = archive.testzip()
            if damaged is not None:
                raise ValueError(f"Corrupt archive entry: {damaged}")
            names = set(archive.namelist())
            for name in names:
                if not name.endswith((".json", ".jsonc", ".lua")):
                    continue
                text = archive.read(name).decode("utf-8-sig")
                if name.endswith((".json", ".jsonc")):
                    parse_json(text)
                references = re.findall(
                    r'"((?:images|items|layouts|locations|maps|scripts)/[^"\n]+\.(?:png|jsonc|json|lua))"', text)
                for reference in references:
                    if reference not in names:
                        raise ValueError(f"{name}: missing file {reference}")
        temporary.replace(target)
    finally:
        temporary.unlink(missing_ok=True)
    print(f"Created: {target}")
    print(f"Version {version} | {len(files)} files | {target.stat().st_size / 1024 / 1024:.2f} MiB")
    print("ZIP integrity, JSON and static file references verified.")


if __name__ == "__main__":
    build()
