#!/usr/bin/env bash
set -e

echo "== Blinders Cassino build sem node_modules =="
rm -rf dist
mkdir -p dist

python3 - <<'PY'
import zipfile, os, shutil

source = "site.zip"
output = "dist"

if not os.path.exists(source):
    raise SystemExit("site.zip não encontrado.")

with zipfile.ZipFile(source, "r") as z:
    z.extractall(output)

for rel in ["_redirects", "database"]:
    p = os.path.join(output, rel)
    if os.path.isdir(p):
        shutil.rmtree(p, ignore_errors=True)
    elif os.path.exists(p):
        os.remove(p)

headers = "/*\n  X-Frame-Options: DENY\n  X-Content-Type-Options: nosniff\n  Referrer-Policy: strict-origin-when-cross-origin\n\n/assets/*\n  Cache-Control: public, max-age=3600\n"
with open(os.path.join(output, "_headers"), "w", encoding="utf-8") as f:
    f.write(headers)

not_found = os.path.join(output, "404.html")
if not os.path.exists(not_found):
    html = '<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>404</title></head><body><main><h1>404</h1><p>Página não encontrada.</p><a href="/menu.html">Menu</a></main></body></html>'
    with open(not_found, "w", encoding="utf-8") as f:
        f.write(html)
PY

echo "Build concluído em dist/"
echo "Arquivos no dist:"
find dist -maxdepth 2 -type f | head -40
