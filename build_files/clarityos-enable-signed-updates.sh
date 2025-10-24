#!/bin/bash
set -euo pipefail

# ClarityOS First Boot - Convert to Signed Updates
# This script runs once on first boot to enable signature verification
# Similar to how Bazzite handles the transition from unverified to signed

MARKER_FILE="/var/lib/clarityos/.signed-updates-enabled"

# Check if already converted
if [ -f "$MARKER_FILE" ]; then
    echo "Already converted to signed updates. Exiting."
    exit 0
fi

echo "ClarityOS First Boot: Enabling signature verification for future updates..."

# Install the policy.json that requires signature verification
mkdir -p /etc/containers
cat > /etc/containers/policy.json << 'EOF'
{
  "default": [
    {
      "type": "insecureAcceptAnything"
    }
  ],
  "transports": {
    "docker": {
      "ghcr.io/ctsdownloads/clarity-os": [
        {
          "type": "signedBy",
          "keyPath": "/etc/pki/containers/clarity-os.pub"
        }
      ]
    },
    "containers-storage": {
      "": [
        {
          "type": "insecureAcceptAnything"
        }
      ]
    }
  }
}
EOF

echo "Policy installed. Signature verification now enabled for ghcr.io/ctsdownloads/clarity-os"

# Rebase to the signed image URL format
# This converts from ostree-unverified-registry: to ostree-image-signed:
echo "Converting to signed image format..."

# Get current image reference
CURRENT_IMAGE=$(rpm-ostree status --json | jq -r '.deployments[0]."container-image-reference"' | sed 's/ostree-unverified-registry://' | sed 's/ostree-image-signed:docker://')

if [[ "$CURRENT_IMAGE" == *"ghcr.io/ctsdownloads/clarity-os"* ]]; then
    echo "Rebasing to signed image reference..."
    rpm-ostree rebase "ostree-image-signed:docker://${CURRENT_IMAGE}" || {
        echo "Warning: Rebase to signed image failed. Will retry on next boot."
        exit 0
    }
    
    # Mark as complete
    mkdir -p /var/lib/clarityos
    touch "$MARKER_FILE"
    echo "✓ Successfully enabled signature verification"
    echo "Changes will take effect on next reboot"
else
    echo "Not running ClarityOS image, skipping conversion"
fi

exit 0
