#!/bin/sh

#-------------------------------------------------------------------------------
# Funções
#-------------------------------------------------------------------------------
# Verifica a conectividade com a internet
is_connected() {
  # IP do DNS público do Google
  host='8.8.8.8'
  count=2
  timeout=5

  ping -c "${count}" -W "${timeout}" "${host}" > /dev/null 2>&1
}

# Verifica se algum dispositivo de rede wireless foi detectado
is_wifi_detected() {
  nmcli device status | grep --quiet 'wifi'
}
#-------------------------------------------------------------------------------
# Internet
#-------------------------------------------------------------------------------
# Se não foi possível conectar à internet por uma interface ethernet, tenta
# através de uma interface wireless
printf '\nConectando à internet ...\n'

if ! is_connected && is_wifi_detected; then
  printf 'Não foi possível acessar a internet através de conexão cabeada\n\n'

  nmcli device wifi list
  printf '\nEscolha a rede sem fio: '
  read -r ssid

  printf 'Digite a senha: '
  stty -echo
  read -r password
  stty echo

  printf '\nTentando conectar-se a rede %s (10s de espera)...\n' "${ssid}"
  nmcli device wifi connect "${ssid}" password "${password}" && sleep 10
fi

# Finaliza o script se não foi possível conectar à internet
if ! is_connected; then
  printf '\nNão foi possível conectar à internet.\n\
O script de instalação será encerrado.\n'
  exit 1
fi
#-------------------------------------------------------------------------------
# Instalação
#-------------------------------------------------------------------------------
# Aplicações para terminal
# File archiver for extremely high compression
pkg_list="${pkg_list} 7zip"
# Download utility that supports HTTP(S), FTP, BitTorrent, and Metalink
pkg_list="${pkg_list} aria2"
# TUI for managing bluetooth devices
pkg_list="${pkg_list} bluetui"
# Lightweight brightness control tool
pkg_list="${pkg_list} brightnessctl"
# A monitor of system resources, bpytop ported to C++
pkg_list="${pkg_list} btop"
# Image-to-text converter supporting a wide range of symbols and palettes,
# transparency, animations, etc.
pkg_list="${pkg_list} chafa"
# DOS filesystem utilities
pkg_list="${pkg_list} dosfstools"
# Ext2/3/4 filesystem utilities
pkg_list="${pkg_list} e2fsprogs"
# Command-line fuzzy finder
pkg_list="${pkg_list} fzf"
# An interpreter for the PostScript language
pkg_list="${pkg_list} ghostscript"
# the fast distributed version control system
pkg_list="${pkg_list} git"
# An image viewing/manipulation program
pkg_list="${pkg_list} imagemagick"
# OpenJDK Java __ full runtime environment
pkg_list="${pkg_list} jre-openjdk"
# Command-line JSON processor
pkg_list="${pkg_list} jq"
# A terminal file manager inspired by ranger
pkg_list="${pkg_list} lf"
# Multi-purpose desktop calculator
pkg_list="${pkg_list} libqalculate"
# Disk usage analyzer with an ncurses interface
pkg_list="${pkg_list} ncdu"
# NTFS filesystem driver and utilities
pkg_list="${pkg_list} ntfs-3g"
# SSH protocol implementation for remote login, command execution and file
# transfer
pkg_list="${pkg_list} openssh"
# Reader and rewriter of EXIF information that supports raw files
pkg_list="${pkg_list} perl-image-exiftool"
# Low-latency audio/video router and processor - JACK replacement
pkg_list="${pkg_list} pipewire-jack"
# Low-latency audio/video router and processor - PulseAudio replacement
pkg_list="${pkg_list} pipewire-pulse"
# CLI and curses mixer for pulseaudio
pkg_list="${pkg_list} pulsemixer"
# Manage installation of multiple softwares in the same directory tree
pkg_list="${pkg_list} stow"
# Command line trashcan (recycle bin) interface
pkg_list="${pkg_list} trash-cli"
# A collection of USB tools to query connected USB devices
pkg_list="${pkg_list} usbutils"
# Manage user directories like ~/Desktop and ~/Music
pkg_list="${pkg_list} xdg-user-dirs"
# A youtube-dl fork with additional features and fixes
pkg_list="${pkg_list} yt-dlp"
# External JavaScript for yt-dlp supporting many runtimes
pkg_list="${pkg_list} yt-dlp-ejs"
# A very advanced and programmable command interpreter (shell) for UNIX
pkg_list="${pkg_list} zsh"

# Window Manager e aplicações relacionadas
# Customizable and lightweight notification-daemon
pkg_list="${pkg_list} dunst"
# Screenshot utility for Wayland
pkg_list="${pkg_list} grim"
# A window switcher, application launcher and dmenu replacement
pkg_list="${pkg_list} rofi"
# Select a region in a Wayland compositor
pkg_list="${pkg_list} slurp"
# Tiling Wayland compositor and replacement for the i3 window manager
pkg_list="${pkg_list} sway"
# Idle management daemon for Wayland
pkg_list="${pkg_list} swayidle"
# Screen locker for Wayland
pkg_list="${pkg_list} swaylock"
# Highly customizable Wayland bar for Sway and Wlroots based compositors
pkg_list="${pkg_list} waybar"
# A tool for debugging wayland events on a Wayland window, analagous to the X11
# tool xev
pkg_list="${pkg_list} wev"
# Command-line copy/paste utilities for Wayland
pkg_list="${pkg_list} wl-clipboard"
# Utility to manage outputs of a Wayland compositor
pkg_list="${pkg_list} wlr-randr"

# Aplicações para interface gráfica: Sistema
# Fast, lightweight, and minimalistic Wayland terminal emulator
pkg_list="${pkg_list} foot"
# Removable disk automounter using udisks
pkg_list="${pkg_list} udiskie"

# Aplicações para interface gráfica: Acessórios
# 
# pkg_list="${pkg_list} "

# Aplicações para interface gráfica: Internet
# Fast, Private & Safe Web Browser
pkg_list="${pkg_list} firefox"
# Portuguese (Brazilian) language pack for Firefox
pkg_list="${pkg_list} firefox-i18n-pt-br"

# Aplicações para interface gráfica: Imagem
# GNU Image Manipulation Program
pkg_list="${pkg_list} gimp"
# A lightweight image viewer for Wayland display servers
pkg_list="${pkg_list} swayimg"

# Aplicações para interface gráfica: Multimídia
# a free, open source, and cross-platform media player
pkg_list="${pkg_list} mpv"

# Aplicações para interface gráfica: Escritório
# LibreOffice branch which contains new features and program enhancements
pkg_list="${pkg_list} libreoffice-fresh"
# Portuguese (Brasil) language pack for LibreOffice Fresh
pkg_list="${pkg_list} libreoffice-fresh-pt-br"

# Temas, ícones, cursores e fontes
# Google Noto TTF fonts
pkg_list="${pkg_list} noto-fonts"
# Google Noto CJK fonts
pkg_list="${pkg_list} noto-fonts-cjk"
# Google Noto Color Emoji font
pkg_list="${pkg_list} noto-fonts-emoji"
# Monospace bitmap font (for X11 and console)
pkg_list="${pkg_list} terminus-font"
# Bitstream Vera fonts
pkg_list="${pkg_list} ttf-bitstream-vera"
# A serif font family metric-compatible with Cambria font family
pkg_list="${pkg_list} ttf-caladea"
# Google's Carlito font
pkg_list="${pkg_list} ttf-carlito"
# Chrome OS core fonts
pkg_list="${pkg_list} ttf-croscore"
# Font family based on the Bitstream Vera Fonts with a wider range of characters
pkg_list="${pkg_list} ttf-dejavu"
# Font family which aims at metric compatibility with Arial, Times New Roman,
# and Courier New
pkg_list="${pkg_list} ttf-liberation"
# Patched font Terminus (Terminess) from nerd fonts library
pkg_list="${pkg_list} ttf-terminus-nerd"

# Instala a lista de pacotes
sudo pacman --sync --refresh --sysupgrade --noconfirm ${pkg_list}

# Instalação do gerenciador de pacotes para AUR
# Yet another yogurt. Pacman wrapper and AUR helper written in go. Pre-compiled
git clone https://aur.archlinux.org/yay-bin.git
if (
  cd yay-bin || exit 1
  makepkg --syncdeps --install --noconfirm
); then
  rm -r "${HOME}"/yay-bin
fi

# An open source cross-platform alternative to AirDrop
aur_pkg_list="${aur_pkg_list} localsend-bin"

# Instala a lista de pacotes da AUR
yay -S --noconfirm --quiet ${aur_pkg_list}

# Verificador ortográfico para Libreoffice
curl --remote-name 'https://pt-br.libreoffice.org/assets/Uploads/PT-BR-Documents/VERO/VeroptBR3215AOC.oxt'
unopkg add VeroptBR3215AOC.oxt
rm VeroptBR3215AOC.oxt
#-------------------------------------------------------------------------------
# Personalização
#-------------------------------------------------------------------------------
# Clona o repositório do Github que contém arquivos de configuração
cd "${HOME}" || exit 1
git clone https://github.com/maozinha23/.dotfiles

# Cria links simbólicos para os arquivos de configuração
rm "${HOME}"/.bashrc "${HOME}"/.bash_logout
# dotfiles comuns a todos os sistemas
cd "${HOME}"/.dotfiles/common \
  && ls | xargs stow --target="${HOME}" \
  || exit 1

# Cria os diretórios de usuário em $HOME
mkdir --parents "${HOME}"/Documents "${HOME}"/Downloads "${HOME}"/Media
xdg-user-dirs-update

# Altera a fonte do tty
sudo printf 'FONT=ter-118n' >> /etc/vconsole.conf

# Ativa cores e exibição de pacotes por colunas no pacman
sudo sed --in-place 's/^#\(Color\)/\1/' /etc/pacman.conf
sudo sed --in-place 's/^#\(VerbosePkgLists\)/\1/' /etc/pacman.conf

# Ativa o serviço de bluetooth
sudo systemctl enable --now bluetooth.service
