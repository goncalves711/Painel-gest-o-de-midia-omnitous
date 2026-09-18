-- PARTE 1 de 3 · tabelas e permissões
-- Rode este arquivo inteiro no SQL Editor.

-- ═══════════════════════════════════════════════════════════
-- Painel de postagens · estrutura completa
-- Rode num projeto Supabase novo para recriar tudo.
-- ═══════════════════════════════════════════════════════════

create extension if not exists pgcrypto with schema extensions;

create table if not exists public.painel_config (
  chave text primary key,
  valor text not null,
  atualizado_em timestamptz not null default now()
);

create table if not exists public.painel_posts (
  id            uuid primary key default gen_random_uuid(),
  titulo        text not null,
  legenda       text not null default '',
  midia_url     text,
  rede          text not null default 'linkedin',
  data_publicacao date,
  status        text not null default 'rascunho',
  aprovado_em   timestamptz,
  aprovado_por  text,
  publicado_em  timestamptz,
  criado_em     timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  constraint painel_posts_status_ok check (status in
    ('rascunho','aguardando','aprovado','ajuste','publicado')),
  constraint painel_posts_rede_ok check (rede in
    ('linkedin','instagram','facebook','ambas'))
);
create index if not exists painel_posts_data_idx on public.painel_posts(data_publicacao);

create table if not exists public.painel_ajustes (
  id           uuid primary key default gen_random_uuid(),
  post_id      uuid not null references public.painel_posts(id) on delete cascade,
  texto        text not null,
  autor        text,
  criado_em    timestamptz not null default now(),
  resolvido_em timestamptz
);
create index if not exists painel_ajustes_post_idx on public.painel_ajustes(post_id);

create table if not exists public.painel_solicitacoes (
  id            uuid primary key default gen_random_uuid(),
  texto         text not null,
  autor         text,
  status        text not null default 'aberta',
  resposta      text,
  criado_em     timestamptz not null default now(),
  respondido_em timestamptz,
  constraint painel_solic_status_ok check (status in
    ('aberta','em_producao','concluida','recusada'))
);

create table if not exists public.painel_eventos (
  id        bigserial primary key,
  post_id   uuid references public.painel_posts(id) on delete cascade,
  tipo      text not null,
  detalhe   text,
  autor     text,
  criado_em timestamptz not null default now()
);

alter table public.painel_config       enable row level security;
alter table public.painel_posts        enable row level security;
alter table public.painel_ajustes      enable row level security;
alter table public.painel_solicitacoes enable row level security;
alter table public.painel_eventos      enable row level security;
-- sem policies: acesso só pelas funções

revoke all on public.painel_config, public.painel_posts, public.painel_ajustes,
              public.painel_solicitacoes, public.painel_eventos
  from anon, authenticated;
