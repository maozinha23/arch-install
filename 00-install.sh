#!/usr/bin/env bash

# Valores em MiB
readonly EFI_SIZE_MIN=400
readonly EFI_SIZE_MAX=1000
#-------------------------------------------------------------------------------
# Configura o novo sistema
chroot_setup() {
  arch-chroot -S /mnt /bin/bash -c '
    readonly CONSOLE_KEYMAP="br-abnt2"
    readonly CONSOLE_FONT="cp850-8x14"
    readonly LOCALE_LANG="pt_BR.UTF-8"
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

    # Definições do layout do teclado e fonte do console
    echo "KEYMAP=$CONSOLE_KEYMAP" > /etc/vconsole.conf
    echo "FONT=$CONSOLE_FONT" >> /etc/vconsole.conf

    # Hostname
    clear
    read -e -r -p "${PROMPT_HOSTNAME}: " hostname
    echo "$hostname" > /etc/hostname

    # NetworkManager
    systemctl enable NetworkManager.service > /dev/null

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

    # Personalização do bash
    # Integração do fzf
    echo "eval \"\$(fzf --bash)\"" >> "/home/${user}/.bashrc"

    exit
 '
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

  local -r MSG_ERR_PARTITION_CREATE='ERRO: falha ao criar partições'
  local -r MSG_ERR_PARTITION_DELETE='ERRO: falha ao deletar partições'
  local -r MSG_ERR_PARTITION_FORMAT='ERRO: falha ao formatar partições'
  local -r MSG_ERR_PARTITION_MOUNT='ERRO: falha ao montar partições'
  local disk="$1"
  local efi_size="$2"

  if ! partitions_delete "$disk"; then
    err "$MSG_ERR_PARTITION_DELETE"
    return 1
  fi

  if ! partitions_create "$disk" "$efi_size"; then
    err "$MSG_ERR_PARTITION_CREATE"
    return 1
  fi

  if ! partitions_format "$disk"; then
    err "$MSG_ERR_PARTITION_FORMAT"
    return 1
  fi

  if ! partitions_mount "$disk"; then
    err "$MSG_ERR_PARTITION_MOUNT"
    return 1
  fi

  genfstab -U /mnt >> /mnt/etc/fstab
}

# Mostra uma mensagem de erro
err() {
  echo -e "$*" >&2
}

# Finaliza a instalação
finish_install() {
  local -r MSG_INFO_INSTALL_COMPLETE='Instalação concluída'
  local -r PROMPT_RESTART='Pressione qualquer tecla para reiniciar...'

  echo -e "\n${MSG_INFO_INSTALL_COMPLETE}\n"
  read -n 1 -r -s -p "$PROMPT_RESTART"

  umount -R /mnt
  reboot
}

# Obtém (do usuário) o nome do disco a ser usado na instalação
get_disk() {
  local -r PROMPT_DISK='Escolha o disco para instalação'
  local disk

  show_disks
  read -e -r -p "${PROMPT_DISK}: " disk

  echo "$disk"
}

# Obtém (do usuário) o tamanho da partição EFI em MiB
get_efi_size() {
  local -r PROMPT_EFI="Escolha o tamanho (${EFI_SIZE_MIN}-${EFI_SIZE_MAX} MiB) da partição de boot (EFI)"
  local efi_size

  read -e -r -p "${PROMPT_EFI}: " efi_size

  echo "$efi_size"
}

# Obtém o nome do pacote referente ao microcode do dispositivo (AMD/Intel)
get_package_microcode() {
  local -r MICROCODE_AMD='amd-ucode'
  local -r MICROCODE_INTEL='intel-ucode'

  [[ "$(lscpu | grep --ignore-case --count 'amd')" -gt 0 ]] \
    && echo  "$MICROCODE_AMD" \
    || echo "$MICROCODE_INTEL"
}

# Verifica se está conectado na internet
is_connected() {
  local -r COUNT=2
  # IP do DNS público do Google
  local -r HOST='8.8.8.8'
  local -r TIMEOUT=5

  ping -c "$COUNT" -W "$TIMEOUT" "$HOST" > /dev/null 2>&1
}

# Verifica se o disco selecionado é um dispositivo válido
# $1: disco selecionado (hda, sdb, nvme0n1, etc)
is_disk_valid() {
  [[ -z "$1" ]] && return 1

  local disk="$1"

  [[ -b "/dev/$disk" ]]
}

# Verifica se o tamanho em MiB escolhido para a partição EFI é válido
# $1: valor inteiro positivo em MiB
is_efi_size_valid() {
  [[ -z "$1" ]] && return 1

  local -i efi_size="$1"

  [[ "$efi_size" =~ ^[0-9]+$ ]] \
    && (( efi_size >= EFI_SIZE_MIN && efi_size <= EFI_SIZE_MAX ))
}

# Obtém a confirmação do usuário se o esquema de partições está correto
# $1: disco selecionado (hda, sdb, nvme0n1, etc)
# $2: tamanho em MiB da partição EFI
is_partition_scheme_valid() {
  [[ -z "$1" || -z "$2" ]] && return 1

  local -r MSG_INFO_DISK_PARTITION='O sistema será instalado conforme o esquema de partições abaixo:'
  local -r MSG_WARN_DISK_PARTITION='AVISO: TODOS OS DADOS DO DISCO SERÃO PERDIDOS!'
  local -r OPTION_CONFIRM='s'
  local -r PROMPT_CONFIRM='Deseja continuar? (s)im/(n)ão'
  local disk="$1"
  local efi_size="$2"

  echo -e "\n$MSG_INFO_DISK_PARTITION"
  show_partition_scheme "$disk" "$efi_size"
  echo -e "\n${MSG_WARN_DISK_PARTITION}\n"
  read -e -r -p "${PROMPT_CONFIRM}: "

  [[ "${REPLY,,}" == "$OPTION_CONFIRM" ]]
}

# Instala os pacotes do sistema
packages_install() {
  # Contém o array PACKAGE_LIST_BASE com o nome dos pacotes a serem instalados
  source "$(pwd)/packages-base" || return 1

  local cpu_microcode
  local pkg_list

  cpu_microcode="$(get_package_microcode)" || return 1
  pkg_list=("${PACKAGE_LIST_BASE[@]}" "$cpu_microcode")

  pacstrap -K /mnt "${pkg_list[@]}"
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

  mount "/dev/${disk}2" /mnt &&
  mount --options umask=0077 --mkdir "/dev/${disk}1" /mnt/boot
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
  lsblk --output NAME,MODEL,SIZE,FSUSED,FSUSE%,FSTYPE,MOUNTPOINTS >&2
}

# Mostra o esquema de partições a ser usado na instalação
# $1: disco selecionado (hda, sdb, nvme0n1, etc)
# $2: tamanho em MiB da partição EFI
show_partition_scheme() {
  [[ -z "$1" || -z "$2" ]] && return 1

  local -r COLOR_HIGHLIGHT=$'\e[36m'
  local -r COLOR_RESET=$'\e[0m'
  local disk="$1"
  local efi_size="$2"

  cat <<EOF
Tipo: GPT
Dispositivo: ${COLOR_HIGHLIGHT}${disk}${COLOR_RESET}
${COLOR_HIGHLIGHT}${disk}1${COLOR_RESET}: Boot (EFI) - FAT32 - tamanho: ${COLOR_HIGHLIGHT}${efi_size}${COLOR_RESET} MiB
${COLOR_HIGHLIGHT}${disk}2${COLOR_RESET}: Sistema    - ext4  - tamanho: resto do disco
EOF
}
#-------------------------------------------------------------------------------
main() {
  local -r CONSOLE_FONT='cp850-8x14'
  local -r KEYBOARD_LAYOUT='br-abnt2'

  local -r MSG_ERR_EFI_SIZE='ERRO: tamanho inválido para a partição EFI'
  local -r MSG_ERR_DEVICE_INVALID='ERRO: disco inválido'
  local -r MSG_ERR_DISK_PREPARE='ERRO: falha ao preparar o disco para instalação'
  local -r MSG_ERR_INTERNET='ERRO: não foi possível conectar à internet'
  local -r MSG_ERR_INSTALL='ERRO: instalação cancelada'
  local -r MSG_ERR_PACKAGE_INSTALL='ERRO: falha ao instalar os pacotes do sistema'

  clear
  set_keyboard_layout "$KEYBOARD_LAYOUT"
  set_console_font "$CONSOLE_FONT"

  if ! is_connected; then
    err "$MSG_ERR_INTERNET" "\n$MSG_ERR_INSTALL"
    return 1
  fi

  disk="$(get_disk)"

  if ! is_disk_valid "$disk"; then
    err "$MSG_ERR_DEVICE_INVALID" "\n$MSG_ERR_INSTALL"
    return 1
  fi

  efi_size="$(get_efi_size)"

  if ! is_efi_size_valid "$efi_size"; then
    err "$MSG_ERR_EFI_SIZE" "\n$MSG_ERR_INSTALL"
    return 1
  fi

  if ! is_partition_scheme_valid "$disk" "$efi_size"; then
    err "$MSG_ERR_INSTALL"
    return 1
  fi

  if ! disk_prepare "$disk" "$efi_size"; then
    err "$MSG_ERR_DISK_PREPARE" "\n$MSG_ERR_INSTALL"
    return 1
  fi

  if ! packages_install; then
    err "$MSG_ERR_PACKAGE_INSTALL" "\n$MSG_ERR_INSTALL"
    return 1
  fi

  if ! chroot_setup; then
    err "$MSG_ERR_INSTALL"
    return 1
  fi

  finish_install
}

main "$@"
