/* ═══════════════════════════════════════════════════════════════
   Painel de postagens — lado da agência
   Usa a chave de serviço do Supabase, que nunca sai do servidor.

   Variáveis de ambiente (Vercel):
     SUPABASE_URL            https://xxxx.supabase.co
     SUPABASE_SERVICE_KEY    chave service_role (secreta)
     SENHA_PAINEL_POSTS      senha de acesso da agência
   ═══════════════════════════════════════════════════════════════ */

const BUCKET = 'painel-midias';
const TIPOS = { 'image/png':'png', 'image/jpeg':'jpg', 'image/webp':'webp', 'video/mp4':'mp4' };
const LIMITE_BYTES = 4 * 1024 * 1024;

function senhaConfere(a, b) {
  if (typeof a !== 'string' || typeof b !== 'string' || a.length !== b.length) return false;
  let d = 0;
  for (let i = 0; i < a.length; i++) d |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return d === 0;
}

async function sb(caminho, opcoes = {}) {
  const r = await fetch(`${process.env.SUPABASE_URL}${caminho}`, {
    ...opcoes,
    headers: {
      apikey: process.env.SUPABASE_SERVICE_KEY,
      Authorization: `Bearer ${process.env.SUPABASE_SERVICE_KEY}`,
      'Content-Type': 'application/json',
      ...(opcoes.headers || {})
    }
  });
  const txt = await r.text();
  let corpo = null;
  try { corpo = txt ? JSON.parse(txt) : null; } catch { corpo = txt; }
  if (!r.ok) throw new Error(`supabase ${r.status}: ${typeof corpo === 'string' ? corpo : JSON.stringify(corpo)}`);
  return corpo;
}

const CAMPOS = ['titulo','legenda','midia_url','rede','data_publicacao','status'];
function limpaPost(p = {}) {
  const o = {};
  for (const c of CAMPOS) if (p[c] !== undefined) o[c] = p[c] === '' ? null : p[c];
  if (o.titulo != null) o.titulo = String(o.titulo).slice(0, 200);
  if (o.legenda != null) o.legenda = String(o.legenda).slice(0, 4000); else o.legenda = o.legenda;
  if (o.status && !['rascunho','aguardando','aprovado','ajuste','publicado'].includes(o.status))
    throw new Error('status_invalido');
  if (o.rede && !['linkedin','instagram','facebook','ambas'].includes(o.rede))
    throw new Error('rede_invalida');
  o.atualizado_em = new Date().toISOString();
  return o;
}

export default async function handler(req, res) {
  if (req.method !== 'POST') return res.status(405).json({ erro: 'Método não permitido.' });

  for (const v of ['SUPABASE_URL','SUPABASE_SERVICE_KEY','SENHA_PAINEL_POSTS'])
    if (!process.env[v]) return res.status(500).json({ erro: `Falta configurar ${v} no Vercel.` });

  const { senha, acao } = req.body || {};
  if (!senhaConfere(senha, process.env.SENHA_PAINEL_POSTS)) {
    await new Promise(r => setTimeout(r, 700));
    return res.status(401).json({ erro: 'Senha incorreta.' });
  }

  try {
    switch (acao) {

      /* ── tudo que a agência vê ── */
      case 'listar': {
        const posts = await sb('/rest/v1/painel_posts?select=*&order=data_publicacao.asc.nullslast,criado_em.asc');
        const ajustes = await sb('/rest/v1/painel_ajustes?select=*&order=criado_em.desc');
        const solicitacoes = await sb('/rest/v1/painel_solicitacoes?select=*&order=criado_em.desc');
        for (const p of posts) p.ajustes = ajustes.filter(a => a.post_id === p.id);
        return res.status(200).json({ ok: true, posts, solicitacoes });
      }

      /* ── criar ou atualizar post ── */
      case 'salvar': {
        const { id, post } = req.body;
        const dados = limpaPost(post);
        if (!dados.titulo && !id) return res.status(400).json({ erro: 'Título é obrigatório.' });
        if (id) {
          const r = await sb(`/rest/v1/painel_posts?id=eq.${encodeURIComponent(id)}`, {
            method: 'PATCH', headers: { Prefer: 'return=representation' },
            body: JSON.stringify(dados) });
          return res.status(200).json({ ok: true, post: r && r[0] });
        }
        const r = await sb('/rest/v1/painel_posts', {
          method: 'POST', headers: { Prefer: 'return=representation' },
          body: JSON.stringify({ legenda: '', ...dados }) });
        return res.status(200).json({ ok: true, post: r && r[0] });
      }

      /* ── excluir post ── */
      case 'excluir': {
        const { id } = req.body;
        if (!id) return res.status(400).json({ erro: 'Sem id.' });
        await sb(`/rest/v1/painel_posts?id=eq.${encodeURIComponent(id)}`, { method: 'DELETE' });
        return res.status(200).json({ ok: true });
      }

      /* ── subir a arte ── */
      case 'upload': {
        const { nome, tipo, base64 } = req.body;
        const ext = TIPOS[tipo];
        if (!ext) return res.status(400).json({ erro: 'Formato não aceito. Use PNG, JPG, WEBP ou MP4.' });
        const bin = Buffer.from(String(base64 || ''), 'base64');
        if (!bin.length) return res.status(400).json({ erro: 'Arquivo vazio.' });
        if (bin.length > LIMITE_BYTES) return res.status(400).json({ erro: 'Arquivo grande demais. Use até 3 MB.' });
        const seguro = String(nome || 'arte').toLowerCase()
          .normalize('NFD').replace(/[̀-ͯ]/g, '')
          .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '').slice(0, 50) || 'arte';
        const caminho = `${Date.now()}-${seguro}.${ext}`;
        const r = await fetch(`${process.env.SUPABASE_URL}/storage/v1/object/${BUCKET}/${caminho}`, {
          method: 'POST',
          headers: {
            apikey: process.env.SUPABASE_SERVICE_KEY,
            Authorization: `Bearer ${process.env.SUPABASE_SERVICE_KEY}`,
            'Content-Type': tipo,
            'x-upsert': 'true'
          },
          body: bin
        });
        if (!r.ok) throw new Error(`storage ${r.status}: ${await r.text()}`);
        return res.status(200).json({ ok: true,
          url: `${process.env.SUPABASE_URL}/storage/v1/object/public/${BUCKET}/${caminho}` });
      }

      /* ── responder solicitação de pauta ── */
      case 'responder': {
        const { id, resposta, status } = req.body;
        if (!id) return res.status(400).json({ erro: 'Sem id.' });
        const corpo = { respondido_em: new Date().toISOString() };
        if (typeof resposta === 'string') corpo.resposta = resposta.slice(0, 2000);
        if (status) {
          if (!['aberta','em_producao','concluida','recusada'].includes(status))
            return res.status(400).json({ erro: 'Status inválido.' });
          corpo.status = status;
        }
        await sb(`/rest/v1/painel_solicitacoes?id=eq.${encodeURIComponent(id)}`, {
          method: 'PATCH', body: JSON.stringify(corpo) });
        return res.status(200).json({ ok: true });
      }

      /* ── trocar o código do cliente ── */
      case 'codigo': {
        const { codigo } = req.body;
        if (!codigo || String(codigo).length < 6)
          return res.status(400).json({ erro: 'Use um código com 6 caracteres ou mais.' });
        await sb('/rest/v1/rpc/painel_definir_codigo', {
          method: 'POST', body: JSON.stringify({ p_codigo: String(codigo) }) });
        return res.status(200).json({ ok: true });
      }

      default:
        return res.status(400).json({ erro: 'Ação desconhecida.' });
    }
  } catch (e) {
    console.error(e);
    const m = String(e.message || e);
    if (/status_invalido|rede_invalida/.test(m)) return res.status(400).json({ erro: 'Dado inválido.' });
    return res.status(500).json({ erro: 'Erro no servidor. Tente de novo.' });
  }
}
