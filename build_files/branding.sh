#!/bin/bash
set -ouex pipefail

echo "Applying ClarityOS branding..."

### OS Release Information (Shows in Settings → About)
cat > /usr/lib/os-release << 'EOF'
NAME="ClarityOS"
VERSION="42 (COSMIC)"
ID=clarityos
ID_LIKE="fedora"
VERSION_ID=42
PLATFORM_ID="platform:f42"
PRETTY_NAME="ClarityOS 42 (COSMIC)"
ANSI_COLOR="0;38;2;60;110;180"
LOGO=fedora-logo-icon
CPE_NAME="cpe:/o:clarityos:clarityos:42"
DEFAULT_HOSTNAME="clarityos"
HOME_URL="https://github.com/ctsdownloads/clarity-os"
DOCUMENTATION_URL="https://github.com/ctsdownloads/clarity-os"
SUPPORT_URL="https://github.com/ctsdownloads/clarity-os/issues"
BUG_REPORT_URL="https://github.com/ctsdownloads/clarity-os/issues"
REDHAT_BUGZILLA_PRODUCT="ClarityOS"
REDHAT_BUGZILLA_PRODUCT_VERSION=42
REDHAT_SUPPORT_PRODUCT="ClarityOS"
REDHAT_SUPPORT_PRODUCT_VERSION=42
SUPPORT_END=2025-11-12
VARIANT="COSMIC Desktop"
VARIANT_ID=cosmic
EOF

# Create symlink for /etc/os-release
ln -sf /usr/lib/os-release /etc/os-release

### Issue (Pre-login banner)
cat > /etc/issue << 'EOF'
ClarityOS \r (\l)

EOF

### Issue.net (Network login banner)
cat > /etc/issue.net << 'EOF'
ClarityOS
EOF

### MOTD (Message of the day)
cat > /etc/motd << 'EOF'
Welcome to ClarityOS!

EOF

### Default Hostname
echo "clarityos" > /etc/hostname

### GRUB Distributor (only if grub config exists)
if [ -f /etc/default/grub ]; then
    sed -i 's/GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="ClarityOS"/' /etc/default/grub
else
    # Create the file if it doesn't exist
    mkdir -p /etc/default
    echo 'GRUB_DISTRIBUTOR="ClarityOS"' > /etc/default/grub
fi

### Remove Fedora branding from various locations
rm -f /etc/fedora-release 2>/dev/null || true
rm -f /etc/system-release 2>/dev/null || true

# Create ClarityOS release file
echo "ClarityOS release 42 (COSMIC)" > /etc/clarityos-release
ln -sf /etc/clarityos-release /etc/system-release

echo "ClarityOS branding applied successfully!"
