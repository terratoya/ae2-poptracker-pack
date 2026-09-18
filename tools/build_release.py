"""Build a PopTracker ZIP from runtime files and validate its references."""
import argparse
import hashlib
import json
import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def parse_json(text):
    return json.loads(re.sub(r"(?m)^\s*//.*$", "", text))


def build(changelog=None, tag=None):
    manifest = parse_json((ROOT / "manifest.json").read_text(encoding="utf-8-sig"))
    version = manifest["package_version"]
    if not re.fullmatch(r"[A-Za-z0-9._-]+", version):
        raise ValueError("Invalid package_version for archive filename")
    if tag is not None and tag != f"v{version}":
        raise ValueError(f"Release tag {tag!r} must match manifest version: v{version}")
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
    # This index is a release asset, outside the ZIP to avoid a circular checksum.
    checksum = hashlib.sha256(target.read_bytes()).hexdigest()
    index = {
        "versions": [{
            "package_version": version,
            "download_url": (
                f"https://github.com/terratoya/ae2-poptracker-pack/releases/"
                f"download/v{version}/{target.name}"
            ),
            "sha256": checksum,
            "changelog": changelog or [f"Release {version}"],
        }]
    }
    index_path = output / "versions.json"
    index_path.write_text(json.dumps(index, indent=2) + "\n", encoding="utf-8")
    print(f"Created: {target}")
    print(f"Version {version} | {len(files)} files | {target.stat().st_size / 1024 / 1024:.2f} MiB")
    print("ZIP integrity, JSON and static file references verified.")
    print(f"Update index: {index_path}")
    print(f"SHA-256: {checksum}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", help="Validate the release tag against package_version")
    parser.add_argument("--change", action="append", help="Changelog entry (repeatable)")
    args = parser.parse_args()
    build(changelog=args.change, tag=args.tag)
