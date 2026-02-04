#!/usr/bin/env bash
set -euo pipefail

# OpenClaw Deployment Script
# Supports multiple deployment platforms with environment-specific configurations

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
ENVIRONMENT="${ENVIRONMENT:-production}"
PLATFORM="${PLATFORM:-fly}"
DRY_RUN="${DRY_RUN:-false}"
SKIP_TESTS="${SKIP_TESTS:-false}"
SKIP_BUILD="${SKIP_BUILD:-false}"

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

usage() {
  cat << EOF
Usage: $(basename "$0") [OPTIONS]

Deploy OpenClaw to various platforms

OPTIONS:
  -e, --environment ENV    Deployment environment (staging|production) [default: production]
  -p, --platform PLATFORM  Target platform (fly|render|docker|all) [default: fly]
  -d, --dry-run           Run in dry-run mode (no actual deployment)
  -s, --skip-tests        Skip running tests before deployment
  -b, --skip-build        Skip build step (use existing dist/)
  -h, --help              Show this help message

EXAMPLES:
  # Deploy to Fly.io production
  $(basename "$0") --platform fly --environment production

  # Deploy to all platforms in staging
  $(basename "$0") --platform all --environment staging

  # Dry-run deployment to Render
  $(basename "$0") --platform render --dry-run

ENVIRONMENT VARIABLES:
  FLY_API_TOKEN           Fly.io API token
  RENDER_API_KEY          Render API key
  RENDER_SERVICE_ID       Render service ID
  DOCKER_REGISTRY         Docker registry URL (default: ghcr.io)
  OPENCLAW_VERSION        Override version detection
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case $1 in
      -e|--environment)
        ENVIRONMENT="$2"
        shift 2
        ;;
      -p|--platform)
        PLATFORM="$2"
        shift 2
        ;;
      -d|--dry-run)
        DRY_RUN=true
        shift
        ;;
      -s|--skip-tests)
        SKIP_TESTS=true
        shift
        ;;
      -b|--skip-build)
        SKIP_BUILD=true
        shift
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        log_error "Unknown option: $1"
        usage
        exit 1
        ;;
    esac
  done
}

check_requirements() {
  log_info "Checking requirements..."

  # Check Node.js version
  if ! command -v node &> /dev/null; then
    log_error "Node.js is not installed"
    exit 1
  fi

  NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
  if [ "$NODE_VERSION" -lt 22 ]; then
    log_error "Node.js 22+ is required (found: $(node -v))"
    exit 1
  fi

  # Check pnpm
  if ! command -v pnpm &> /dev/null; then
    log_error "pnpm is not installed. Run: corepack enable && corepack prepare pnpm@10.23.0 --activate"
    exit 1
  fi

  # Platform-specific checks
  case $PLATFORM in
    fly|all)
      if ! command -v flyctl &> /dev/null; then
        log_error "flyctl is not installed. Visit: https://fly.io/docs/hands-on/install-flyctl/"
        exit 1
      fi
      if [ -z "${FLY_API_TOKEN:-}" ]; then
        log_error "FLY_API_TOKEN environment variable is not set"
        exit 1
      fi
      ;;
    render|all)
      if [ -z "${RENDER_API_KEY:-}" ]; then
        log_error "RENDER_API_KEY environment variable is not set"
        exit 1
      fi
      if [ -z "${RENDER_SERVICE_ID:-}" ]; then
        log_error "RENDER_SERVICE_ID environment variable is not set"
        exit 1
      fi
      ;;
    docker|all)
      if ! command -v docker &> /dev/null; then
        log_error "Docker is not installed"
        exit 1
      fi
      ;;
  esac

  log_success "Requirements check passed"
}

get_version() {
  if [ -n "${OPENCLAW_VERSION:-}" ]; then
    echo "$OPENCLAW_VERSION"
  else
    node -p "require('./package.json').version"
  fi
}

run_tests() {
  if [ "$SKIP_TESTS" = true ]; then
    log_warn "Skipping tests (--skip-tests flag)"
    return 0
  fi

  log_info "Running tests..."
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would run: pnpm test"
    return 0
  fi

  pnpm test || {
    log_error "Tests failed"
    exit 1
  }
  log_success "Tests passed"
}

build_project() {
  if [ "$SKIP_BUILD" = true ]; then
    log_warn "Skipping build (--skip-build flag)"
    return 0
  fi

  log_info "Building project..."
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would run: pnpm build"
    return 0
  fi

  pnpm build || {
    log_error "Build failed"
    exit 1
  }
  log_success "Build completed"
}

deploy_to_fly() {
  local app_name="openclaw"
  if [ "$ENVIRONMENT" = "staging" ]; then
    app_name="openclaw-staging"
  fi

  log_info "Deploying to Fly.io ($app_name)..."
  
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would run: flyctl deploy --config fly.toml --app $app_name"
    return 0
  fi

  flyctl deploy --config fly.toml --app "$app_name" || {
    log_error "Fly.io deployment failed"
    return 1
  }

  log_success "Deployed to Fly.io"
  
  # Health check
  log_info "Running health check..."
  sleep 10
  if flyctl status --app "$app_name"; then
    log_success "Fly.io health check passed"
  else
    log_warn "Fly.io health check had issues"
  fi
}

deploy_to_render() {
  log_info "Deploying to Render..."
  
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would trigger Render deployment"
    return 0
  fi

  local response
  response=$(curl -s -X POST \
    "https://api.render.com/v1/services/${RENDER_SERVICE_ID}/deploys" \
    -H "Authorization: Bearer ${RENDER_API_KEY}" \
    -H "Content-Type: application/json" \
    -d '{"clearCache": false}')

  if echo "$response" | grep -q "id"; then
    log_success "Render deployment triggered"
    
    # Wait for deployment
    log_info "Waiting for deployment to complete..."
    for i in {1..30}; do
      sleep 10
      local status
      status=$(curl -s \
        "https://api.render.com/v1/services/${RENDER_SERVICE_ID}" \
        -H "Authorization: Bearer ${RENDER_API_KEY}" \
        | grep -o '"status":"[^"]*"' | cut -d'"' -f4)
      
      log_info "Status: $status"
      
      if [ "$status" = "running" ]; then
        log_success "Render deployment completed"
        return 0
      fi
    done
    
    log_warn "Deployment status check timed out"
  else
    log_error "Failed to trigger Render deployment"
    return 1
  fi
}

deploy_to_docker() {
  local registry="${DOCKER_REGISTRY:-ghcr.io}"
  local image_name="${DOCKER_IMAGE_NAME:-openclaw/openclaw}"
  local version
  version=$(get_version)
  local tag="${registry}/${image_name}:${version}"
  
  if [ "$ENVIRONMENT" = "staging" ]; then
    tag="${tag}-staging"
  fi

  log_info "Building and pushing Docker image: $tag"
  
  if [ "$DRY_RUN" = true ]; then
    log_info "[DRY RUN] Would build and push: $tag"
    return 0
  fi

  docker build -t "$tag" . || {
    log_error "Docker build failed"
    return 1
  }

  docker push "$tag" || {
    log_error "Docker push failed"
    return 1
  }

  # Also tag as latest for the environment
  local latest_tag="${registry}/${image_name}:latest"
  if [ "$ENVIRONMENT" = "staging" ]; then
    latest_tag="${registry}/${image_name}:staging"
  fi
  
  docker tag "$tag" "$latest_tag"
  docker push "$latest_tag"

  log_success "Docker image pushed: $tag"
}

deploy() {
  local version
  version=$(get_version)
  
  log_info "Starting deployment"
  log_info "Version: $version"
  log_info "Environment: $ENVIRONMENT"
  log_info "Platform: $PLATFORM"
  
  if [ "$DRY_RUN" = true ]; then
    log_warn "Running in DRY-RUN mode"
  fi

  check_requirements
  run_tests
  build_project

  local deploy_failed=false

  case $PLATFORM in
    fly)
      deploy_to_fly || deploy_failed=true
      ;;
    render)
      deploy_to_render || deploy_failed=true
      ;;
    docker)
      deploy_to_docker || deploy_failed=true
      ;;
    all)
      deploy_to_fly || deploy_failed=true
      deploy_to_render || deploy_failed=true
      deploy_to_docker || deploy_failed=true
      ;;
    *)
      log_error "Unknown platform: $PLATFORM"
      exit 1
      ;;
  esac

  if [ "$deploy_failed" = true ]; then
    log_error "One or more deployments failed"
    exit 1
  fi

  log_success "Deployment completed successfully"
}

main() {
  cd "$PROJECT_ROOT"
  parse_args "$@"
  deploy
}

main "$@"
