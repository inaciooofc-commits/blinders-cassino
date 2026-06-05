# Blinders Cassino — Upload mínimo para GitHub

Este pacote existe para resolver limite de quantidade de arquivos no upload do GitHub.

Você só precisa subir estes poucos arquivos no repositório:

- `site.zip`
- `package.json`
- `build.js`
- `README.md`
- `SQL_PARA_COLAR_NO_SUPABASE.sql`

## Cloudflare Pages

Configure assim:

```text
Framework preset: None
Build command: npm install && npm run build
Output directory: dist
Root directory: /
```

O Cloudflare vai instalar a dependência, rodar `build.js`, descompactar `site.zip` e publicar a pasta `dist`.

## Supabase

Cole no SQL Editor:

```text
SQL_PARA_COLAR_NO_SUPABASE.sql
```

## Observação

Não suba secrets, service_role key, senhas ou tokens privados.
