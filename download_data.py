"""Download the original public processed file and verify its recorded hash."""
from pathlib import Path
from urllib.request import Request, urlopen
import hashlib
URL = 'https://osf.io/download/b6m3u/'
EXPECTED = 'd5bc284a66ac805bbac3adba7ff636ecac5364ef3cace074b370b911f09aeb13'
ROOT = Path(__file__).resolve().parent
dest = ROOT / 'data' / 'sms.imp.processed.RData'
dest.parent.mkdir(parents=True, exist_ok=True)
if dest.exists() and hashlib.sha256(dest.read_bytes()).hexdigest() == EXPECTED:
    print('Existing original data file verified.'); raise SystemExit(0)
temp = dest.with_suffix('.download')
try:
    req = Request(URL, headers={'User-Agent': 'Academic secondary-data portfolio / provenance check'})
    with urlopen(req, timeout=90) as response, temp.open('wb') as target:
        while chunk := response.read(1024*1024): target.write(chunk)
    found = hashlib.sha256(temp.read_bytes()).hexdigest()
    if found != EXPECTED:
        raise RuntimeError(f'Source file changed: expected {EXPECTED}, received {found}. Inspect the repository before analysis.')
    temp.replace(dest)
    print(f'Downloaded and verified {dest.name}: {dest.stat().st_size:,} bytes.')
finally:
    if temp.exists(): temp.unlink()
