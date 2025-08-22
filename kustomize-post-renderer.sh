#!/bin/bash


set -e

OVERLAY_PATH=${1:-overlays/dev}
CURRENT_DIR=$(pwd)

# Temp Verzeichnis erstlelen
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Helm Output sichern
cat > "$TEMP_DIR/all.yaml"

# Prüfen ob Overlay existiert
if [ ! -d "$CURRENT_DIR/$OVERLAY_PATH" ]; then
    echo "Error: $CURRENT_DIR/$OVERLAY_PATH not found"
    exit 1
fi

# Zur Overlay-Directory wechseln und von dort aus builden
cd "$CURRENT_DIR/$OVERLAY_PATH"

# Temporäre kustomization.yaml für diesen Build erstellen
cat > "$TEMP_DIR/kustomization.yaml" << EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
- all.yaml

patches:
- path: configmap-patch.yaml
  target:
    kind: ConfigMap
    name: my-config1
EOF

# Patch-Datei in temp Verzeichnis kopieren
cp configmap-patch.yaml "$TEMP_DIR/"

# Build ausführen
cd "$TEMP_DIR"
kustomize build .
