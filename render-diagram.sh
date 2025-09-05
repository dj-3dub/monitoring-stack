#!/usr/bin/env bash
# Regenerate Monitoring Stack architecture diagram

set -e

DOT_FILE="docs/architecture.dot"
PNG_FILE="docs/architecture.png"
SVG_FILE="docs/architecture.svg"

if ! command -v dot >/dev/null 2>&1; then
  echo "Error: graphviz is not installed. Install with: sudo apt install graphviz -y"
  exit 1
fi

if [ ! -f "$DOT_FILE" ]; then
  echo "Error: $DOT_FILE not found. Run from project root: ./render-diagram.sh"
  exit 1
fi

echo "Rendering architecture diagram..."
dot -Tpng "$DOT_FILE" -o "$PNG_FILE"
dot -Tsvg "$DOT_FILE" -o "$SVG_FILE"

echo "✅ Diagram rendered:"
echo " - $PNG_FILE"
echo " - $SVG_FILE"
