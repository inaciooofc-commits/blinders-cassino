# Blinders Cassino — Upload mínimo v2 sem erro de _redirects

Este pacote corrige o erro:

`Invalid _redirects configuration: Got 404`

## Suba no GitHub somente estes arquivos

- `site.zip`
- `package.json`
- `build.js`
- `_redirects`
- `README.md`
- `SQL_PARA_COLAR_NO_SUPABASE.sql`

## Importante

Se no repositório antigo existir um `_redirects` com:

`/database/* /404.html 404`

apague ele ou substitua pelo `_redirects` deste pacote.

## Cloudflare Pages

Use exatamente:

```text
Framework preset: None
Build command: npm install && npm run build
Output directory: dist
Root directory: /
```

O `build.js` remove qualquer `_redirects` inválido de dentro do `site.zip`.

## Supabase

Cole:

`SQL_PARA_COLAR_NO_SUPABASE.sql`
