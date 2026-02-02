#!/bin/bash

# Mithril - Build Script
# Builds the Mithril Docker image locally
# Forked from pi-hole/docker-pi-hole

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Default values
TAG="mithril:local"
USE_CACHE=""
FTL_BRANCH="master"
CORE_BRANCH="master"
WEB_BRANCH="master"
PADD_BRANCH="master"
LOCAL_FTL=false

# Usage function
usage() {
    echo ""
    echo "Mithril Docker Image Builder"
    echo ""
    echo "Usage: $0 [-l] [-f <ftl_branch>] [-c <core_branch>] [-w <web_branch>] [-p <padd_branch>] [-t <tag>] [use_cache]"
    echo ""
    echo "Options:"
    echo "  -f, --ftlbranch <branch>     Specify FTL branch (cannot be used with -l)"
    echo "  -c, --corebranch <branch>    Specify Core branch (default: master)"
    echo "  -w, --webbranch <branch>     Specify Web branch (default: master)"
    echo "  -p, --paddbranch <branch>    Specify PADD branch (default: master)"
    echo "  -t, --tag <tag>              Specify Docker image tag (default: mithril:local)"
    echo "  -l, --local                  Use locally built FTL binary (requires src/pihole-FTL file)"
    echo "  use_cache                    Enable caching (by default --no-cache is used)"
    echo ""
    echo "Examples:"
    echo "  $0                           Build with defaults"
    echo "  $0 -t mithril:v1.0           Build with custom tag"
    echo "  $0 use_cache                 Build with Docker cache enabled"
    echo ""
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--ftlbranch)
            FTL_BRANCH="$2"
            shift 2
            ;;
        -c|--corebranch)
            CORE_BRANCH="$2"
            shift 2
            ;;
        -w|--webbranch)
            WEB_BRANCH="$2"
            shift 2
            ;;
        -p|--paddbranch)
            PADD_BRANCH="$2"
            shift 2
            ;;
        -t|--tag)
            TAG="$2"
            shift 2
            ;;
        -l|--local)
            LOCAL_FTL=true
            shift
            ;;
        use_cache)
            USE_CACHE="yes"
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            usage
            ;;
    esac
done

# Check for conflicting options
if [ "$LOCAL_FTL" = true ] && [ "$FTL_BRANCH" != "master" ]; then
    echo -e "${RED}Error: Cannot use -l (local FTL) with -f (FTL branch)${NC}"
    exit 1
fi

# Check for local FTL binary if requested
if [ "$LOCAL_FTL" = true ]; then
    if [ ! -f "src/pihole-FTL" ]; then
        echo -e "${RED}Error: Local FTL binary not found at src/pihole-FTL${NC}"
        echo "Please build pihole-FTL and place it in the src/ directory"
        exit 1
    fi
    FTL_SOURCE="local"
else
    FTL_SOURCE="remote"
fi

# Build the cache argument
if [ -z "$USE_CACHE" ]; then
    CACHE_ARG="--no-cache"
else
    CACHE_ARG=""
fi

echo ""
echo -e "${GREEN}┌──────────────────────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│  ⚔️  Building Mithril Docker Image                            │${NC}"
echo -e "${GREEN}└──────────────────────────────────────────────────────────────┘${NC}"
echo ""
echo -e "  Tag:          ${YELLOW}${TAG}${NC}"
echo -e "  FTL Source:   ${YELLOW}${FTL_SOURCE}${NC}"
echo -e "  FTL Branch:   ${YELLOW}${FTL_BRANCH}${NC}"
echo -e "  Core Branch:  ${YELLOW}${CORE_BRANCH}${NC}"
echo -e "  Web Branch:   ${YELLOW}${WEB_BRANCH}${NC}"
echo -e "  PADD Branch:  ${YELLOW}${PADD_BRANCH}${NC}"
echo -e "  Cache:        ${YELLOW}${USE_CACHE:-disabled}${NC}"
echo ""

# Build the image
docker buildx build src/. \
    --tag "${TAG}" \
    --build-arg FTL_SOURCE="${FTL_SOURCE}" \
    --build-arg FTL_BRANCH="${FTL_BRANCH}" \
    --build-arg CORE_BRANCH="${CORE_BRANCH}" \
    --build-arg WEB_BRANCH="${WEB_BRANCH}" \
    --build-arg PADD_BRANCH="${PADD_BRANCH}" \
    --build-arg MITHRIL_TAG="${TAG}" \
    ${CACHE_ARG}

echo ""
echo -e "${GREEN}┌──────────────────────────────────────────────────────────────┐${NC}"
echo -e "${GREEN}│  ✅ Build complete!                                          │${NC}"
echo -e "${GREEN}│                                                              │${NC}"
echo -e "${GREEN}│  Run with: docker compose up -d                              │${NC}"
echo -e "${GREEN}└──────────────────────────────────────────────────────────────┘${NC}"
echo ""
