# Blinders Cassino — Upload mínimo v3 sem node_modules

Este pacote corrige o erro:

`Asset too large: node_modules/workerd/bin/workerd 119 MiB`

O erro acontece quando:
- você usa `npm install` e o Cloudflare publica a raiz `/`, ou
- o Output directory está errado.

## Suba no GitHub apenas estes arquivos

- `site.zip`
- `build.sh`
- `package.json`
- `_redirects`
- `README.md`
- `SQL_PARA_COLAR_NO_SUPABASE.sql`

## Cloudflare Pages

Use exatamente:

```text
Framework preset: None
Build command: bash build.sh
Output directory: dist
Root directory: /
```

Não use:

```text
npm install && npm run build
```

Não use Output directory `/`.

## Supabase

Cole no SQL Editor:

```text
SQL_PARA_COLAR_NO_SUPABASE.sql
```
