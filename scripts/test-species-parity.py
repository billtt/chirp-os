#!/usr/bin/env python3
"""Protect the separately compiled desktop timelines and atlas contract from drift."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
swift = (ROOT / 'platforms/macos/Sources/BirdingCore/SpeciesBehavior.swift').read_text()
csharp = (ROOT / 'platforms/windows/ChirpOS.Core/SpeciesBehavior.cs').read_text()
source = json.loads((ROOT / 'platforms/macos/Sources/BirdingCore/Resources/species.json').read_text())
shared = json.loads((ROOT / 'shared/species.json').read_text())
assert source == shared, 'Shared catalog is stale'
ids = {bird['id'] for bird in source['species']}
swift_rows = re.findall(r'case \.(\w+): return Motion\(action: \.(\w+), cycle: ([\d.]+), start: ([\d.]+), duration: ([\d.]+), rate: ([\d.]+), hop: ([\d.]+)\)', swift)
cs_rows = re.findall(r'"(\w+)" => new\("(\w+)", ([\d.]+), ([\d.]+), ([\d.]+), ([\d.]+), ([\d.]+)\)', csharp)
def normalized(rows):
    return {row[0]: (row[1], *map(float, row[2:])) for row in rows}
assert set(normalized(swift_rows)) == ids, 'Missing Swift species schedule'
assert normalized(swift_rows) == normalized(cs_rows), 'Windows schedule differs from macOS'
manifest = json.loads((ROOT / 'shared/art/manifest.json').read_text())
art_source = (ROOT / 'platforms/macos/Sources/Birding/PixelArt.swift').read_text()
frames = re.findall(r'"([a-z]+\d*)"', re.search(r'static let names = \[(.*?)\]', art_source).group(1))
assert manifest['frames'] == frames, 'Atlas frame order is stale'
assert set(manifest['frameSizes']) == ids, 'Missing species in atlas manifest'
assert all((ROOT / 'shared/art' / f'{id}.png').is_file() for id in ids)
print(f'PASS: {len(ids)} matching species schedules and {len(frames)} shared frame names')
