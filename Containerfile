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
## Add ALL necessary Fedora repos for COSMIC
RUN curl -Lo /etc/yum.repos.d/fedora.repo \
    https://src.fedoraproject.org/rpms/fedora-repos/raw/f42/f/fedora.repo && \
    curl -Lo /etc/yum.repos.d/fedora-updates.repo \
    https://src.fedoraproject.org/rpms/fedora-repos/raw/f42/f/fedora-updates.repo && \
    curl -Lo /etc/yum.repos.d/fedora-updates-testing.repo \
    https://src.fedoraproject.org/rpms/fedora-repos/raw/f42/f/fedora-updates-testing.repo

## Install COSMIC desktop environment - manual package list since group isn't available
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
    xdg-desktop-portal-cosmic

### Install Essential Packages
RUN rpm-ostree install \
    cups \
    system-config-printer \
    fwupd \
    vim \
    nano \
    fastfetch \
    unzip \
    zip \
    tree \
    tmux \
    bash-completion

### Install System Utilities
RUN rpm-ostree install \
    nmap \
    traceroute \
    whois \
    bind-utils \
    iotop \
    lsof \
    gnome-disk-utility \
    pavucontrol

### Install Plymouth for Boot Splash
RUN rpm-ostree install \
    plymouth \
    plymouth-theme-spinner

### Apply ClarityOS Branding
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/branding.sh

### Custom Default Wallpaper - Dark wallpaper for both themes
# Ensure target directory exists first
RUN mkdir -p /usr/share/backgrounds/f42/default

# Use dark wallpaper for both day and night since COSMIC doesn't switch automatically
COPY build_files/wallpapers/default-dark.jxl /usr/share/backgrounds/f42/default/f42-01-day.jxl
COPY build_files/wallpapers/default-dark.jxl /usr/share/backgrounds/f42/default/f42-01-night.jxl

### Configure Flatpak
RUN rpm-ostree install flatpak && \
    mkdir -p /var/lib/flatpak

### Create first-boot Flatpak installer script
RUN mkdir -p /etc/skel/.config/autostart

COPY build_files/clarityos-first-boot.sh /usr/bin/clarityos-first-boot.sh
RUN chmod +x /usr/bin/clarityos-first-boot.sh

COPY build_files/clarityos-first-boot.desktop /etc/skel/.config/autostart/clarityos-first-boot.desktop

### Create useful bash aliases for all users
COPY build_files/clarityos-aliases.sh /tmp/clarityos-aliases.sh
RUN cat /tmp/clarityos-aliases.sh >> /etc/skel/.bashrc && rm /tmp/clarityos-aliases.sh

### Configure COSMIC Dock - Pin Apps for New Users
RUN mkdir -p /etc/skel/.config/cosmic/com.system76.CosmicAppList/v1
COPY build_files/favorites.json /etc/skel/.config/cosmic/com.system76.CosmicAppList/v1/favorites

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
