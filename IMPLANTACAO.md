# 🚀 Pipeline de Implantação OpenClaw

Um sistema completo de implantação para OpenClaw em múltiplas plataformas.

## 📋 O Que Foi Criado

### ✅ Fluxo de Trabalho Automatizado (GitHub Actions)
- **Arquivo**: `.github/workflows/deploy.yml`
- **Recursos**:
  - ✓ Validação automática (build, testes, lint)
  - ✓ Implantação multi-plataforma (Fly.io, Render, Docker)
  - ✓ Verificações de saúde após deploy
  - ✓ Criação automática de releases no GitHub
  - ✓ Notificações de status

### ✅ Scripts de Implantação Manual
- **`scripts/deploy.sh`**: Script completo de implantação
  - Suporta múltiplas plataformas
  - Modo dry-run para testes
  - Validação de pré-requisitos
  
- **`scripts/rollback.sh`**: Reversão rápida
  - Volta para versões anteriores
  - Confirmação de segurança
  - Suporte a todas as plataformas

### ✅ Documentação Completa em Português
- **`docs/deployment/README.pt-BR.md`**: Guia completo
- **`docs/deployment/PIPELINE.pt-BR.md`**: Visão geral do pipeline

### ✅ Template de Configuração
- **`.env.deployment.example`**: Todas as variáveis de ambiente necessárias

## 🎯 Início Rápido

### Opção 1: Automatizado (Recomendado)

```bash
# 1. Configure os secrets no GitHub:
#    - FLY_API_TOKEN
#    - RENDER_API_KEY
#    - RENDER_SERVICE_ID

# 2. Crie e envie uma tag de versão
git tag v2026.2.4
git push --tags

# Pronto! A implantação inicia automaticamente
```

### Opção 2: Manual com Scripts

```bash
# 1. Instalar dependências
pnpm install

# 2. Copiar e configurar variáveis de ambiente
cp .env.deployment.example .env.deployment
# Edite o arquivo .env.deployment com suas credenciais

# 3. Carregar variáveis
source .env.deployment

# 4. Implantar (com teste primeiro)
bash scripts/deploy.sh --platform fly --dry-run

# 5. Implantar de verdade
bash scripts/deploy.sh --platform fly --environment production
```

## 🌐 Plataformas Suportadas

### 1. Fly.io ⭐ (Recomendado)
```bash
# Instalar CLI
curl -L https://fly.io/install.sh | sh

# Login
flyctl auth login

# Implantar
bash scripts/deploy.sh --platform fly
```

**Vantagens:**
- ✓ Armazenamento persistente
- ✓ SSL automático
- ✓ CDN global
- ✓ Fácil escalonamento

### 2. Render
```bash
# Configure no dashboard: render.com
# Obtenha sua API key

# Implantar
bash scripts/deploy.sh --platform render
```

**Vantagens:**
- ✓ Zero configuração
- ✓ Plano gratuito
- ✓ SSL incluído
- ✓ Interface simples

### 3. Docker / Auto-hospedado
```bash
# Build local
docker build -t openclaw:latest .

# Executar
docker run -p 18789:18789 \
  -e OPENCLAW_GATEWAY_TOKEN="seu-token" \
  openclaw:latest

# Ou usar Docker Compose
docker-compose up -d
```

**Vantagens:**
- ✓ Controle total
- ✓ Qualquer provedor
- ✓ Multi-arquitetura
- ✓ Desenvolvimento local

## ⚙️ Configuração

### Variáveis Obrigatórias

```bash
# Token de autenticação
OPENCLAW_GATEWAY_TOKEN="gere-um-token-seguro-aqui"

# Pelo menos um provedor de IA
CLAUDE_AI_SESSION_KEY="sua-chave-claude"
# OU
ANTHROPIC_API_KEY="sua-chave-anthropic"
# OU
OPENAI_API_KEY="sua-chave-openai"

# Plataforma escolhida
FLY_API_TOKEN="token-fly"        # Para Fly.io
# OU
RENDER_API_KEY="chave-render"    # Para Render
```

### Como Obter as Chaves

**Fly.io Token:**
```bash
flyctl auth login
flyctl auth token
```

**Render API Key:**
1. Acesse https://dashboard.render.com/account
2. Vá em "API Keys"
3. Crie uma nova chave

**Claude Session:**
1. Faça login em claude.ai
2. Execute: `openclaw login`
3. Siga as instruções

## 📖 Comandos Úteis

### Implantação

```bash
# Implantar em produção
bash scripts/deploy.sh --platform fly --environment production

# Implantar em staging
bash scripts/deploy.sh --platform fly --environment staging

# Teste sem executar (recomendado primeiro)
bash scripts/deploy.sh --platform fly --dry-run

# Implantar em todas as plataformas
bash scripts/deploy.sh --platform all

# Pular testes (use com cuidado)
bash scripts/deploy.sh --skip-tests
```

### Reversão

```bash
# Reverter para versão anterior
bash scripts/rollback.sh --platform fly --version 2026.2.3

# Reverter staging
bash scripts/rollback.sh --environment staging --version 2026.2.2
```

### Monitoramento

```bash
# Ver status (Fly.io)
flyctl status --app openclaw

# Ver logs
flyctl logs --app openclaw

# Verificar saúde
curl https://sua-app.fly.dev/health

# Docker logs
docker logs openclaw-container
```

## 🔄 Fluxo de Trabalho Recomendado

```bash
# 1️⃣ Desenvolver localmente
pnpm build
pnpm test
docker-compose up -d

# 2️⃣ Testar implantação
bash scripts/deploy.sh --platform fly --environment staging

# 3️⃣ Verificar staging
curl https://openclaw-staging.fly.dev/health
flyctl logs --app openclaw-staging

# 4️⃣ Implantar em produção
bash scripts/deploy.sh --platform fly --environment production

# 5️⃣ Monitorar
flyctl logs --app openclaw --follow

# 6️⃣ Se algo der errado, reverter
bash scripts/rollback.sh --platform fly --version VERSAO_ANTERIOR
```

## ❗ Solução de Problemas

### Erro: "Tests failed"
```bash
# Execute testes localmente
pnpm test

# Se precisar pular (não recomendado)
bash scripts/deploy.sh --skip-tests
```

### Erro: "Cannot connect to gateway"
```bash
# Verifique o bind do gateway
# Deve ser "lan" para acesso externo
export OPENCLAW_GATEWAY_BIND="lan"

# Verifique o token
echo $OPENCLAW_GATEWAY_TOKEN

# Veja os logs
flyctl logs --app openclaw
```

### Erro: "Out of memory"
```bash
# Aumente a memória do Node.js
export NODE_OPTIONS="--max-old-space-size=2048"

# Ou atualize o tamanho da VM em fly.toml
```

### Erro: "Authentication failed"
```bash
# Verifique as credenciais do provedor de IA
# Atualize as chaves de sessão

# Claude
openclaw login

# Verifique variáveis de ambiente
env | grep -E "CLAUDE|OPENAI|ANTHROPIC"
```

## 📚 Documentação Completa

- 📖 [Guia Completo de Implantação](docs/deployment/README.pt-BR.md)
- 🔧 [Visão Geral do Pipeline](docs/deployment/PIPELINE.pt-BR.md)
- ⚙️ [Configuração](docs/configuration.md)
- 🔒 [Segurança](docs/gateway/security.md)

## 🎉 Recursos Principais

- ✅ **Multi-plataforma**: Fly.io, Render, Docker
- ✅ **Automatizado**: GitHub Actions integrado
- ✅ **Seguro**: Validação e verificações de saúde
- ✅ **Reversível**: Rollback rápido e fácil
- ✅ **Monitorado**: Logs e métricas integradas
- ✅ **Documentado**: Guias completos em português
- ✅ **Testado**: Validação antes de cada deploy

## 💡 Dicas

1. **Sempre use staging primeiro** antes de produção
2. **Execute dry-run** antes da implantação real
3. **Monitore os logs** após cada deploy
4. **Mantenha backup** das configurações
5. **Use tokens seguros** e nunca os comite no git
6. **Documente mudanças** no CHANGELOG.md
7. **Teste localmente** com Docker Compose
8. **Configure alertas** para problemas em produção

## 🆘 Precisa de Ajuda?

- 📝 Leia a [documentação completa](docs/deployment/README.pt-BR.md)
- 🐛 Reporte problemas no [GitHub Issues](https://github.com/openclaw/openclaw/issues)
- 📋 Execute `openclaw doctor` para diagnóstico
- 📊 Verifique os logs da plataforma

---

**Pronto para implantar?** Comece com o [Guia de Implantação](docs/deployment/README.pt-BR.md)!
