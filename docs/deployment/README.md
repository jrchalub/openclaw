---
summary: "Deployment guide for OpenClaw across multiple platforms"
read_when:
  - Deploying OpenClaw to production
  - Setting up CI/CD pipelines
  - Rolling back deployments
---

# Deployment Guide

OpenClaw supports deployment to multiple platforms with automated CI/CD pipelines and manual deployment scripts.

## Table of Contents

- [Supported Platforms](#supported-platforms)
- [Prerequisites](#prerequisites)
- [Automated Deployment (CI/CD)](#automated-deployment-cicd)
- [Manual Deployment](#manual-deployment)
- [Environment Configuration](#environment-configuration)
- [Rollback Procedures](#rollback-procedures)
- [Health Checks](#health-checks)
- [Troubleshooting](#troubleshooting)

## Supported Platforms

OpenClaw can be deployed to:

1. **Fly.io** - Recommended for production with persistent storage
2. **Render** - Simple deployment with automatic scaling
3. **Docker** - Self-hosted or custom container platforms
4. **Docker Compose** - Local development and self-hosted deployments

## Prerequisites

### General Requirements

- Node.js 22+ (for building)
- pnpm 10.23.0+ (via corepack)
- Git (for version control)

### Platform-Specific Requirements

#### Fly.io
```bash
# Install flyctl
curl -L https://fly.io/install.sh | sh

# Login
flyctl auth login

# Set API token (for CI/CD)
export FLY_API_TOKEN="your-token"
```

#### Render
- Render account with API access
- Service created via render.yaml or dashboard
- API key from account settings

```bash
export RENDER_API_KEY="your-api-key"
export RENDER_SERVICE_ID="your-service-id"
```

#### Docker
```bash
# Ensure Docker is installed
docker --version

# Login to registry (GitHub Container Registry example)
echo $GITHUB_TOKEN | docker login ghcr.io -u USERNAME --password-stdin
```

## Automated Deployment (CI/CD)

### GitHub Actions Workflow

The project includes a comprehensive deployment workflow at `.github/workflows/deploy.yml`.

#### Trigger Deployment

**Manual Trigger:**
```bash
# Via GitHub UI: Actions → Deploy → Run workflow
# Select environment and platform
```

**Tag-based Deployment:**
```bash
# Create and push a version tag
git tag v2026.2.4
git push origin v2026.2.4

# Automatically triggers deployment to all platforms
```

#### Workflow Features

- Pre-deployment validation (build, test, lint)
- Multi-platform deployment (Fly.io, Render, Docker)
- Health checks after deployment
- Automatic GitHub release creation
- Deployment status notifications

### Environment Variables for CI/CD

Configure these secrets in your GitHub repository settings:

```yaml
# Fly.io
FLY_API_TOKEN: "your-fly-api-token"

# Render
RENDER_API_KEY: "your-render-api-key"
RENDER_SERVICE_ID: "your-service-id"

# Optional: Custom Docker registry
DOCKER_REGISTRY: "ghcr.io"
DOCKER_IMAGE_NAME: "openclaw/openclaw"
```

## Manual Deployment

### Using the Deployment Script

```bash
# Deploy to Fly.io production
./scripts/deploy.sh --platform fly --environment production

# Deploy to all platforms in staging
./scripts/deploy.sh --platform all --environment staging

# Dry-run deployment
./scripts/deploy.sh --platform render --dry-run

# Skip tests (not recommended for production)
./scripts/deploy.sh --platform fly --skip-tests
```

### Script Options

```
OPTIONS:
  -e, --environment ENV    Deployment environment (staging|production)
  -p, --platform PLATFORM  Target platform (fly|render|docker|all)
  -d, --dry-run           Run without actual deployment
  -s, --skip-tests        Skip running tests
  -b, --skip-build        Skip build step
  -h, --help              Show help message
```

### Platform-Specific Deployment

#### Fly.io

```bash
# Deploy to production
flyctl deploy --config fly.toml --app openclaw

# Deploy to staging
flyctl deploy --config fly.toml --app openclaw-staging

# Check status
flyctl status --app openclaw

# View logs
flyctl logs --app openclaw
```

#### Render

```bash
# Trigger deployment via API
curl -X POST "https://api.render.com/v1/services/$RENDER_SERVICE_ID/deploys" \
  -H "Authorization: Bearer $RENDER_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"clearCache": false}'

# Or use the dashboard at https://dashboard.render.com
```

#### Docker

```bash
# Build image
docker build -t openclaw:latest .

# Tag for registry
docker tag openclaw:latest ghcr.io/openclaw/openclaw:2026.2.4

# Push to registry
docker push ghcr.io/openclaw/openclaw:2026.2.4

# Run locally
docker run -p 18789:18789 \
  -e OPENCLAW_GATEWAY_TOKEN="your-token" \
  -v ~/.openclaw:/home/node/.openclaw \
  openclaw:latest
```

#### Docker Compose

```bash
# Set environment variables
export OPENCLAW_GATEWAY_TOKEN="your-token"
export CLAUDE_AI_SESSION_KEY="your-session-key"
export OPENCLAW_CONFIG_DIR="${HOME}/.openclaw"
export OPENCLAW_WORKSPACE_DIR="${HOME}/.openclaw/workspace"

# Start services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

## Environment Configuration

### Required Environment Variables

```bash
# Authentication
OPENCLAW_GATEWAY_TOKEN="your-secure-token"

# AI Provider (choose one or more)
CLAUDE_AI_SESSION_KEY="your-claude-session"
CLAUDE_WEB_SESSION_KEY="your-claude-web-session"
CLAUDE_WEB_COOKIE="your-claude-cookie"
OPENAI_API_KEY="your-openai-key"
ANTHROPIC_API_KEY="your-anthropic-key"

# Gateway Configuration
OPENCLAW_GATEWAY_BIND="lan"  # or "loopback" for local only
OPENCLAW_GATEWAY_PORT="18789"
```

### Optional Configuration

```bash
# Storage
OPENCLAW_STATE_DIR="/data/.openclaw"
OPENCLAW_WORKSPACE_DIR="/data/workspace"

# Node.js Options
NODE_ENV="production"
NODE_OPTIONS="--max-old-space-size=1536"

# Platform-specific
OPENCLAW_PREFER_PNPM="1"  # Use pnpm for builds
```

### Platform Configuration Files

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

## Rollback Procedures

### Using the Rollback Script

```bash
# Rollback Fly.io to specific version
./scripts/rollback.sh --platform fly --version 2026.2.3

# Rollback staging environment
./scripts/rollback.sh --environment staging --version 2026.2.2

# Rollback Docker deployment
./scripts/rollback.sh --platform docker --version 2026.2.1
```

### Manual Rollback

#### Fly.io
```bash
# List recent releases
flyctl releases --app openclaw

# Rollback to specific version
flyctl releases rollback VERSION_NUMBER --app openclaw
```

#### Render
```bash
# Via dashboard: Select previous deploy and click "Redeploy"
# Or use API to trigger redeploy of specific version
```

#### Docker
```bash
# Pull previous version
docker pull ghcr.io/openclaw/openclaw:2026.2.3

# Retag as latest
docker tag ghcr.io/openclaw/openclaw:2026.2.3 ghcr.io/openclaw/openclaw:latest

# Push updated latest tag
docker push ghcr.io/openclaw/openclaw:latest
```

## Health Checks

### Built-in Health Endpoint

OpenClaw exposes a health check endpoint at `/health` (when available).

```bash
# Check health
curl https://your-deployment-url.fly.dev/health

# Expected response: 200 OK
```

### Platform Health Checks

#### Fly.io
```bash
# Check app status
flyctl status --app openclaw

# View recent logs
flyctl logs --app openclaw --limit 100

# Check VM metrics
flyctl vm status --app openclaw
```

#### Render
```bash
# Check via API
curl "https://api.render.com/v1/services/$RENDER_SERVICE_ID" \
  -H "Authorization: Bearer $RENDER_API_KEY"

# Or use dashboard: https://dashboard.render.com
```

#### Docker
```bash
# Check container status
docker ps | grep openclaw

# View logs
docker logs openclaw-container

# Execute health check inside container
docker exec openclaw-container node dist/index.js gateway --help
```

## Troubleshooting

### Common Issues

#### Build Failures

**Problem:** Build fails during deployment

**Solution:**
```bash
# Clean build locally
rm -rf dist node_modules
pnpm install --frozen-lockfile
pnpm build

# Check for errors
pnpm lint
pnpm test
```

#### Connection Issues

**Problem:** Cannot connect to gateway after deployment

**Solution:**
1. Check gateway is bound to correct interface (`lan` vs `loopback`)
2. Verify firewall/security group rules
3. Ensure `OPENCLAW_GATEWAY_TOKEN` is set correctly
4. Check logs for startup errors

#### Memory Issues

**Problem:** Container/VM runs out of memory

**Solution:**
```bash
# Increase Node.js memory limit
export NODE_OPTIONS="--max-old-space-size=2048"

# Or update platform configuration (fly.toml, render.yaml)
# to use larger instance size
```

#### Session/Authentication Errors

**Problem:** Cannot authenticate with AI providers

**Solution:**
1. Verify session keys are current and valid
2. Check environment variables are set correctly
3. Review logs for authentication errors
4. Refresh session keys if expired

### Getting Help

- Check logs first: `flyctl logs`, `docker logs`, or Render dashboard
- Review [troubleshooting guide](../gateway/troubleshooting.md)
- Run `openclaw doctor` for diagnostics
- Check [GitHub Issues](https://github.com/openclaw/openclaw/issues)

## Best Practices

1. **Always test locally first** using `docker-compose up`
2. **Use staging environment** for validation before production
3. **Enable health checks** on your platform
4. **Monitor logs** after deployment
5. **Keep secrets secure** - never commit credentials
6. **Document changes** in CHANGELOG.md
7. **Version everything** using semantic versioning
8. **Automate deployments** using CI/CD workflows
9. **Have rollback plan** ready before deploying
10. **Monitor resource usage** and adjust instance sizes as needed

## Next Steps

- [Configuration Guide](../configuration.md)
- [Security Best Practices](../gateway/security.md)
- [Monitoring and Observability](../gateway/monitoring.md)
- [Platform-Specific Guides](../platforms/)
