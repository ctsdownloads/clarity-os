# Allow build scripts to be referenced without being copied into the final image
FROM scratch AS ctx
COPY build_files /

# Base Image - ublue base-main + COSMIC from Fedora
FROM ghcr.io/ublue-os/base-main:42

### Setup Signature Verification
COPY cosign.pub /etc/pki/containers/clarity-os.pub
RUN mkdir -p /etc/containers/registries.d && \
    printf 'docker:\n  ghcr.io/ctsdownloads/clarity-os:\n    use-sigstore-attachments: true\n' \
    > /etc/containers/registries.d/ghcr-ctsdownloads.yaml

### Configure bootc to verify signatures automatically for updates
COPY build_files/policy.json /etc/containers/policy.json

### COSMIC Desktop Installation
## base-main doesn't have Fedora repos enabled by default
## Add Fedora repos so we can install COSMIC packages
RUN curl -Lo /etc/yum.repos.d/fedora.repo \
    https://src.fedoraproject.org/rpms/fedora-repos/raw/f42/f/fedora.repo && \
    curl -Lo /etc/yum.repos.d/fedora-updates.repo \
    https://src.fedoraproject.org/rpms/fedora-repos/raw/f42/f/fedora-updates.repo

## Install COSMIC desktop environment (with graceful failure handling)
RUN rpm-ostree install \
    cosmic-session \
    cosmic-comp \
    cosmic-greeter \
    cosmic-panel \
    cosmic-launcher \
    cosmic-settings \
    cosmic-settings-daemon \
    cosmic-files \
    cosmic-term \
    cosmic-bg \
    cosmic-applets \
    cosmic-notifications \
    cosmic-osd \
    cosmic-workspaces \
    cosmic-screenshot \
    cosmic-app-library \
    cosmic-edit \
    cosmic-store \
    cosmic-player \
    cosmic-wallpapers \
    cosmic-icon-theme \
    cosmic-idle \
    xdg-desktop-portal-cosmic \
    || echo "Some COSMIC packages failed to install, continuing..."

### Install Essential Packages (critical - must succeed)
RUN rpm-ostree install \
    cups \
    system-config-printer \
    fwupd \
    vim \
    nano \
    fastfetch

### Install Archive Tools (with error handling)
RUN rpm-ostree install \
    unzip \
    zip \
    p7zip \
    p7zip-plugins \
    || echo "Some archive tools failed, continuing..."

### Install System Utilities (optional - graceful failure)
RUN rpm-ostree install nmap || true
RUN rpm-ostree install traceroute || true
RUN rpm-ostree install whois || true
RUN rpm-ostree install bind-utils || true
RUN rpm-ostree install iotop || true
RUN rpm-ostree install lsof || true
RUN rpm-ostree install gnome-disk-utility || true
RUN rpm-ostree install pavucontrol || true
RUN rpm-ostree install powertop || true

### Install QoL Utilities (optional - graceful failure)
RUN rpm-ostree install bat || true
RUN rpm-ostree install tmux || true
RUN rpm-ostree install tree || true
RUN rpm-ostree install bash-completion || true

### Apply ClarityOS Branding
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/branding.sh

### Custom Default Wallpaper - Dark wallpaper for both themes
# Use dark wallpaper for both day and night since COSMIC doesn't switch automatically
COPY build_files/wallpapers/default-dark.jxl /usr/share/backgrounds/f42/default/f42-01-day.jxl
COPY build_files/wallpapers/default-dark.jxl /usr/share/backgrounds/f42/default/f42-01-night.jxl

### Configure Flatpak
RUN rpm-ostree install flatpak && \
    mkdir -p /var/lib/flatpak

### Create first-boot Flatpak installer script
RUN mkdir -p /etc/skel/.config/autostart && \
    cat > /usr/local/bin/clarityos-first-boot.sh << 'SCRIPT'
#!/bin/bash
# ClarityOS First Boot Setup

# Add Flathub if not already added
flatpak remote-add --if-not-exists --user flathub https://flathub.org/repo/flathub.flatpakrepo

# Install essential Flatpaks
flatpak install -y --user flathub \
    io.github.kolunmi.Bazaar \
    org.libreoffice.LibreOffice \
    org.gimp.GIMP \
    org.videolan.VLC \
    org.inkscape.Inkscape \
    org.audacityteam.Audacity \
    org.mozilla.Thunderbird \
    com.github.tchx84.Flatseal

# Remove this script after first run
rm -f ~/.config/autostart/clarityos-first-boot.desktop
SCRIPT

RUN chmod +x /usr/local/bin/clarityos-first-boot.sh && \
    cat > /etc/skel/.config/autostart/clarityos-first-boot.desktop << 'DESKTOP'
[Desktop Entry]
Type=Application
Name=ClarityOS First Boot Setup
Exec=/usr/local/bin/clarityos-first-boot.sh
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
DESKTOP

### Create useful bash aliases for all users
RUN cat >> /etc/skel/.bashrc << 'BASHRC'

# ClarityOS Quality of Life Aliases
alias ll='ls -lah --color=auto'
alias update='rpm-ostree update'
alias cleanup='flatpak uninstall --unused && rpm-ostree cleanup -b'
alias sysinfo='fastfetch'

BASHRC

### Configure COSMIC Dock - Pin Apps for New Users
RUN mkdir -p /etc/skel/.config/cosmic/com.system76.CosmicAppList/v1 && \
    cat > /etc/skel/.config/cosmic/com.system76.CosmicAppList/v1/favorites << 'EOF'
[
  "org.mozilla.firefox",
  "com.system76.CosmicFiles",
  "com.system76.CosmicEdit",
  "com.system76.CosmicTerm",
  "io.github.kolunmi.Bazaar",
  "com.system76.CosmicSettings",
]
EOF

### [IM]MUTABLE /opt
# RUN rm /opt && mkdir /opt

### MODIFICATIONS
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    --mount=type=cache,dst=/var/cache \
    --mount=type=cache,dst=/var/log \
    --mount=type=tmpfs,dst=/tmp \
    /ctx/build.sh
    
### LINTING
RUN bootc container lint
