#!/bin/sh

# Installation guide (Português)
# https://wiki.archlinux.org/title/Installation_guide_(Portugu%C3%AAs)
#-------------------------------------------------------------------------------
# Funções auxiliares
#-------------------------------------------------------------------------------
# Verifica a conectividade com a internet tentando pingar um servidor confiável
is_connected() {
  _host='8.8.8.8'  # IP do DNS público do Google
  _count=2         # Número de tentativas de ping
  _timeout=5       # Tempo limite por tentativa em segundos

  ping -c "${_count}" -W "${_timeout}" "${_host}" > /dev/null 2>&1
}
#-------------------------------------------------------------------------------
# 5 - Pós-instalação
#-------------------------------------------------------------------------------
# Conexão com a internet
printf "\nConectando à internet ...\n"

# Verifica se foi possível conectar à internet
# Se não foi possível conectar por uma interface ethernet, tenta através de uma
# interface wireless
if ! is_connected; then
  printf "Não foi possível conectar à internet.\n\
Conectando a uma rede sem fio ...\n\n"

  nmcli device wifi list

  printf "\nEscolha a rede sem fio: "
  read -r _ssid

  printf "Digite a senha: "
  stty -echo
  read -r _password
  stty echo
  printf "\n"

  printf "Tentando conectar-se a rede %s ...\n" "${_ssid}"
  nmcli device wifi connect "${_ssid}" password "${_password}"
fi

# Finaliza o script se não foi possível conectar à internet
if ! is_connected; then
  printf "\nNão foi possível conectar à internet.\n\
O script de instalação será encerrado.\n"
  exit 1
fi

# Aplicações para terminal
# File archiver for extremely high compression
pkg_list="${pkg_list} 7zip"
# Download utility that supports HTTP(S), FTP, BitTorrent, and Metalink
pkg_list="${pkg_list} aria2"
# Lightweight brightness control tool
pkg_list="${pkg_list} brightnessctl"
# Lightweight, easy to configure DNS forwarder and DHCP server
pkg_list="${pkg_list} dnsmasq"
# Lightweight video thumbnailer that can be used by file managers
pkg_list="${pkg_list} ffmpegthumbnailer"
# Command-line fuzzy finder
pkg_list="${pkg_list} fzf"
# The GNU Debugger
pkg_list="${pkg_list} gdb"
# the fast distributed version control system
pkg_list="${pkg_list} git"
# An image viewing/manipulation program
pkg_list="${pkg_list} imagemagick"
# OpenJDK Java 24 development kit
pkg_list="${pkg_list} jdk-openjdk"
# Command-line JSON processor
pkg_list="${pkg_list} jq"
# A terminal file manager inspired by ranger
pkg_list="${pkg_list} lf"
# Multi-purpose desktop calculator
pkg_list="${pkg_list} libqalculate"
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
# Systems programming language focused on safety, speed and concurrency
pkg_list="${pkg_list} rust"
# SMB Fileserver and AD Domain server
pkg_list="${pkg_list} samba"
# Manage installation of multiple softwares in the same directory tree
pkg_list="${pkg_list} stow"
# Command line trashcan (recycle bin) interface
pkg_list="${pkg_list} trash-cli"
# Command line utility which allows to display images in the terminal, written
# in C++
pkg_list="${pkg_list} ueberzugpp"
# Manage user directories like ~/Desktop and ~/Music
pkg_list="${pkg_list} xdg-user-dirs"
# A very advanced and programmable command interpreter (shell) for UNIX
pkg_list="${pkg_list} zsh"

# Window Manager e aplicações relacionadas
# Tool which allows you to compose wallpapers ("root pixmaps") for X. Fork by
# Hyriand
pkg_list="${pkg_list} hsetroot"
# Improved dynamic tiling window manager
pkg_list="${pkg_list} i3-wm"
# Lightweight compositor for X11
pkg_list="${pkg_list} picom"
# A fast and easy-to-use status bar
pkg_list="${pkg_list} polybar"
# A window switcher, application launcher and dmenu replacement
pkg_list="${pkg_list} rofi"
# Command line interface to the X11 clipboard
pkg_list="${pkg_list} xclip"
# xorg-server-common, xorg-server-devel, xorg-server-xephyr, xorg-server-xnest,
# xorg-server-xvfb
pkg_list="${pkg_list} xorg-server"
# X.Org initialisation program
pkg_list="${pkg_list} xorg-xinit"
# Use external locker as X screen saver
pkg_list="${pkg_list} xss-lock"

# Aplicações para interface gráfica: Sistema
# A cross-platform, GPU-accelerated terminal emulator
pkg_list="${pkg_list} alacritty"
# Provide a simple visual front end for XRandR 1.2
pkg_list="${pkg_list} arandr"
# GTK+ Bluetooth Manager
pkg_list="${pkg_list} blueman"
# Light-weight system monitor for X, Wayland, and other things, too
pkg_list="${pkg_list} conky"
# A QEMU setup for desktop environments
pkg_list="${pkg_list} qemu-desktop"
# Removable disk automounter using udisks
pkg_list="${pkg_list} udiskie"
# Desktop user interface for managing virtual machines
pkg_list="${pkg_list} virt-manager"

# Aplicações para interface gráfica: Acessórios
# No Nonsense Neovim Client in Rust
pkg_list="${pkg_list} neovide"
# GTK+ frontend to various command line archivers
pkg_list="${pkg_list} xarchiver"

# Aplicações para interface gráfica: Internet
# Fast, Private & Safe Web Browser
pkg_list="${pkg_list} firefox"
# Portuguese (Brazilian) language pack for Firefox
pkg_list="${pkg_list} firefox-i18n-pt-br"

# Aplicações para interface gráfica: Imagem
# Fast and light imlib2-based image viewer
pkg_list="${pkg_list} feh"
# GNU Image Manipulation Program
pkg_list="${pkg_list} gimp"

# Aplicações para interface gráfica: Multimídia
# a free, open source, and cross-platform media player
pkg_list="${pkg_list} mpv"

# Aplicações para interface gráfica: Escritório
# LibreOffice branch which contains new features and program enhancements
pkg_list="${pkg_list} libreoffice-fresh"
# Portuguese (Brasil) language pack for LibreOffice Fresh
pkg_list="${pkg_list} libreoffice-fresh-pt-br"

# Temas, ícones e fontes
# Google Noto CJK fonts
pkg_list="${pkg_list} noto-fonts-cjk"
# Papirus icon theme
pkg_list="${pkg_list} papirus-icon-theme"
# Monospace bitmap font (for X11 and console)
pkg_list="${pkg_list} terminus-font"
# Font family which aims at metric compatibility with Arial, Times New Roman,
# and Courier New
pkg_list="${pkg_list} ttf-liberation"
# Patched font Terminus (Terminess) from nerd fonts library
pkg_list="${pkg_list} ttf-terminus-nerd"
# Vanilla DMZ cursor theme
pkg_list="${pkg_list} xcursor-vanilla-dmz"

# Instala a lista de pacotes
sudo pacman --sync --refresh --sysupgrade --noconfirm ${pkg_list}

# Instalação do gerenciador de pacotes para AUR
# paru : Feature packed AUR helper
git clone https://aur.archlinux.org/paru.git
if (
  cd paru || exit 1
  makepkg --syncdeps --install
); then
  rm -r paru
fi

# The world's most popular non-default computer lockscreen
aur_pkg_list="${aur_pkg_list} i3lock-color"

# Instala a lista de pacotes da AUR
paru --sync --noconfirm ${aur_pkg_list}

# Verificador ortográfico para Libreoffice
curl --remote-name 'https://pt-br.libreoffice.org/assets/Uploads/PT-BR-Documents/VERO/VeroptBR3215AOC.oxt'
unopkg add VeroptBR3215AOC.oxt
rm VeroptBR3215AOC.oxt
#-------------------------------------------------------------------------------
# 6 - Personalização
#-------------------------------------------------------------------------------
# Clona o repositório do Github que contém arquivos de configuração
cd || exit 1
git clone https://github.com/maozinha23/.dotfiles

# Cria links simbólicos para os arquivos de configuração
rm .bashrc
rm .bash_logout
cd .dotfiles || exit 1
# stow .

# Cria os diretórios de usuário em $HOME
cd || exit 1
mkdir Documents Downloads Media
xdg-user-dirs-update

# Adiciona o usuário atual ao grupo libvirt
sudo usermod --append --groups libvirt "$(whoami)"

# Remove o script de instalação
rm -- "$0"
