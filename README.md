# Blinders Cassino — GitHub Ready

Pacote pronto para subir no GitHub e conectar no Cloudflare Pages.

## O que está incluído

- Site estático completo na raiz do repositório.
- Banco IRIS Control + submenus.
- Menu hambúrguer reorganizado em submenus.
- Jogos reais e módulos anteriores preservados.
- UI premium aplicada com:
  - `/assets/blinders-effects.css`
  - `/assets/blinders-effects.js`
- SQL para colar no Supabase em:
  - `database/SQL_PARA_COLAR_NO_SUPABASE.sql`
  - `database/SQL_COMPLETO_TODAS_ATUALIZACOES_DISPONIVEIS.sql`

## Como subir no GitHub

1. Crie um repositório chamado `blinders-cassino`.
2. Extraia este ZIP.
3. Arraste tudo para o repositório.
4. Faça commit.

Sugestão de commit:

```text
Blinders Cassino GitHub ready
```

## Cloudflare Pages

Configuração:

```text
Framework preset: None
Build command: vazio
Output directory: /
Root directory: /
```

## Supabase

Para banco já atualizado, cole:

```text
database/SQL_PARA_COLAR_NO_SUPABASE.sql
```

Para reaplicar a sequência completa de atualizações disponíveis, use:

```text
database/SQL_COMPLETO_TODAS_ATUALIZACOES_DISPONIVEIS.sql
```

## Segurança

Não coloque no GitHub:

- service_role key
- senhas reais
- segredos privados
- tokens pessoais

A chave `anon` do Supabase pode ficar no frontend, desde que as funções continuem protegidas por token/login.
