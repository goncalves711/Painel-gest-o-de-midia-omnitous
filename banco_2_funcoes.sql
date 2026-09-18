-- PARTE 2 de 3 · funções e permissões de execução
-- Rode depois da parte 1.

-- ═══════════════════════════════════════════════════════════
-- Funções: única porta de entrada do cliente
-- ═══════════════════════════════════════════════════════════

create or replace function public.painel_codigo_ok(p_codigo text)
returns boolean language plpgsql security definer
set search_path = public, extensions as $$
declare h text;
begin
  if p_codigo is null or length(p_codigo) < 4 then return false; end if;
  select valor into h from public.painel_config where chave = 'codigo_cliente';
  if h is null then return false; end if;
  return extensions.crypt(p_codigo, h) = h;
end $$;

create or replace function public.painel_definir_codigo(p_codigo text)
returns void language plpgsql security definer
set search_path = public, extensions as $$
begin
  insert into public.painel_config(chave, valor)
  values ('codigo_cliente', extensions.crypt(p_codigo, extensions.gen_salt('bf', 10)))
  on conflict (chave) do update
    set valor = extensions.crypt(p_codigo, extensions.gen_salt('bf', 10)),
        atualizado_em = now();
end $$;

create or replace function public.painel_listar(p_codigo text)
returns json language plpgsql security definer set search_path = public as $$
begin
  if not public.painel_codigo_ok(p_codigo) then raise exception 'codigo_invalido'; end if;
  return json_build_object(
    'posts', coalesce((
      select json_agg(to_jsonb(x) - 'ord' order by x.ord nulls last)
      from (
        select p.id, p.titulo, p.legenda, p.midia_url, p.rede,
               p.data_publicacao, p.status, p.aprovado_em, p.aprovado_por,
               coalesce(p.data_publicacao::timestamptz, p.criado_em) as ord,
               coalesce((
                 select json_agg(json_build_object('texto', a.texto, 'autor', a.autor,
                          'criado_em', a.criado_em, 'resolvido_em', a.resolvido_em)
                        order by a.criado_em desc)
                 from public.painel_ajustes a where a.post_id = p.id
               ), '[]'::json) as ajustes
        from public.painel_posts p where p.status <> 'rascunho'
      ) x), '[]'::json),
    'solicitacoes', coalesce((
      select json_agg(json_build_object('id', s.id, 'texto', s.texto, 'status', s.status,
               'resposta', s.resposta, 'criado_em', s.criado_em) order by s.criado_em desc)
      from public.painel_solicitacoes s), '[]'::json));
end $$;

create or replace function public.painel_aprovar(p_codigo text, p_post uuid, p_autor text)
returns json language plpgsql security definer set search_path = public as $$
declare st text;
begin
  if not public.painel_codigo_ok(p_codigo) then raise exception 'codigo_invalido'; end if;
  select status into st from public.painel_posts where id = p_post;
  if st is null then raise exception 'post_inexistente'; end if;
  if st = 'publicado' then raise exception 'post_ja_publicado'; end if;
  update public.painel_posts set status='aprovado', aprovado_em=now(),
         aprovado_por=nullif(trim(coalesce(p_autor,'')),''), atualizado_em=now()
   where id = p_post;
  update public.painel_ajustes set resolvido_em=now()
   where post_id = p_post and resolvido_em is null;
  insert into public.painel_eventos(post_id, tipo, autor)
  values (p_post,'aprovado',nullif(trim(coalesce(p_autor,'')),''));
  return json_build_object('ok', true);
end $$;

create or replace function public.painel_pedir_ajuste(
  p_codigo text, p_post uuid, p_texto text, p_autor text)
returns json language plpgsql security definer set search_path = public as $$
begin
  if not public.painel_codigo_ok(p_codigo) then raise exception 'codigo_invalido'; end if;
  if length(trim(coalesce(p_texto,''))) < 5 then raise exception 'texto_curto'; end if;
  if length(p_texto) > 2000 then raise exception 'texto_longo'; end if;
  if not exists (select 1 from public.painel_posts where id = p_post) then
    raise exception 'post_inexistente'; end if;
  insert into public.painel_ajustes(post_id, texto, autor)
  values (p_post, trim(p_texto), nullif(trim(coalesce(p_autor,'')),''));
  update public.painel_posts set status='ajuste', aprovado_em=null,
         aprovado_por=null, atualizado_em=now() where id = p_post;
  insert into public.painel_eventos(post_id, tipo, detalhe, autor)
  values (p_post,'ajuste_pedido',left(trim(p_texto),200),nullif(trim(coalesce(p_autor,'')),''));
  return json_build_object('ok', true);
end $$;

create or replace function public.painel_abrir_solicitacao(
  p_codigo text, p_texto text, p_autor text)
returns json language plpgsql security definer set search_path = public as $$
begin
  if not public.painel_codigo_ok(p_codigo) then raise exception 'codigo_invalido'; end if;
  if length(trim(coalesce(p_texto,''))) < 10 then raise exception 'texto_curto'; end if;
  if length(p_texto) > 2000 then raise exception 'texto_longo'; end if;
  if (select count(*) from public.painel_solicitacoes
       where criado_em > now() - interval '1 hour') >= 10 then
    raise exception 'muitas_solicitacoes'; end if;
  insert into public.painel_solicitacoes(texto, autor)
  values (trim(p_texto), nullif(trim(coalesce(p_autor,'')),''));
  insert into public.painel_eventos(tipo, detalhe, autor)
  values ('solicitacao',left(trim(p_texto),200),nullif(trim(coalesce(p_autor,'')),''));
  return json_build_object('ok', true);
end $$;

-- ── permissões: no Postgres toda função nasce aberta a PUBLIC ──
revoke execute on function public.painel_definir_codigo(text) from public, anon, authenticated;
revoke execute on function public.painel_codigo_ok(text)      from public, anon, authenticated;
revoke execute on function public.painel_listar(text)                         from public;
revoke execute on function public.painel_aprovar(text, uuid, text)            from public;
revoke execute on function public.painel_pedir_ajuste(text, uuid, text, text) from public;
revoke execute on function public.painel_abrir_solicitacao(text, text, text)  from public;

grant execute on function public.painel_listar(text)                         to anon;
grant execute on function public.painel_aprovar(text, uuid, text)            to anon;
grant execute on function public.painel_pedir_ajuste(text, uuid, text, text) to anon;
grant execute on function public.painel_abrir_solicitacao(text, text, text)  to anon;
grant execute on function public.painel_definir_codigo(text)                 to service_role;

-- por último: defina o código do cliente
-- select public.painel_definir_codigo('troque-este-codigo');
