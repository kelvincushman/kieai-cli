#!/usr/bin/env bash
# =============================================================================
# setup-nova.sh — Generate the Nova CLI from the KIE.AI API spec
# Run this on: 192.168.55.228 (Ubuntu server with Go installed)
#
# Usage:
#   chmod +x setup-nova.sh
#   ./setup-nova.sh
#
# What this does:
#   1. Verifies Go and printing-press are available
#   2. Copies the KIE.AI spec + Nova brief to a working directory
#   3. Runs printing-press to generate the Nova CLI, Claude Code skill, and MCP server
#   4. Wires `nova` into your PATH
# =============================================================================

set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────────
NOVA_OUTPUT_DIR="$HOME/nova"
SPEC_FILE="$(dirname "$0")/kie-ai-openapi.yaml"
BRIEF_FILE="$(dirname "$0")/nova-brief.md"
CLI_NAME="nova"
PRINTING_PRESS="printing-press"

# ── Colors ─────────────────────────────────────────────────────────────────────
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[nova]${NC} $*"; }
success() { echo -e "${GREEN}[nova]${NC} $*"; }
warn()    { echo -e "${YELLOW}[nova]${NC} $*"; }
err()     { echo -e "${RED}[nova]${NC} $*" >&2; }

# ── Step 1: Check prerequisites ───────────────────────────────────────────────
info "Checking prerequisites..."

if ! command -v go &>/dev/null; then
  err "Go is not installed or not in PATH."
  err "Install Go from https://go.dev/dl/ then re-run this script."
  exit 1
fi
success "Go $(go version | awk '{print $3}') found"

# Install printing-press if not present
if ! command -v "$PRINTING_PRESS" &>/dev/null; then
  warn "printing-press not found. Installing..."
  go install github.com/mvanhorn/cli-printing-press/v4/cmd/printing-press@latest
  # Make sure GOPATH/bin is in PATH
  export PATH="$PATH:$(go env GOPATH)/bin"
  if ! command -v "$PRINTING_PRESS" &>/dev/null; then
    err "Installation failed. Add \$(go env GOPATH)/bin to your PATH and retry."
    exit 1
  fi
fi
success "printing-press $(printing-press --version 2>/dev/null || echo '(version unknown)') found"

# Verify spec files exist
if [[ ! -f "$SPEC_FILE" ]]; then
  err "OpenAPI spec not found at: $SPEC_FILE"
  err "Make sure kie-ai-openapi.yaml is in the same directory as this script."
  exit 1
fi
success "KIE.AI OpenAPI spec found"

if [[ ! -f "$BRIEF_FILE" ]]; then
  warn "Nova brief not found at: $BRIEF_FILE (will continue without it)"
  BRIEF_ARGS=""
else
  success "Nova brief found"
  BRIEF_ARGS="--brief $BRIEF_FILE"
fi

# ── Step 2: Create output directory ───────────────────────────────────────────
info "Setting up output directory: $NOVA_OUTPUT_DIR"
mkdir -p "$NOVA_OUTPUT_DIR"

# ── Step 3: Run Printing Press ────────────────────────────────────────────────
info "Running Printing Press to generate Nova CLI..."
echo ""
echo "  Spec:   $SPEC_FILE"
echo "  Brief:  $BRIEF_FILE"
echo "  Output: $NOVA_OUTPUT_DIR"
echo "  Name:   $CLI_NAME"
echo ""
warn "This may take 2–5 minutes — Printing Press is designing the optimal CLI..."
echo ""

# Run printing-press generate with the correct flags (v4.9.0+)
printing-press generate \
    --spec "$SPEC_FILE" \
    --name "$CLI_NAME" \
    --output "$NOVA_OUTPUT_DIR" \
    --spec-source official \
    --polish || {
  err "printing-press generate failed."
  err "Check the output above, then retry manually:"
  err "  printing-press generate --spec $SPEC_FILE --name nova --output $NOVA_OUTPUT_DIR"
  exit 1
}
success "Printing Press generate completed!"

# ── Step 4: Build the Go binary ───────────────────────────────────────────────
echo ""
info "Building nova binary..."

# printing-press typically puts a go.mod in the output directory
if [[ -f "$NOVA_OUTPUT_DIR/go.mod" ]]; then
  cd "$NOVA_OUTPUT_DIR"
  go build -o "$HOME/go/bin/$CLI_NAME" . && success "nova binary built at: $(which nova 2>/dev/null || echo $HOME/go/bin/nova)"
elif [[ -f "$NOVA_OUTPUT_DIR/cmd/$CLI_NAME/main.go" ]]; then
  cd "$NOVA_OUTPUT_DIR"
  go build -o "$HOME/go/bin/$CLI_NAME" "./cmd/$CLI_NAME/" && success "nova binary built"
else
  warn "Could not auto-detect Go source location in $NOVA_OUTPUT_DIR"
  warn "Check the output directory and run 'go build' manually."
  ls -la "$NOVA_OUTPUT_DIR" 2>/dev/null || true
fi

# ── Step 5: Wire into PATH ────────────────────────────────────────────────────
GOBIN="$(go env GOPATH)/bin"
if [[ ":$PATH:" != *":$GOBIN:"* ]]; then
  echo ""
  warn "Add this to your ~/.bashrc or ~/.zshrc to make nova permanent:"
  echo ""
  echo "    export PATH=\"\$PATH:$GOBIN\""
  echo ""
  export PATH="$PATH:$GOBIN"
fi

# ── Step 6: Set up auth ───────────────────────────────────────────────────────
echo ""
info "Almost done! Set your KIE.AI API key:"
echo ""
echo "    # Option A: environment variable (recommended)"
echo "    export KIE_API_KEY=your_api_key_here"
echo "    echo 'export KIE_API_KEY=your_api_key_here' >> ~/.bashrc"
echo ""
echo "    # Option B: nova config"
echo "    nova auth your_api_key_here"
echo ""
echo "  Get your API key at: https://kie.ai/api-key"
echo ""

# ── Step 7: What was generated ────────────────────────────────────────────────
echo ""
success "═══════════════════════════════════════════════════"
success " Nova CLI generation complete!"
success "═══════════════════════════════════════════════════"
echo ""
info "Generated files in $NOVA_OUTPUT_DIR:"
ls -la "$NOVA_OUTPUT_DIR" 2>/dev/null || true
echo ""
info "Quick test (after setting KIE_API_KEY):"
echo ""
echo '    nova models                                   # list all available models'
echo '    nova image "a fox in snow, cinematic" --out fox.jpg'
echo '    nova video "surfer at sunset" --out surf.mp4'
echo '    nova music "chill lo-fi hip hop" --out track.mp3'
echo ""
info "Claude Code skill location (for agents):"
find "$NOVA_OUTPUT_DIR" -name "SKILL.md" 2>/dev/null | head -5 || echo "  Check $NOVA_OUTPUT_DIR for .skill files"
echo ""
info "MCP server config:"
find "$NOVA_OUTPUT_DIR" -name "mcp*.json" -o -name "*mcp*.yaml" 2>/dev/null | head -5 || echo "  Check $NOVA_OUTPUT_DIR for MCP config"
echo ""
success "Nova is ready. Run: nova --help"
