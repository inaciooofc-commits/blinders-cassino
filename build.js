const fs = require("fs");
const path = require("path");
const AdmZip = require("adm-zip");

const source = path.join(__dirname, "site.zip");
const output = path.join(__dirname, "dist");

function rm(p) {
  if (fs.existsSync(p)) fs.rmSync(p, { recursive: true, force: true });
}

if (!fs.existsSync(source)) {
  console.error("site.zip não encontrado.");
  process.exit(1);
}

rm(output);
fs.mkdirSync(output, { recursive: true });

const zip = new AdmZip(source);
zip.extractAllTo(output, true);

// Segurança do deploy: Cloudflare rejeita _redirects com status 404.
// Para não falhar, removemos qualquer _redirects extraído do site.zip.
rm(path.join(output, "_redirects"));

// Remove database do site publicado. O SQL fica só na raiz do repositório.
rm(path.join(output, "database"));

// Mantém um _headers simples e válido dentro do dist.
fs.writeFileSync(path.join(output, "_headers"), `/*
  X-Frame-Options: DENY
  X-Content-Type-Options: nosniff
  Referrer-Policy: strict-origin-when-cross-origin

/assets/*
  Cache-Control: public, max-age=3600
`, "utf8");

// Garante fallback SPA/HTML sem usar _redirects inválido.
const notFound = path.join(output, "404.html");
if (!fs.existsSync(notFound)) {
  fs.writeFileSync(notFound, `<!doctype html><html lang="pt-BR"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>404</title></head><body><main><h1>404</h1><p>Página não encontrada.</p><a href="/menu.html">Menu</a></main></body></html>`, "utf8");
}

console.log("Blinders Cassino extraído para dist/");
console.log("Correção aplicada: dist/_redirects removido.");
console.log("Correção aplicada: dist/database removido.");
console.log("Deploy pronto para Cloudflare Pages.");
