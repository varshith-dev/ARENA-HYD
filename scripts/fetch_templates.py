"""Download just the matching Android template using validated HTTP ZIP ranges."""
import io
import json
import pathlib
import urllib.request
import zipfile
import time

ROOT = pathlib.Path(__file__).resolve().parents[1]
VERSION = '4.7.2-stable'
URL = f'https://github.com/godotengine/godot-builds/releases/download/{VERSION}/Godot_v{VERSION}_export_templates.tpz'
SIZE = 1281349702

class RemoteZip(io.RawIOBase):
    def __init__(self):
        self.pos = 0
    def seekable(self): return True
    def readable(self): return True
    def tell(self): return self.pos
    def seek(self, offset, whence=0):
        self.pos = offset if whence == 0 else self.pos + offset if whence == 1 else SIZE + offset
        return self.pos
    def read(self, size=-1):
        if size < 0: size = SIZE-self.pos
        if size == 0: return b''
        start, end = self.pos, min(SIZE-1,self.pos+size-1)
        request = urllib.request.Request(URL,headers={'Range':f'bytes={start}-{end}','User-Agent':'ArenaHyderabad-build/0.1'})
        for attempt in range(4):
            try:
                with urllib.request.urlopen(request,timeout=120) as response:
                    if response.status != 206: raise RuntimeError('Range request not honored; refusing full ZIP download')
                    result = response.read()
                    if len(result) != end-start+1: raise RuntimeError('Incomplete range')
                    self.pos += len(result)
                    return result
            except Exception:
                if attempt == 3: raise
                time.sleep(1+attempt)

target = ROOT/'tools'/'export_templates'
target.mkdir(parents=True,exist_ok=True)
with zipfile.ZipFile(RemoteZip()) as archive:
    for entry in archive.infolist():
        if not entry.filename.endswith(('android_debug.apk','android_release.apk','version.txt')): continue
        output = target/pathlib.PurePosixPath(entry.filename).name
        if output.exists() and output.stat().st_size == entry.file_size: continue
        print(f'Fetching {output.name} ({entry.compress_size/1e6:.1f} MB transfer)',flush=True)
        content = archive.read(entry)
        output.write_bytes(content)
        print(f'Validated CRC and extracted {output.name}',flush=True)
