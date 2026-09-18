-- PARTE 3 de 3 · pasta das artes
-- Se der erro de permissão aqui, crie pela interface:
--   Storage > New bucket > nome: painel-midias > marque Public bucket

-- bucket das artes
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('painel-midias','painel-midias', true, 10485760,
        array['image/png','image/jpeg','image/webp','video/mp4'])
on conflict (id) do nothing;
