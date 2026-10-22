# Persistência e API do ArenaPlay

## Estado desta entrega

As páginas estáticas agora usam **modo real por padrão**. Sem backend, mostram estado vazio/indisponível e não criam receita, usuários, pontos, ranking ou saques locais. Para testar as telas, use explicitamente `?mode=demo`; todos os dados desse modo são inventados e ficam apenas em memória.

O cadastro não pede CPF no HTML. Sessão real deve ser criada e mantida pelo servidor com cookie `Secure; HttpOnly; SameSite=Lax`. O navegador não guarda token de sessão, CPF, chave PIX, saldo nem histórico em `localStorage`.

## Contrato esperado

Configure `<meta name="arena-api-base" content="/api">` antes de `api.js` se o prefixo mudar. O padrão é mesma origem em `/api`. O backend deve rejeitar CORS de origens não autorizadas, validar `Origin` e o cookie/header CSRF nas mutações, aplicar rate limiting e autorização por rota. Nunca confiar em valores de pontos, saldo, valor de saque, apelido ou papel administrativo recebidos do navegador.

| Rota | Acesso | Uso |
| --- | --- | --- |
| `GET /me` | sessão | perfil mínimo, pontos, saldo disponível |
| `POST /auth/register` | público com rate limit | cria conta e emite sessão |
| `POST /auth/logout` | sessão + CSRF | encerra sessão no servidor |
| `GET /ranking?limit=15` | público | `{items:[{userId,nickname,points}]}`, sem PII |
| `GET /admin/dashboard` | admin | totais agregados calculados no servidor |
| `GET /admin/withdrawals` | admin | fila sem chave PIX em claro |
| `GET /admin/transactions?limit=20` | admin | transações registradas pelo backend |
| `POST /admin/withdrawals/{id}/approve` | admin + CSRF | move para revisão/aprovação; não confirma pagamento |
| `POST /withdrawals` | sessão + CSRF | solicitação com chave idempotente; exige conta PIX verificada |

A chave PIX deve ser escolhida/resolvida no backend a partir de uma conta verificada. O frontend não deve enviar CPF/chave PIX nem autorizar pagamento. O endpoint administrativo precisa de RBAC, trilha de auditoria, dupla aprovação conforme política e integração idempotente com PSP antes de marcar `paid`.

## Banco

`schema.sql` oferece tabelas iniciais para usuários, contas PIX, eventos de pontuação, ledger imutável, saques e auditoria. Cifrar PII/PIX no backend com chave gerida por KMS; `email_lookup_hash` e `pix_key_fingerprint` devem ser HMAC com segredo, nunca hash simples. Conceder ao usuário do app apenas permissões necessárias; credenciais e segredos ficam no ambiente do servidor. Aplicar migrações em transação, backups cifrados e política de retenção/eliminação.

A view de ranking deriva pontos de eventos aceitos pelo servidor. Rodadas e respostas devem ser validadas no backend antes de inserir `score_events`; o jogo atual é explicitamente demo até essa validação estar pronta. Saldo disponível é calculado pelo ledger, com reserva atômica do valor do saque e chave idempotente. O esquema é uma base de implementação e ainda exige revisão operacional/LGPD antes de receber dados reais.
