---
summary: "Guia de implantação do OpenClaw em várias plataformas"
read_when:
  - Implantando OpenClaw em produção
  - Configurando pipelines de CI/CD
  - Revertendo implantações
---

# Guia de Implantação

O OpenClaw suporta implantação em várias plataformas com pipelines automatizados de CI/CD e scripts de implantação manual.

## Índice

- [Plataformas Suportadas](#plataformas-suportadas)
- [Pré-requisitos](#pré-requisitos)
- [Implantação Automatizada (CI/CD)](#implantação-automatizada-cicd)
- [Implantação Manual](#implantação-manual)
- [Configuração de Ambiente](#configuração-de-ambiente)
- [Procedimentos de Reversão](#procedimentos-de-reversão)
- [Verificações de Saúde](#verificações-de-saúde)
- [Solução de Problemas](#solução-de-problemas)

## Plataformas Suportadas

O OpenClaw pode ser implantado em:

1. **Fly.io** - Recomendado para produção com armazenamento persistente
2. **Render** - Implantação simples com escalonamento automático
3. **Docker** - Auto-hospedado ou plataformas de container personalizadas
4. **Docker Compose** - Desenvolvimento local e implantações auto-hospedadas

## Pré-requisitos

### Requisitos Gerais

- Node.js 22+ (para build)
- pnpm 10.23.0+ (via corepack)
- Git (para controle de versão)

### Requisitos Específicos por Plataforma

#### Fly.io
```bash
# Instalar flyctl
curl -L https://fly.io/install.sh | sh

# Fazer login
flyctl auth login

# Definir token da API (para CI/CD)
export FLY_API_TOKEN="seu-token"
```

#### Render
- Conta Render com acesso à API
- Serviço criado via render.yaml ou painel
- Chave API das configurações da conta

```bash
export RENDER_API_KEY="sua-chave-api"
export RENDER_SERVICE_ID="seu-id-servico"
```

#### Docker
```bash
# Garantir que o Docker está instalado
docker --version

# Fazer login no registro (exemplo GitHub Container Registry)
echo $GITHUB_TOKEN | docker login ghcr.io -u USUARIO --password-stdin
```

## Implantação Automatizada (CI/CD)

### Fluxo de Trabalho GitHub Actions

O projeto inclui um fluxo de trabalho abrangente de implantação em `.github/workflows/deploy.yml`.

#### Acionar Implantação

**Acionamento Manual:**
```bash
# Via interface do GitHub: Actions → Deploy → Run workflow
# Selecione ambiente e plataforma
```

**Implantação baseada em Tag:**
```bash
# Criar e enviar uma tag de versão
git tag v2026.2.4
git push origin v2026.2.4

# Aciona automaticamente implantação em todas as plataformas
```

#### Recursos do Fluxo de Trabalho

- Validação pré-implantação (build, teste, lint)
- Implantação multi-plataforma (Fly.io, Render, Docker)
- Verificações de saúde após implantação
- Criação automática de release no GitHub
- Notificações de status de implantação

### Variáveis de Ambiente para CI/CD

Configure estes secrets nas configurações do seu repositório GitHub:

```yaml
# Fly.io
FLY_API_TOKEN: "seu-token-api-fly"

# Render
RENDER_API_KEY: "sua-chave-api-render"
RENDER_SERVICE_ID: "seu-id-servico"

# Opcional: Registro Docker personalizado
DOCKER_REGISTRY: "ghcr.io"
DOCKER_IMAGE_NAME: "openclaw/openclaw"
```

## Implantação Manual

### Usando o Script de Implantação

```bash
# Implantar no Fly.io produção
bash scripts/deploy.sh --platform fly --environment production

# Implantar em todas as plataformas em staging
bash scripts/deploy.sh --platform all --environment staging

# Teste de implantação sem executar
bash scripts/deploy.sh --platform render --dry-run

# Pular testes (não recomendado para produção)
bash scripts/deploy.sh --platform fly --skip-tests
```

### Opções do Script

```
OPÇÕES:
  -e, --environment ENV    Ambiente de implantação (staging|production)
  -p, --platform PLATFORM  Plataforma destino (fly|render|docker|all)
  -d, --dry-run           Executar sem implantação real
  -s, --skip-tests        Pular execução de testes
  -b, --skip-build        Pular etapa de build
  -h, --help              Mostrar mensagem de ajuda
```

### Implantação Específica por Plataforma

#### Fly.io

```bash
# Implantar em produção
flyctl deploy --config fly.toml --app openclaw

# Implantar em staging
flyctl deploy --config fly.toml --app openclaw-staging

# Verificar status
flyctl status --app openclaw

# Ver logs
flyctl logs --app openclaw
```

#### Render

```bash
# Acionar implantação via API
curl -X POST "https://api.render.com/v1/services/$RENDER_SERVICE_ID/deploys" \
  -H "Authorization: Bearer $RENDER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"clearCache": false}'

# Ou use o painel em https://dashboard.render.com
```

#### Docker

```bash
# Construir imagem
docker build -t openclaw:latest .

# Marcar para registro
docker tag openclaw:latest ghcr.io/openclaw/openclaw:2026.2.4

# Enviar para registro
docker push ghcr.io/openclaw/openclaw:2026.2.4

# Executar localmente
docker run -p 18789:18789 \
  -e OPENCLAW_GATEWAY_TOKEN="seu-token" \
  -v ~/.openclaw:/home/node/.openclaw \
  openclaw:latest
```

#### Docker Compose

```bash
# Definir variáveis de ambiente
export OPENCLAW_GATEWAY_TOKEN="seu-token"
export CLAUDE_AI_SESSION_KEY="sua-chave-sessao"
export OPENCLAW_CONFIG_DIR="${HOME}/.openclaw"
export OPENCLAW_WORKSPACE_DIR="${HOME}/.openclaw/workspace"

# Iniciar serviços
docker-compose up -d

# Ver logs
docker-compose logs -f

# Parar serviços
docker-compose down
```

## Configuração de Ambiente

### Variáveis de Ambiente Obrigatórias

```bash
# Autenticação
OPENCLAW_GATEWAY_TOKEN="seu-token-seguro"

# Provedor de IA (escolha um ou mais)
CLAUDE_AI_SESSION_KEY="sua-sessao-claude"
CLAUDE_WEB_SESSION_KEY="sua-sessao-web-claude"
CLAUDE_WEB_COOKIE="seu-cookie-claude"
OPENAI_API_KEY="sua-chave-openai"
ANTHROPIC_API_KEY="sua-chave-anthropic"

# Configuração do Gateway
OPENCLAW_GATEWAY_BIND="lan"  # ou "loopback" para apenas local
OPENCLAW_GATEWAY_PORT="18789"
```

### Configuração Opcional

```bash
# Armazenamento
OPENCLAW_STATE_DIR="/data/.openclaw"
OPENCLAW_WORKSPACE_DIR="/data/workspace"

# Opções Node.js
NODE_ENV="production"
NODE_OPTIONS="--max-old-space-size=1536"

# Específico da plataforma
OPENCLAW_PREFER_PNPM="1"  # Usar pnpm para builds
```

### Arquivos de Configuração por Plataforma

#### Fly.io (`fly.toml`)
```toml
app = "openclaw"
primary_region = "iad"

[env]
NODE_ENV = "production"
OPENCLAW_STATE_DIR = "/data"

[mounts]
source = "openclaw_data"
destination = "/data"

[[vm]]
size = "shared-cpu-2x"
memory = "2048mb"
```

#### Render (`render.yaml`)
```yaml
services:
  - type: web
    name: openclaw
    runtime: docker
    plan: starter
    envVars:
      - key: PORT
        value: "8080"
      - key: OPENCLAW_GATEWAY_TOKEN
        generateValue: true
    disk:
      name: openclaw-data
      mountPath: /data
      sizeGB: 1
```

## Procedimentos de Reversão

### Usando o Script de Reversão

```bash
# Reverter Fly.io para versão específica
bash scripts/rollback.sh --platform fly --version 2026.2.3

# Reverter ambiente staging
bash scripts/rollback.sh --environment staging --version 2026.2.2

# Reverter implantação Docker
bash scripts/rollback.sh --platform docker --version 2026.2.1
```

### Reversão Manual

#### Fly.io
```bash
# Listar releases recentes
flyctl releases --app openclaw

# Reverter para versão específica
flyctl releases rollback NUMERO_VERSAO --app openclaw
```

#### Render
```bash
# Via painel: Selecione implantação anterior e clique em "Redeploy"
# Ou use API para acionar redeploy de versão específica
```

#### Docker
```bash
# Baixar versão anterior
docker pull ghcr.io/openclaw/openclaw:2026.2.3

# Re-marcar como latest
docker tag ghcr.io/openclaw/openclaw:2026.2.3 ghcr.io/openclaw/openclaw:latest

# Enviar tag latest atualizada
docker push ghcr.io/openclaw/openclaw:latest
```

## Verificações de Saúde

### Endpoint de Saúde Integrado

O OpenClaw expõe um endpoint de verificação de saúde em `/health` (quando disponível).

```bash
# Verificar saúde
curl https://sua-url-implantacao.fly.dev/health

# Resposta esperada: 200 OK
```

### Verificações de Saúde por Plataforma

#### Fly.io
```bash
# Verificar status da aplicação
flyctl status --app openclaw

# Ver logs recentes
flyctl logs --app openclaw --limit 100

# Verificar métricas da VM
flyctl vm status --app openclaw
```

#### Render
```bash
# Verificar via API
curl "https://api.render.com/v1/services/$RENDER_SERVICE_ID" \
  -H "Authorization: Bearer $RENDER_API_KEY"

# Ou use o painel: https://dashboard.render.com
```

#### Docker
```bash
# Verificar status do container
docker ps | grep openclaw

# Ver logs
docker logs openclaw-container

# Executar verificação de saúde dentro do container
docker exec openclaw-container node dist/index.js gateway --help
```

## Solução de Problemas

### Problemas Comuns

#### Falhas de Build

**Problema:** Build falha durante implantação

**Solução:**
```bash
# Limpar build localmente
rm -rf dist node_modules
pnpm install --frozen-lockfile
pnpm build

# Verificar erros
pnpm lint
pnpm test
```

#### Problemas de Conexão

**Problema:** Não é possível conectar ao gateway após implantação

**Solução:**
1. Verificar se gateway está vinculado à interface correta (`lan` vs `loopback`)
2. Verificar regras de firewall/grupo de segurança
3. Garantir que `OPENCLAW_GATEWAY_TOKEN` está definido corretamente
4. Verificar logs para erros de inicialização

#### Problemas de Memória

**Problema:** Container/VM fica sem memória

**Solução:**
```bash
# Aumentar limite de memória do Node.js
export NODE_OPTIONS="--max-old-space-size=2048"

# Ou atualizar configuração da plataforma (fly.toml, render.yaml)
# para usar tamanho de instância maior
```

#### Erros de Sessão/Autenticação

**Problema:** Não é possível autenticar com provedores de IA

**Solução:**
1. Verificar se as chaves de sessão estão atuais e válidas
2. Verificar se variáveis de ambiente estão definidas corretamente
3. Revisar logs para erros de autenticação
4. Atualizar chaves de sessão se expiradas

### Obtendo Ajuda

- Verifique os logs primeiro: `flyctl logs`, `docker logs`, ou painel Render
- Revise o [guia de solução de problemas](../gateway/troubleshooting.md)
- Execute `openclaw doctor` para diagnóstico
- Verifique [GitHub Issues](https://github.com/openclaw/openclaw/issues)

## Melhores Práticas

1. **Sempre teste localmente primeiro** usando `docker-compose up`
2. **Use ambiente staging** para validação antes de produção
3. **Habilite verificações de saúde** na sua plataforma
4. **Monitore logs** após implantação
5. **Mantenha secrets seguros** - nunca comite credenciais
6. **Documente mudanças** no CHANGELOG.md
7. **Versione tudo** usando versionamento semântico
8. **Automatize implantações** usando fluxos CI/CD
9. **Tenha plano de reversão** pronto antes de implantar
10. **Monitore uso de recursos** e ajuste tamanhos de instância conforme necessário

## Próximos Passos

- [Guia de Configuração](../configuration.md)
- [Melhores Práticas de Segurança](../gateway/security.md)
- [Monitoramento e Observabilidade](../gateway/monitoring.md)
- [Guias Específicos por Plataforma](../platforms/)
