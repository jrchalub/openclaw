#!/usr/bin/env bash
set -euo pipefail

# OpenClaw Rollback Script
# Quickly rollback to a previous deployment

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ENVIRONMENT="${ENVIRONMENT:-production}"
PLATFORM="${PLATFORM:-fly}"
VERSION="${VERSION:-}"

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

Rollback OpenClaw deployment to a previous version

OPTIONS:
  -e, --environment ENV    Environment (staging|production) [default: production]
  -p, --platform PLATFORM  Platform (fly|render|docker) [default: fly]
  -v, --version VERSION    Version to rollback to (required)
  -h, --help              Show this help message

EXAMPLES:
  # Rollback Fly.io to version 2026.2.2
  $(basename "$0") --platform fly --version 2026.2.2

  # Rollback staging environment
  $(basename "$0") --environment staging --version 2026.2.1
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
      -v|--version)
        VERSION="$2"
        shift 2
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

  if [ -z "$VERSION" ]; then
    log_error "Version is required"
    usage
    exit 1
  fi
}

rollback_fly() {
  local app_name="openclaw"
  if [ "$ENVIRONMENT" = "staging" ]; then
    app_name="openclaw-staging"
  fi

  log_info "Rolling back Fly.io app: $app_name to version $VERSION"

  # List recent deployments
  log_info "Recent deployments:"
  flyctl releases --app "$app_name" --limit 10

  # Find the deployment version
  local release_id
  release_id=$(flyctl releases --app "$app_name" --json | \
    jq -r ".[] | select(.version == \"$VERSION\") | .id" | head -n 1)

  if [ -z "$release_id" ]; then
    log_error "Could not find release for version $VERSION"
    exit 1
  fi

  log_info "Found release ID: $release_id"
  
  # Confirm rollback
  read -p "Are you sure you want to rollback to version $VERSION? (yes/no) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Rollback cancelled"
    exit 0
  fi

  flyctl releases rollback "$release_id" --app "$app_name" || {
    log_error "Rollback failed"
    exit 1
  }

  log_success "Rollback completed"
  
  # Show status
  flyctl status --app "$app_name"
}

rollback_render() {
  log_info "Rolling back Render service to version $VERSION"

  # Get recent deploys
  local deploys
  deploys=$(curl -s \
    "https://api.render.com/v1/services/${RENDER_SERVICE_ID}/deploys" \
    -H "Authorization: Bearer ${RENDER_API_KEY}")

  log_info "Recent deploys:"
  echo "$deploys" | jq -r '.[] | "\(.id) - \(.status) - \(.createdAt)"' | head -n 10

  # Find deploy by version (this assumes version is in commit message or branch)
  local deploy_id
  deploy_id=$(echo "$deploys" | jq -r ".[] | select(.commit.message | contains(\"$VERSION\")) | .id" | head -n 1)

  if [ -z "$deploy_id" ]; then
    log_error "Could not find deploy for version $VERSION"
    log_info "Please specify the deploy ID manually"
    exit 1
  fi

  log_info "Found deploy ID: $deploy_id"
  
  # Confirm rollback
  read -p "Are you sure you want to rollback to version $VERSION? (yes/no) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Rollback cancelled"
    exit 0
  fi

  # Trigger rollback by redeploying that version
  curl -X POST \
    "https://api.render.com/v1/services/${RENDER_SERVICE_ID}/deploys/${deploy_id}/redeploy" \
    -H "Authorization: Bearer ${RENDER_API_KEY}" || {
    log_error "Rollback failed"
    exit 1
  }

  log_success "Rollback initiated"
}

rollback_docker() {
  local registry="${DOCKER_REGISTRY:-ghcr.io}"
  local image_name="${DOCKER_IMAGE_NAME:-openclaw/openclaw}"
  local tag="${registry}/${image_name}:${VERSION}"
  
  if [ "$ENVIRONMENT" = "staging" ]; then
    tag="${tag}-staging"
  fi

  log_info "Rolling back Docker deployment to: $tag"

  # Check if image exists
  if ! docker pull "$tag" 2>/dev/null; then
    log_error "Could not pull image: $tag"
    exit 1
  fi

  # Confirm rollback
  read -p "Are you sure you want to rollback to version $VERSION? (yes/no) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Rollback cancelled"
    exit 0
  fi

  # Retag as latest
  local latest_tag="${registry}/${image_name}:latest"
  if [ "$ENVIRONMENT" = "staging" ]; then
    latest_tag="${registry}/${image_name}:staging"
  fi

  docker tag "$tag" "$latest_tag"
  docker push "$latest_tag"

  log_success "Rollback completed. Image $tag is now tagged as $latest_tag"
  log_info "Update your deployment configuration to use this version"
}

main() {
  cd "$PROJECT_ROOT"
  parse_args "$@"

  case $PLATFORM in
    fly)
      rollback_fly
      ;;
    render)
      rollback_render
      ;;
    docker)
      rollback_docker
      ;;
    *)
      log_error "Unknown platform: $PLATFORM"
      exit 1
      ;;
  esac
}

main "$@"
