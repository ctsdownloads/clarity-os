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
