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

## Install complete COSMIC desktop environment from Fedora updates repo
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
    cosmic-wallpapers \
    cosmic-icon-theme \
    xdg-desktop-portal-cosmic

### Apply ClarityOS Branding
RUN --mount=type=bind,from=ctx,source=/,target=/ctx \
    /ctx/branding.sh

### Custom Default Wallpaper
# Directly overwrite Fedora's default wallpapers with ClarityOS wallpapers
COPY build_files/wallpapers/default.jxl /usr/share/backgrounds/default.jxl
COPY build_files/wallpapers/default-dark.jxl /usr/share/backgrounds/default-dark.jxl

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
