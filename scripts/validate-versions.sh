#!/bin/bash
#
# Validate that plugin versions are consistent and bumped when files change
#
# Usage: ./scripts/validate-versions.sh [base-branch]
#   base-branch: Branch to compare against (default: main)
#
# Checks:
# 1. Version in plugin.json matches version in marketplace.json
# 2. If plugin files changed, version was bumped

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

BASE_BRANCH="${1:-main}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

ERRORS=0

echo "Validating plugin versions..."
echo ""

# Get list of plugins
PLUGINS=$(ls -1 "$ROOT_DIR/plugins" 2>/dev/null | grep -v "^\.")

for PLUGIN_NAME in $PLUGINS; do
    PLUGIN_JSON="$ROOT_DIR/plugins/$PLUGIN_NAME/.claude-plugin/plugin.json"
    MARKETPLACE_JSON="$ROOT_DIR/.claude-plugin/marketplace.json"

    if [ ! -f "$PLUGIN_JSON" ]; then
        echo -e "${YELLOW}Warning: No plugin.json for $PLUGIN_NAME${NC}"
        continue
    fi

    echo "Checking $PLUGIN_NAME..."

    # Get versions from both files
    PLUGIN_VERSION=$(grep -o '"version": *"[^"]*"' "$PLUGIN_JSON" | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
    MARKETPLACE_VERSION=$(grep -A5 "\"name\": *\"$PLUGIN_NAME\"" "$MARKETPLACE_JSON" | grep -o '"version": *"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')

    # Check 1: Versions match
    if [ "$PLUGIN_VERSION" != "$MARKETPLACE_VERSION" ]; then
        echo -e "${RED}  ERROR: Version mismatch${NC}"
        echo "    plugin.json:      $PLUGIN_VERSION"
        echo "    marketplace.json: $MARKETPLACE_VERSION"
        ERRORS=$((ERRORS + 1))
    else
        echo -e "${GREEN}  Versions match: $PLUGIN_VERSION${NC}"
    fi

    # Check 2: If plugin files changed, version should be bumped
    # Only check on CI when we have a base branch to compare against
    if git rev-parse --verify "origin/$BASE_BRANCH" &>/dev/null; then
        CHANGED_FILES=$(git diff --name-only "origin/$BASE_BRANCH"...HEAD -- "plugins/$PLUGIN_NAME/" 2>/dev/null || echo "")

        if [ -n "$CHANGED_FILES" ]; then
            # Get version from base branch
            BASE_VERSION=$(git show "origin/$BASE_BRANCH:plugins/$PLUGIN_NAME/.claude-plugin/plugin.json" 2>/dev/null | grep -o '"version": *"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/' || echo "")

            if [ -n "$BASE_VERSION" ] && [ "$BASE_VERSION" = "$PLUGIN_VERSION" ]; then
                echo -e "${RED}  ERROR: Plugin files changed but version not bumped${NC}"
                echo "    Current version: $PLUGIN_VERSION"
                echo "    Changed files:"
                echo "$CHANGED_FILES" | sed 's/^/      /'
                echo ""
                echo "    Fix: ./scripts/bump-version.sh $PLUGIN_NAME patch"
                ERRORS=$((ERRORS + 1))
            fi
        fi
    fi

    echo ""
done

if [ $ERRORS -gt 0 ]; then
    echo -e "${RED}Validation failed with $ERRORS error(s)${NC}"
    exit 1
else
    echo -e "${GREEN}All validations passed${NC}"
fi
