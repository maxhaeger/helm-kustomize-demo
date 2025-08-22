#!/bin/bash

# Kustomize Post-Renderer für Helm
# Usage: helm install/upgrade --post-renderer ./kustomize-post-renderer.sh --post-renderer-args overlays/dev

set -e

# Overlay-Pfad aus Argumenten
OVERLAY_PATH=${1:-overlays/dev}

# Temporäres Verzeichnis erstellen
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Helm Output in temporäre Datei schreiben
cat > "$TEMP_DIR/all.yaml"

# Kustomization.yaml für das Overlay erstellen, falls nicht vorhanden
if [ ! -f "$OVERLAY_PATH/kustomization.yaml" ]; then
    echo "Error: $OVERLAY_PATH/kustomization.yaml not found"
    exit 1
fi

# Base kustomization.yaml erstellen, die auf Helm Output verweist
cat > "$TEMP_DIR/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- all.yaml

patchesStrategicMerge:
$(cd "$OVERLAY_PATH" && find . -name "*.yaml" -not -name "kustomization.yaml" | sed 's|^|- ../'"$OVERLAY_PATH"'/|')
EOF

# Kustomize build ausführen
cd "$TEMP_DIR"
kustomize build .
