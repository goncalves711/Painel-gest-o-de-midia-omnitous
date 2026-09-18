# Painel de acompanhamento de postagens
### iNova · Omni Tous

Duas telas sobre um banco. O cliente vê o calendário, aprova ou pede ajuste e
abre solicitação de pauta. Você produz, envia para aprovação e lê o que ele
respondeu — com data e hora de cada aceite.

```
acompanhamento.html   tela do cliente (aberta, sem senha)
agencia.html          sua tela (senha)
api/painel.js         servidor da sua tela
banco.sql             estrutura do banco, para backup ou migração
```

Antes de publicar as páginas, rode o `banco.sql` no SQL Editor do seu projeto
Supabase — ele cria tabelas, funções, permissões e o bucket de arte.

---

## Instalação

### 1. Suba os arquivos

No mesmo repositório do site (`omnitous-site`), mantendo a pasta `api`:

```
omnitous-site/
├── index.html          (site, já existe)
├── admin.html          (painel de textos, já existe)
├── acompanhamento.html ← novo
├── agencia.html        ← novo
└── api/
    ├── publicar.js     (já existe)
    ├── contato.js      (já existe)
    └── painel.js       ← novo
```

Lembre de entrar **dentro da pasta `api`** antes de subir o `painel.js`.

### 2. Pegue a chave de serviço do Supabase

No painel do Supabase, no seu projeto:
**Settings → API Keys → service_role** → revelar e copiar.

Essa chave dá acesso total ao banco. Ela vai **somente** para a variável de
ambiente do Vercel, nunca para um arquivo do repositório.

### 3. Variáveis no Vercel

Projeto → Settings → Environment Variables → Production:

| Chave | Valor |
|---|---|
| `SUPABASE_URL` | `https://dzmveizdmrqoqhznpeom.supabase.co` |
| `SUPABASE_SERVICE_KEY` | a chave `service_role` do passo 2 |
| `SENHA_PAINEL_POSTS` | a senha que **você** vai usar |

Depois: **Deployments → Redeploy.**

### 4. Defina o código do cliente

Rode no SQL Editor:

```sql
select public.painel_definir_codigo('o-codigo-que-voce-quiser');
```

Para trocar depois, sem SQL: abra `seudominio.com/agencia.html`, entre com a sua senha, clique em
**Código do cliente** e defina outro. Ele é guardado em hash — nem eu nem
você conseguimos ler depois, só redefinir.

### 5. Confira o código dentro do arquivo

No topo do `<script>` do `acompanhamento.html` existe uma linha:

```js
var CODIGO='XPFN-8734';
```

Ela precisa ser **igual** ao código que você definiu no banco no passo 4. É
esse par que faz a página conversar com o banco — o cliente nunca vê nem
digita isso.

### 6. Mande o link no grupo

```
omnitous.com.br/acompanhamento.html
```

Abre direto no calendário. Ninguém digita nada para ver.

O **nome é pedido na hora de agir** — aprovar, pedir ajuste ou solicitar
pauta. Como são três sócios, é assim que você sabe quem fez o quê. O nome
fica lembrado no navegador de cada um, e tem um link *trocar* caso duas
pessoas usem o mesmo aparelho.

## Como funciona no dia a dia

**Você:** cria o post como *rascunho*, escreve a legenda, sobe a arte e define
a data. Quando estiver pronto, **Enviar p/ aprovação** — só então ele aparece
para o cliente. Rascunho é invisível do lado dele.

**O cliente:** vê o calendário do mês, abre o post, lê a legenda, olha a arte
e escolhe *Aprovar* ou *Pedir ajuste*. No ajuste, o campo de texto é
obrigatório — não dá para pedir mudança sem dizer qual.

**Você, de novo:** a aba *Ajuste pedido* mostra em vermelho o que ele escreveu,
dentro do próprio card. Corrige, salva, reenvia. Ao aprovar, o ajuste anterior
é marcado como resolvido.

**Publicado:** depois de publicar de verdade na rede, marque como *publicado*.
O cliente vê o histórico e não consegue mais mexer.

**Cobrança sem cobrar:** posts em *aguardando* mostram "há X dias" no card.
Serve para você saber quando lembrar — e, pelo contrato, a aprovação é tácita
depois de 3 dias úteis.

---

## Segurança

**As tabelas estão fechadas.** RLS ligado e nenhuma policy: ninguém lê nem
escreve direto, nem com a chave pública. Todo acesso passa por funções que
exigem o código de acesso.

**A chave pública dentro do `cliente.html` é normal.** Ela é feita para ficar
visível no navegador. Sem o código de acesso ela não abre nada — testei:
código errado devolve erro, tabela direta devolve permissão negada.

**Uma falha que encontrei e corrigi durante a construção:** no Postgres toda
função nasce executável por `PUBLIC`, e o papel anônimo herda disso. Eu havia
revogado a função que redefine o código apenas do papel anônimo — o que não
fecha a porta. Qualquer pessoa com a chave pública poderia ter redefinido o
código do cliente. Revoguei de `PUBLIC` e confirmei por consulta: hoje só o
servidor executa.

**O que é aberto por escolha sua:** qualquer pessoa com o link vê o painel e
pode agir. O nome digitado é **atribuição, não autenticação** — o registro diz
"quem se identificou como Alan", não "o Alan comprovadamente".

Para o que esse painel guarda — calendário de posts e aprovação de arte — isso
é proporcional: o custo de um acesso indevido é baixo e o ganho de não ter
senha é alto. Vale só ter consciência de duas coisas:

- quem receber o link por encaminhamento também entra, inclusive fora da Omni Tous;
- o painel mostra os posts **antes** de publicados, então quem tem o link vê o
  que ainda não foi ao ar.

Se algum dia a aprovação precisar valer como aceite formal — para faturamento
ou discussão de escopo —, aí compensa migrar para login por e-mail, que
verifica quem é a pessoa. Hoje, o registro serve como histórico, não como prova.
Para um contrato com um interlocutor, é proporcional. Se a Omni Tous colocar
mais gente aprovando, vale migrar para login por e-mail — o nome de quem
aprovou passaria a ser verificado, não digitado.

---

## Limites

- **Arte até 3 MB.** É limite do Vercel, não do Supabase. Exporte em JPG.
- **PNG, JPG, WEBP e MP4.** Outros formatos são recusados.
- **500 MB de banco e 1 GB de arquivos** no plano gratuito do Supabase — anos
  de posts antes de encostar nisso.
- **Projeto do Supabase pausa com 7 dias sem uso** no plano gratuito. Como o
  cliente vai entrar toda semana, não deve acontecer; se acontecer, é um
  clique para reativar.
