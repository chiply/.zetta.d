#!/usr/bin/env bash
# Index the sample corpus (corpus/*.org) into the running org-db-v3 server.
# Content-only: semantic search embeds the file body, so no org parsing needed.
#
# The database persists on disk, so you normally run this once. Re-run after
# editing the sample files. Equivalent to M-x chiply-isr-index-corpus in Emacs.
#
# Usage: ./index-corpus.sh
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CORPUS="$HERE/corpus"
URL="http://127.0.0.1:8765/api/file"

python3 - "$CORPUS" "$URL" <<'PY'
import sys, os, glob, hashlib, json, urllib.request
corpus, url = sys.argv[1], sys.argv[2]
files = sorted(glob.glob(os.path.join(corpus, "*.org")))
ok = 0
for fn in files:
    data = open(fn, "rb").read()
    payload = {"filename": fn, "md5": hashlib.md5(data).hexdigest(),
               "file_size": len(data), "content": data.decode("utf-8", "replace"),
               "headlines": [], "links": [], "keywords": [],
               "src_blocks": [], "images": [], "linked_files": []}
    req = urllib.request.Request(url, data=json.dumps(payload).encode(),
                                 headers={"Content-Type": "application/json"}, method="POST")
    urllib.request.urlopen(req, timeout=120); ok += 1
    print(f"  indexed {os.path.basename(fn)}")
print(f"indexed {ok}/{len(files)} sample files")
PY
