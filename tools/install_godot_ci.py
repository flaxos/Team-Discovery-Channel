#!/usr/bin/env python3
"""Install official Godot 4.4.1 Linux x86_64 release and verify its published SHA512."""
import argparse
import hashlib
from pathlib import Path
import shutil
import tempfile
import urllib.request
import zipfile

VERSION = '4.4.1'
BINARY = f'Godot_v{VERSION}-stable_linux.x86_64'
ARCHIVE = BINARY + '.zip'
BASE = f'https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable/'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--destination', type=Path, required=True)
    args = parser.parse_args()
    args.destination.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='godot-install-') as temp:
        archive = Path(temp) / ARCHIVE
        checksums = urllib.request.urlopen(BASE + 'SHA512-SUMS.txt', timeout=60).read().decode()
        expected = None
        for line in checksums.splitlines():
            fields = line.split()
            if len(fields) == 2 and fields[1].lstrip('*') == ARCHIVE:
                expected = fields[0]
                break
        if expected is None:
            raise SystemExit('Official checksum list does not contain the pinned archive')
        urllib.request.urlretrieve(BASE + ARCHIVE, archive)
        with archive.open('rb') as stream:
            actual = hashlib.file_digest(stream, 'sha512').hexdigest()
        if actual != expected:
            raise SystemExit('Godot archive checksum mismatch')
        with zipfile.ZipFile(archive) as bundle:
            with bundle.open(BINARY) as source, (args.destination / 'godot').open('wb') as destination:
                shutil.copyfileobj(source, destination)
    (args.destination / 'godot').chmod(0o755)
    print(f'Installed checksum-verified Godot {VERSION} at {args.destination / "godot"}')


if __name__ == '__main__':
    main()
