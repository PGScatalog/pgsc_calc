#!/usr/bin/env python3
"""Merge shard archives without decompressing genotype arrays into memory."""
import json
import shutil
import sys
import zipfile
from pathlib import PurePosixPath


def pack(output, inputs):
    seen = {}
    with zipfile.ZipFile(output, 'x', compression=zipfile.ZIP_STORED, allowZip64=True) as out:
        for source in inputs:
            with zipfile.ZipFile(source) as archive:
                for member in archive.infolist():
                    if member.is_dir():
                        continue
                    path = PurePosixPath(member.filename)
                    if path.is_absolute() or '..' in path.parts or path.parts[0] != 'genotypes.zarr':
                        raise ValueError(f'Invalid cache member: {member.filename}')
                    ancestor = len(path.parts) <= 4 and path.name == 'zarr.json'
                    # Root, sampleset and chromosome metadata must agree exactly.
                    if member.filename in seen:
                        if not ancestor or seen[member.filename] != json.loads(archive.read(member)):
                            raise ValueError(f'Duplicate cache leaf or inconsistent metadata: {member.filename}')
                        continue
                    seen[member.filename] = json.loads(archive.read(member)) if ancestor else None
                    with archive.open(member) as src, out.open(member.filename, 'w', force_zip64=True) as dst:
                        shutil.copyfileobj(src, dst, length=1024 * 1024)


if __name__ == '__main__':
    pack(sys.argv[1], sys.argv[2:])
