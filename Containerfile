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

### COSMIC Desktop Installation
## base-main doesn't have Fedora repos enabled by default
## Add Fedora repos so we can install COSMIC packages
RUN curl -Lo /etc/yum.repos.d/fedora.repo \
    https://src.fedoraproject.org/rpms/fedora-repos/raw/f42/f/fedora.repo && \
    curl -Lo /etc/yum.repos.d/fedora-updates.repo \
    https://src.fedoraproject.org/rpms/fedora-repos/raw/f42/f/fedora-updates.repo

## Install COMPLETE COSMIC desktop environment from Fedora repos
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
    cosmic-portal \
    xdg-desktop-portal-cosmic

### Install Essential Packages
RUN rpm-ostree install \
    cups \
    system-config-printer \
    fwupd \
    vim \
    nano \
    unzip \
    zip \
    p7zip \
    p7zip-plugins \
    fastfetch

### Additional System Utilities
RUN rpm-ostree install \
    nmap \
    traceroute \
    whois \
    bind-utils \
    iotop \
    iftop \
    nethogs \
    lsof \
    gnome-disk-utility \
    bluez-tools \
    pavucontrol

### Apply ClarityOS Branding
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/branding.sh

### Custom Default Wallpaper - Dark wallpaper for both themes
# Use dark wallpaper for both day and night since COSMIC doesn't switch automatically
COPY build_files/wallpapers/default-dark.jxl /usr/share/backgrounds/f42/default/f42-01-day.jxl
COPY build_files/wallpapers/default-dark.jxl /usr/share/backgrounds/f42/default/f42-01-night.jxl

### Install Flatpak and Configure Flathub
RUN rpm-ostree install flatpak && \
    mkdir -p /var/lib/flatpak && \
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo --system

### Install Essential Flatpak Applications
RUN flatpak install -y --system flathub \
    io.github.kolunmi.Bazaar \
    org.libreoffice.LibreOffice \
    org.gimp.GIMP \
    org.videolan.VLC \
    org.inkscape.Inkscape \
    org.audacityteam.Audacity \
    com.github.tchx84.Flatseal

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
