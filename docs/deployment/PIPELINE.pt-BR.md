# Pipeline de Implantação

Um pipeline abrangente de implantação para OpenClaw em várias plataformas.

## Início Rápido

### Usando GitHub Actions (Recomendado)

1. Configure os secrets no seu repositório GitHub:
   - `FLY_API_TOKEN` - Para implantações Fly.io
   - `RENDER_API_KEY` e `RENDER_SERVICE_ID` - Para implantações Render
   - `GITHUB_TOKEN` - Disponível automaticamente, usado para registro Docker

2. Acione a implantação:
   - **Automatizado**: Envie uma tag de versão (`git tag v2026.2.4 && git push --tags`)
   - **Manual**: Vá em Actions → Deploy → Run workflow

### Usando Scripts de Implantação

```bash
# Instalar dependências
pnpm install

# Implantar no Fly.io produção
bash scripts/deploy.sh --platform fly --environment production

# Implantar em todas as plataformas (staging)
bash scripts/deploy.sh --platform all --environment staging

# Teste sem executar para testar configuração
bash scripts/deploy.sh --platform fly --dry-run
```

## Arquivos Criados

### Fluxo de Trabalho GitHub Actions
- `.github/workflows/deploy.yml` - Pipeline automatizado de implantação com:
  - Validação pré-implantação (build, teste, lint)
  - Implantação multi-plataforma (Fly.io, Render, Docker)
  - Verificações de saúde e monitoramento
  - Criação automática de release no GitHub
  - Suporte a reversão

### Scripts de Implantação
- `scripts/deploy.sh` - Script manual de implantação com suporte para:
  - Múltiplas plataformas (Fly.io, Render, Docker)
  - Seleção de ambiente (staging, production)
  - Modo dry-run (teste)
  - Opções para pular testes/build
  
- `scripts/rollback.sh` - Reversão rápida para versões anteriores:
  - Procedimentos de reversão específicos por plataforma
  - Gerenciamento de histórico de versões
  - Confirmações de segurança

### Documentação
- `docs/deployment/README.pt-BR.md` - Guia abrangente de implantação cobrindo:
  - Configuração de plataforma e pré-requisitos
  - Configuração de ambiente
  - Procedimentos de implantação
  - Estratégias de reversão
  - Solução de problemas
  - Melhores práticas

### Templates de Configuração
- `.env.deployment.example` - Template completo de variáveis de ambiente com:
  - Credenciais específicas por plataforma
  - Configuração do gateway
  - Configurações de provedor de IA
  - Configuração de armazenamento
  - Configurações de segurança

## Plataformas Suportadas

### 1. Fly.io (Recomendado para Produção)
- Armazenamento persistente com volumes montados
- Certificados SSL automáticos
- CDN global e computação de borda
- Escalonamento simples

**Configuração:**
```bash
# Instalar flyctl
curl -L https://fly.io/install.sh | sh

# Fazer login e obter token
flyctl auth login
flyctl auth token
```

### 2. Render
- Implantações zero-config
- SSL automático e proteção DDoS
- Banco de dados e armazenamento integrados
- Plano gratuito disponível

**Configuração:**
1. Criar conta em https://render.com
2. Obter chave API das configurações da conta
3. Criar serviço usando `render.yaml`

### 3. Docker / Plataformas de Container
- Funciona com qualquer plataforma compatível com Docker
- Suporta Docker Compose para desenvolvimento local
- Suporte multi-arquitetura (amd64, arm64)
- Integração com GitHub Container Registry

**Configuração:**
```bash
# Construir e executar localmente
docker build -t openclaw:latest .
docker run -p 18789:18789 openclaw:latest

# Ou usar Docker Compose
docker-compose up -d
```

## Fluxo de Trabalho de Implantação

### Automatizado (CI/CD)

```
Tag/Acionamento → Build & Teste → Deploy Fly.io
                                 → Deploy Render
                                 → Build Docker
                                 → Verificação de Saúde
                                 → Criar Release
```

### Manual

```bash
# 1. Testar localmente
pnpm build && pnpm test

# 2. Implantar com dry-run
bash scripts/deploy.sh --platform fly --dry-run

# 3. Implantar em staging
bash scripts/deploy.sh --platform fly --environment staging

# 4. Verificar staging
curl https://openclaw-staging.fly.dev/health

# 5. Implantar em produção
bash scripts/deploy.sh --platform fly --environment production

# 6. Monitorar
flyctl logs --app openclaw
```

## Configuração de Ambiente

Copie e configure o template de ambiente:

```bash
cp .env.deployment.example .env.deployment

# Editar e preencher suas credenciais
nano .env.deployment

# Carregar antes de implantar
source .env.deployment
```

### Variáveis Obrigatórias

- `OPENCLAW_GATEWAY_TOKEN` - Token de autenticação
- `FLY_API_TOKEN` ou `RENDER_API_KEY` - Credenciais da plataforma
- Credenciais de provedor de IA (pelo menos um):
  - `CLAUDE_AI_SESSION_KEY`
  - `ANTHROPIC_API_KEY`
  - `OPENAI_API_KEY`

## Procedimentos de Reversão

### Reversão Rápida

```bash
# Reverter para versão anterior
bash scripts/rollback.sh --platform fly --version 2026.2.3

# Reverter staging
bash scripts/rollback.sh --environment staging --version 2026.2.2
```

### Específico por Plataforma

**Fly.io:**
```bash
flyctl releases --app openclaw
flyctl releases rollback NUMERO_VERSAO --app openclaw
```

**Render:**
Use o painel para reimplantar uma versão anterior.

**Docker:**
```bash
docker pull ghcr.io/openclaw/openclaw:2026.2.3
docker tag ghcr.io/openclaw/openclaw:2026.2.3 ghcr.io/openclaw/openclaw:latest
```

## Monitoramento & Verificações de Saúde

### Endpoint de Saúde Integrado

```bash
curl https://sua-aplicacao.fly.dev/health
```

### Monitoramento por Plataforma

**Fly.io:**
```bash
flyctl status --app openclaw
flyctl logs --app openclaw
flyctl vm status --app openclaw
```

**Render:**
Verifique o painel em https://dashboard.render.com

**Docker:**
```bash
docker ps
docker logs openclaw
docker stats openclaw
```

## Melhores Práticas

1. **Sempre teste em staging primeiro**
2. **Use versionamento semântico** (`v2026.2.4`)
3. **Mantenha secrets seguros** (nunca comite)
4. **Monitore logs** após implantação
5. **Tenha plano de reversão pronto**
6. **Documente mudanças** no CHANGELOG.md
7. **Execute verificações de saúde** após implantação
8. **Use dry-run** para validação
9. **Automatize via CI/CD** quando possível
10. **Mantenha variáveis de ambiente atualizadas**

## Solução de Problemas

### Falhas de Build
```bash
# Limpar e reconstruir
rm -rf dist node_modules
pnpm install --frozen-lockfile
pnpm build
```

### Problemas de Conexão
- Verifique a configuração `OPENCLAW_GATEWAY_BIND`
- Verifique regras de firewall/segurança
- Garanta que o token está definido corretamente

### Problemas de Memória
```bash
# Aumentar memória do Node.js
export NODE_OPTIONS="--max-old-space-size=2048"
```

### Erros de Autenticação
- Verifique se as chaves de sessão estão atuais
- Verifique variáveis de ambiente
- Atualize credenciais expiradas

## Próximos Passos

- Revise o [Guia de Implantação](docs/deployment/README.pt-BR.md) para instruções detalhadas
- Verifique a [Lista de Verificação de Release](docs/reference/RELEASING.md) antes de releases
- Configure monitoramento e alertas
- Configure estratégias de backup
- Planeje procedimentos de recuperação de desastres

## Suporte

- Documentação: `docs/deployment/`
- Issues: https://github.com/openclaw/openclaw/issues
- Logs: Verifique logging específico da plataforma
