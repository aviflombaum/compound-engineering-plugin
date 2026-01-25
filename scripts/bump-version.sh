#!/bin/bash
#
# Bump plugin version in both plugin.json and marketplace.json
#
# Usage: ./scripts/bump-version.sh <plugin-name> <bump-type>
#   bump-type: patch (1.0.0 -> 1.0.1)
#              minor (1.0.0 -> 1.1.0)
#              major (1.0.0 -> 2.0.0)
#
# Example: ./scripts/bump-version.sh compound-engineering patch

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

PLUGIN_NAME="$1"
BUMP_TYPE="$2"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

usage() {
    echo "Usage: $0 <plugin-name> <bump-type>"
    echo ""
    echo "Arguments:"
    echo "  plugin-name  Name of the plugin (e.g., compound-engineering, coding-tutor)"
    echo "  bump-type    Type of version bump: patch, minor, or major"
    echo ""
    echo "Examples:"
    echo "  $0 compound-engineering patch   # 2.28.0 -> 2.28.1"
    echo "  $0 compound-engineering minor   # 2.28.0 -> 2.29.0"
    echo "  $0 coding-tutor patch           # 1.2.1 -> 1.2.2"
    echo ""
    echo "Available plugins:"
    ls -1 "$ROOT_DIR/plugins" 2>/dev/null | grep -v "^\." | sed 's/^/  /'
    exit 1
}

# Validate arguments
if [ -z "$PLUGIN_NAME" ] || [ -z "$BUMP_TYPE" ]; then
    usage
fi

if [[ ! "$BUMP_TYPE" =~ ^(patch|minor|major)$ ]]; then
    echo -e "${RED}Error: bump-type must be 'patch', 'minor', or 'major'${NC}"
    exit 1
fi

PLUGIN_JSON="$ROOT_DIR/plugins/$PLUGIN_NAME/.claude-plugin/plugin.json"
MARKETPLACE_JSON="$ROOT_DIR/.claude-plugin/marketplace.json"

# Check plugin exists
if [ ! -f "$PLUGIN_JSON" ]; then
    echo -e "${RED}Error: Plugin '$PLUGIN_NAME' not found${NC}"
    echo "Expected: $PLUGIN_JSON"
    echo ""
    echo "Available plugins:"
    ls -1 "$ROOT_DIR/plugins" 2>/dev/null | grep -v "^\." | sed 's/^/  /'
    exit 1
fi

# Get current version
CURRENT_VERSION=$(grep -o '"version": *"[^"]*"' "$PLUGIN_JSON" | head -1 | sed 's/.*"\([^"]*\)"$/\1/')

if [ -z "$CURRENT_VERSION" ]; then
    echo -e "${RED}Error: Could not read version from $PLUGIN_JSON${NC}"
    exit 1
fi

# Parse version components
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# Bump version
case "$BUMP_TYPE" in
    patch)
        NEW_PATCH=$((PATCH + 1))
        NEW_VERSION="$MAJOR.$MINOR.$NEW_PATCH"
        ;;
    minor)
        NEW_MINOR=$((MINOR + 1))
        NEW_VERSION="$MAJOR.$NEW_MINOR.0"
        ;;
    major)
        NEW_MAJOR=$((MAJOR + 1))
        NEW_VERSION="$NEW_MAJOR.0.0"
        ;;
esac

echo -e "${YELLOW}Bumping $PLUGIN_NAME: $CURRENT_VERSION -> $NEW_VERSION${NC}"

# Update plugin.json
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS
    sed -i '' "s/\"version\": *\"$CURRENT_VERSION\"/\"version\": \"$NEW_VERSION\"/" "$PLUGIN_JSON"
else
    # Linux
    sed -i "s/\"version\": *\"$CURRENT_VERSION\"/\"version\": \"$NEW_VERSION\"/" "$PLUGIN_JSON"
fi

echo -e "${GREEN}Updated: $PLUGIN_JSON${NC}"

# Update marketplace.json - need to find the right plugin entry
# Using perl for more precise multi-line matching
if [[ "$OSTYPE" == "darwin"* ]]; then
    perl -i -0pe "s/(\"name\": *\"$PLUGIN_NAME\"[^}]*\"version\": *)\"$CURRENT_VERSION\"/\$1\"$NEW_VERSION\"/" "$MARKETPLACE_JSON"
else
    perl -i -0pe "s/(\"name\": *\"$PLUGIN_NAME\"[^}]*\"version\": *)\"$CURRENT_VERSION\"/\$1\"$NEW_VERSION\"/" "$MARKETPLACE_JSON"
fi

echo -e "${GREEN}Updated: $MARKETPLACE_JSON${NC}"

# Verify the updates
PLUGIN_NEW=$(grep -o '"version": *"[^"]*"' "$PLUGIN_JSON" | head -1 | sed 's/.*"\([^"]*\)"$/\1/')
MARKETPLACE_NEW=$(grep -A5 "\"name\": *\"$PLUGIN_NAME\"" "$MARKETPLACE_JSON" | grep -o '"version": *"[^"]*"' | head -1 | sed 's/.*"\([^"]*\)"$/\1/')

echo ""
if [ "$PLUGIN_NEW" = "$NEW_VERSION" ] && [ "$MARKETPLACE_NEW" = "$NEW_VERSION" ]; then
    echo -e "${GREEN}Version bump successful.${NC}"
    echo "  plugin.json:      $NEW_VERSION"
    echo "  marketplace.json: $NEW_VERSION"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "  1. Update CHANGELOG.md with changes"
    echo "  2. Update README.md if component counts changed"
    echo "  3. Run: claude /release-docs (if docs need updating)"
else
    echo -e "${RED}Warning: Version mismatch detected. Please verify manually.${NC}"
    echo "  plugin.json:      $PLUGIN_NEW"
    echo "  marketplace.json: $MARKETPLACE_NEW"
    exit 1
fi
