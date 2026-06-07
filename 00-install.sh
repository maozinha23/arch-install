#!/usr/bin/env bash

readonly COLOR_HIGHLIGHT=$'\e[36m'
readonly COLOR_RESET=$'\e[0m'
readonly CONSOLE_FONT='cp850-8x14'
readonly KEYBOARD_LAYOUT='br-abnt2'
#-------------------------------------------------------------------------------
# Configura o novo sistema
chroot_setup() {
  arch-chroot -S /mnt /bin/bash -c '
    readonly CONSOLE_KEYMAP="br-abnt2"
    readonly CONSOLE_FONT="cp850-8x14"
    readonly LOCALE_LANG="pt_BR.UTF-8"
    readonly LOCALE_LC_MESSAGES="C.UTF-8"
    readonly LOCALTIME="/usr/share/zoneinfo/America/Sao_Paulo"
    readonly PROMPT_HOSTNAME="Nome do host"
    readonly PROMPT_USER="Nome do usuário"

    # Horário
    ln --symbolic --force "$LOCALTIME" /etc/localtime
    hwclock --systohc
    systemctl enable systemd-timesyncd.service

    # Localização
    sed --in-place "s/^#\(${LOCALE_LANG}\)/\1/" /etc/locale.gen
    locale-gen
    echo "LANG=$LOCALE_LANG" > /etc/locale.conf
    echo "LC_MESSAGES=$LOCALE_LC_MESSAGES" >> /etc/locale.conf

    # Definições do layout do teclado e fonte do console
    echo "KEYMAP=$CONSOLE_KEYMAP" > /etc/vconsole.conf
    echo "FONT=$CONSOLE_FONT" >> /etc/vconsole.conf

    # Hostname
    read -e -r -p "${PROMPT_HOSTNAME}: " hostname
    echo "$hostname" > /etc/hostname

    # NetworkManager
    systemctl enable NetworkManager.service

    # Criação do usuário
    read -e -r -p "${PROMPT_USER}: " user
    useradd --create-home --groups wheel "$user"

    while true; do
      passwd "$user" && break
    done

    # Permite que usuários do grupo "wheel" executem qualquer comando
    sed --in-place "s/^# *\(%wheel ALL=(ALL:ALL) ALL\)/\1/" /etc/sudoers

    # Desabilita o login do usuário root
    passwd --lock root

    # Gerenciador de boot (systemd-boot)
    bootctl install

    cat <<EOF > /boot/loader/loader.conf
default arch.conf
timeout 0
console-mode keep
EOF

    uuid_root=$(findmnt --noheadings --output UUID /)
    cat <<EOF > /boot/loader/entries/arch.conf
title Arch Linux
linux /vmlinuz-linux
initrd /initramfs-linux.img
options root=UUID=$uuid_root rw quiet loglevel=3
EOF

    exit
  '
  umount -R /mnt
}

# Prepara o disco selecionado para a instalação, fazendo as seguintes operações
# sobre as partições:
# 1) Deleta
# 2) Cria
# 3) Formata
# 4) Monta
# Depois gera o "fstab"
#
# $1: disco selecionado (hda, sdb, nvme0n1, etc)
# $2: tamanho em MiB da partição EFI
disk_prepare() {
  [[ -z "$1" || -z "$2" ]] && return 1

  local disk="$1"
  local efi_size="$2"

  partitions_delete "$disk"
  partitions_create "$disk" "$efi_size"
  partitions_format "$disk"
  partitions_mount "$disk"

  # Definição de montagem para as partições de sistema e boot
  genfstab -U /mnt > /mnt/etc/fstab
}

# Mostra uma mensagem de erro
err() {
  echo "$*" >&2
}

# Obtém (do usuário) o nome do disco a ser usado na instalação
get_disk() {
  local -r PROMPT_DISK='Escolha o disco para instalação'
  local disk

  read -e -r -p "\n${PROMPT_DISK}: " disk

  echo "$disk"
}

# Obtém (do usuário) o tamanho da partição EFI em MiB
get_efi_size() {
  local -r PROMPT_EFI='Escolha o tamanho (em MiB) da partição de boot (EFI)'
  local efi_size

  read -e -r -p "\n${PROMPT_EFI}: " efi_size

  echo "$efi_size"
}

# Verifica se está conectado na internet
is_connected() {
  local -r COUNT=2
  # IP do DNS público do Google
  local -r HOST='8.8.8.8'
  local -r TIMEOUT=5

  ping -c "$COUNT" -W "$TIMEOUT" "$HOST" > /dev/null 2>&1
}

# Instala os pacotes do sistema
packages_install() {
  local pkg_list=''
  local cpu_microcode

  # Verifica se o sistema possui um CPU AMD ou Intel para instalar o microcode
  # amd-ucode : Microcode update image for AMD CPUs
  # intel-ucode : Microcode update files for Intel CPUs
  [[ "$(lscpu | grep --ignore-case --count 'amd')" -gt 0 ]] \
    && cpu_microcode='amd-ucode' \
    || cpu_microcode='intel-ucode'

  pkg_list="$cpu_microcode"

  # Minimal package set to define a basic Arch Linux installation
  pkg_list="$pkg_list base"
  # Basic tools to build Arch Linux packages
  pkg_list="$pkg_list base-devel"
  # A monitor of system resources, bpytop ported to C++
  pkg_list="$pkg_list btop"
  # DOS filesystem utilities
  pkg_list="$pkg_list dosfstools"
  # Ext2/3/4 filesystem utilities
  pkg_list="$pkg_list e2fsprogs"
  # Linux user-space application to modify the EFI Boot Manager
  pkg_list="$pkg_list efibootmgr"
  # exFAT filesystem userspace utilities for the Linux Kernel exfat driver
  pkg_list="$pkg_list exfatprogs"
  # Command-line fuzzy finder
  pkg_list="$pkg_list fzf"
  # the fast distributed version control system
  pkg_list="$pkg_list git"
  # The Linux kernel and modules
  pkg_list="$pkg_list linux"
  # Firmware files for Linux - Default set
  pkg_list="$pkg_list linux-firmware"
  # A utility for reading man pages
  pkg_list="$pkg_list man-db"
  # Linux man pages
  pkg_list="$pkg_list man-pages"
  # Pico editor clone with enhancements
  pkg_list="$pkg_list nano"
  # Network connection manager and user applications
  pkg_list="$pkg_list networkmanager"
  # SSH protocol implementation for remote login, command execution and file
  # transfer
  pkg_list="$pkg_list openssh"
  # Command line trashcan (recycle bin) interface
  pkg_list="$pkg_list trash-cli"
  # A collection of USB tools to query connected USB devices
  pkg_list="$pkg_list usbutils"

  pacstrap -K /mnt $pkg_list
}

# Cria as partições de boot e do sistema no disco selecionado
# $1: disco selecionado (hda, sdb, nvme0n1, etc)
# $2: tamanho em MiB da partição EFI
partitions_create() {
  [[ -z "$1" || -z "$2" ]] && return 1

  # GUID para GPT
  local -r GUID_EFI='C12A7328-F81F-11D2-BA4B-00A0C93EC93B'
  local -r GUID_LINUX_FS='0FC63DAF-8483-4772-8E79-3D69D8477DE4'
  local disk="$1"
  local efi_size="$2"

  cat <<EOF | sfdisk "/dev/${disk}"
label: gpt
device: /dev/${disk}
unit: sectors
first-lba: 2048
sector-size: 512

/dev/${disk}1 : start= , size=${efi_size}M, type=$GUID_EFI
/dev/${disk}2 : start= , size= , type=$GUID_LINUX_FS
EOF
}

# Deleta todas as partições do disco selecionado
# $1: disco selecionado (hda, sdb, nvme0n1, etc)
partitions_delete() {
  [[ -z "$1" ]] && return 1

  local disk="$1"

  sfdisk --delete "/dev/${disk}"
}

# Formata as partições de boot e sistema do disco selecionado
# Boot (EFI): FAT32
# Sistema: ext4
# $1: disco selecionado (hda, sdb, nvme0n1, etc)
partitions_format() {
  [[ -z "$1" ]] && return 1

  local disk="$1"

  mkfs.fat -F 32 "/dev/${disk}1" && mkfs.ext4 -F "/dev/${disk}2"
}

# Monta as partições de boot e sistema do disco selecionado
# Boot (EFI): /mnt/boot
# Sistema: /mnt
# $1: disco selecionado (hda, sdb, nvme0n1, etc)
partitions_mount() {
  [[ -z "$1" ]] && return 1

  local disk="$1"

  mount "/dev/${disk}2" /mnt \
    && mount --options umask=0077 --mkdir "/dev/${disk}1" /mnt/boot
}

# Define a fonte do console
# $1: fonte
set_console_font() {
  [[ -z "$1" ]] && return 1

  local font="$1"

  setfont -d "$font"
}

# Define o layout do teclado
# $1: layout do teclado
set_keyboard_layout() {
  [[ -z "$1" ]] && return 1

  local layout="$1"

  loadkeys "$layout"
}

# Mostra informações sobre os discos detectados no sistema
show_disks() {
  lsblk --output NAME,MODEL,SIZE,FSUSED,FSUSE%,FSTYPE,MOUNTPOINTS
}

# Mostra o esquema de partições a ser usado na instalação
# $1: disco selecionado (hda, sdb, nvme0n1, etc)
# $2: tamanho em MiB da partição EFI
show_partition_schema() {
  [[ -z "$1" || -z "$2" ]] && return 1

  local disk="$1"
  local efi_size="$2"

  cat <<EOF
Tipo: GPT
Dispositivo: ${COLOR_HIGHLIGHT}${disk}${COLOR_RESET}
${COLOR_HIGHLIGHT}${disk}1${COLOR_RESET}: EFI System       - tamanho: ${COLOR_HIGHLIGHT}${efi_size}${COLOR_RESET} MiB
${COLOR_HIGHLIGHT}${disk}2${COLOR_RESET}: Linux filesystem - tamanho: resto do disco
EOF
}
#-------------------------------------------------------------------------------
main() {
  local -r MSG_ERR_INTERNET='ERRO: não foi possível conectar à internet'
  local -r MSG_ERR_INSTALL='ERRO: instalação cancelada'
  local -r MSG_INFO_DISK_PARTITION='O sistema será instalado conforme o esquema de partições abaixo:'
  local -r MSG_INFO_INSTALL_COMPLETE='Instalação concluída'
  local -r MSG_WARN_DISK_PARTITION='AVISO: TODOS OS DADOS DO DISCO SERÃO PERDIDOS!'
  local -r OPTION_CONFIRM='s'
  local -r PROMPT_CONFIRM='Deseja continuar? (s)im/(n)ão'
  local -r PROMPT_RESTART='Pressione qualquer tecla para reiniciar...'

  set_keyboard_layout "$KEYBOARD_LAYOUT"
  set_console_font "$CONSOLE_FONT"

  # Finaliza a instalação se não foi possível conectar à internet
  if ! is_connected; then
    err "$MSG_ERR_INTERNET"
    err "$MSG_ERR_INSTALL"
    return 1
  fi

  clear
  show_disks
  disk="$(get_disk)"
  efi_size="$(get_efi_size)"

  echo -e "\n$MSG_INFO_DISK_PARTITION"
  show_partition_schema "$disk" "$efi_size"
  echo -e "\n${MSG_WARN_DISK_PARTITION}\n"
  read -e -r -p "${PROMPT_CONFIRM} : "

  # Finaliza a instalação se o usuário não aceitar o particionamento/formatação
  # do disco
  if [[ ! "${REPLY,,}" == "$OPTION_CONFIRM" ]]; then
    err "$MSG_ERR_INSTALL"
    return 1
  fi

  disk_prepare "$disk" "$efi_size"
  packages_install
  chroot_setup

  echo "$MSG_INFO_INSTALL_COMPLETE"
  read -n 1 -r -s -p "$PROMPT_RESTART"

  reboot
}

main "$@"
