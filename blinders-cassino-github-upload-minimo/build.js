const fs = require("fs");
const path = require("path");
const AdmZip = require("adm-zip");

const source = path.join(__dirname, "site.zip");
const output = path.join(__dirname, "dist");

if (!fs.existsSync(source)) {
  console.error("site.zip não encontrado.");
  process.exit(1);
}

if (fs.existsSync(output)) {
  fs.rmSync(output, { recursive: true, force: true });
}
fs.mkdirSync(output, { recursive: true });

const zip = new AdmZip(source);
zip.extractAllTo(output, true);

console.log("Blinders Cassino extraído para dist/");
console.log("Arquivos prontos para Cloudflare Pages.");
