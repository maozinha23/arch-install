#!/usr/bin/env bash

# Cria as partições de boot e do sistema no disco selecionado
# $1: disco selecionado (hda, sdb, nvme0n1, etc)
# $2: tamanho em MiB da partição EFI
create_partitions() {
  # GUID para GPT
  local -r GUID_EFI='C12A7328-F81F-11D2-BA4B-00A0C93EC93B'
  local -r GUID_LINUX_FS='0FC63DAF-8483-4772-8E79-3D69D8477DE4'
  local disk="$1"
  local efi_size="$2"

  is_disk_valid "$disk" || return 1
  is_efi_size_valid "$efi_size" || return 1

  cat <<EOF | sfdisk "/dev/$disk"
label: gpt
device: /dev/$disk
unit: sectors
first-lba: 2048
sector-size: 512

/dev/${disk}1 : start= , size=${efi_size}M, type=$GUID_EFI
/dev/${disk}2 : start= , size= , type=$GUID_LINUX_FS
EOF
}

# Deleta todas as partições do disco selecionado
# $1: disco selecionado (hda, sdb, nvme0n1, etc)
delete_partitions() {
  local disk="$1"

  is_disk_valid "$disk" || return 1
  partitions_exist "$disk" || return 1

  sfdisk --delete --wipe always "/dev/$disk"
}

# Formata as partições de boot e sistema do disco selecionado
# Boot (EFI): FAT32
# Sistema: ext4
# $1: disco selecionado (hda, sdb, nvme0n1, etc)
format_partitions() {
  local disk="$1"

  is_disk_valid "$disk" || return 1
  partitions_exist "$disk" || return 1

  mkfs.fat -F 32 "/dev/${disk}1" && mkfs.ext4 "/dev/${disk}2"
}

# Gera um novo fstab considerando os pontos de montagem atuais
gen_file_system_table() {
  genfstab -t UUID /mnt > /mnt/etc/fstab
}

# Obtém (do usuário) o nome do disco a ser usado na instalação
get_disk() {
  local -r PROMPT_DISK='Escolha o disco para instalação'
  local disk

  show_disks
  read -e -r -p "${PROMPT_DISK}: " disk
  is_disk_valid "$disk" || return 1

  echo "$disk"
}

# Obtém (do usuário) o tamanho da partição EFI em MiB
get_efi_size() {
  local -r PROMPT_EFI="Escolha o tamanho ($(get_efi_min_size)-$(get_efi_max_size) MiB) da partição de boot (EFI)"
  local efi_size

  read -e -r -p "${PROMPT_EFI}: " efi_size
  is_efi_size_valid "$efi_size" || return 1

  echo "$efi_size"
}

# Obtém o tamanho máximo (em MiB) para a partição EFI
get_efi_max_size() {
  local -i -r EFI_SIZE_MAX=1000

  echo "$EFI_SIZE_MAX"
}

# Obtém o tamanho mínimo (em MiB) para a partição EFI
get_efi_min_size() {
  local -i -r EFI_SIZE_MIN=400

  echo "$EFI_SIZE_MIN"
}

# Obtém os pontos de montagem do disco selecionado
# $1: array recebido como referência
# $2: disco selecionado (hda, sdb, nvme0n1, etc)
get_mountpoints() {
  [[ -z "$1" ]] && return 1

  local -n mountpoints=$1
  local disk="$2"

  is_disk_valid "$disk" || return 1

  # Desconsidera "warning" de variável não usada
  # shellcheck disable=SC2034
  readarray -t mountpoints \
    < <(lsblk --noheadings --output MOUNTPOINT "/dev/$disk" | sed '/^$/d')
}

# Verifica se o disco selecionado é um dispositivo válido
# $1: disco selecionado (hda, sdb, nvme0n1, etc)
is_disk_valid() {
  [[ -b "/dev/$1" ]]
}

# Verifica se o tamanho em MiB escolhido para a partição EFI é válido
# $1: valor inteiro positivo em MiB
is_efi_size_valid() {
  [[ "$1" =~ ^[0-9]+$ ]] || return 1

  local -i efi_size="$1"

  (( efi_size >= $(get_efi_min_size) && efi_size <= $(get_efi_max_size) ))
}

# Obtém a confirmação do usuário se o esquema de partições está correto
# $1: disco selecionado (hda, sdb, nvme0n1, etc)
# $2: tamanho em MiB da partição EFI
is_partition_scheme_valid() {
  local -r MSG_INFO_DISK_PARTITION='O sistema será instalado conforme o esquema de partições abaixo:'
  local -r MSG_WARN_DISK_PARTITION='AVISO: TODOS OS DADOS DO DISCO SERÃO PERDIDOS!'
  local -r OPTION_CONFIRM='s'
  local -r PROMPT_CONFIRM='Deseja continuar? (s)im/(n)ão'
  local disk="$1"
  local efi_size="$2"

  is_disk_valid "$disk" || return 1
  is_efi_size_valid "$efi_size" || return 1

  echo -e "\n$MSG_INFO_DISK_PARTITION"
  show_partition_scheme "$disk" "$efi_size"
  echo -e "\n${MSG_WARN_DISK_PARTITION}\n"
  read -e -r -p "${PROMPT_CONFIRM}: "

  [[ "${REPLY,,}" == "$OPTION_CONFIRM" ]]
}

# Monta as partições de boot e sistema do disco selecionado
# Boot (EFI): /mnt/boot
# Sistema: /mnt
# $1: disco selecionado (hda, sdb, nvme0n1, etc)
mount_partitions() {
  local disk="$1"

  is_disk_valid "$disk" || return 1

  mount "/dev/${disk}2" /mnt \
    && mount --options umask=0077 --mkdir "/dev/${disk}1" /mnt/boot
}

# Verifica se existe pontos de montagem no disco selecionado
# $1: disco selecionado (hda, sdb, nvme0n1, etc)
mountpoints_exist() {
  local disk="$1"
  local -a mountpoints=()

  is_disk_valid "$disk" || return 1
  get_mountpoints mountpoints "$disk" || return 1

  [[ ${#mountpoints[@]} -gt 0 ]]
}

# Verifica se existe um esquema de partições no disco selecionado
# $1: disco selecionado (hda, sdb, nvme0n1, etc)
partitions_exist() {
  local disk="$1"

  is_disk_valid "$disk" || return 1

  sfdisk --dump "/dev/$disk" &> /dev/null
}

# Prepara o disco selecionado para a instalação. Depois de solicitar confirmação
# do usuário se o esquema de partições está correto, realiza as seguintes
# operações sobre as partições:
# 1) Desmonta
# 2) Deleta
# 3) Cria
# 4) Formata
# 5) Monta
prepare_disk() {
  local -r MSG_ERR_DEVICE_INVALID='ERRO: disco inválido'
  local -r MSG_ERR_EFI_SIZE='ERRO: tamanho inválido para a partição EFI'
  local -r MSG_ERR_PARTITION_CREATE='ERRO: falha ao criar partições'
  local -r MSG_ERR_PARTITION_DELETE='ERRO: falha ao deletar partições'
  local -r MSG_ERR_PARTITION_FORMAT='ERRO: falha ao formatar partições'
  local -r MSG_ERR_PARTITION_MOUNT='ERRO: falha ao montar partições'
  local -r MSG_ERR_PARTITION_UNMOUNT='ERRO: falha ao desmontar partições'
  local disk
  local efi_size

  if ! disk="$(get_disk)"; then
    err "$MSG_ERR_DEVICE_INVALID"
    return 1
  fi

  if ! efi_size="$(get_efi_size)"; then
    err "$MSG_ERR_EFI_SIZE"
    return 1
  fi

  is_partition_scheme_valid "$disk" "$efi_size" || return 1

  if mountpoints_exist "$disk"; then
    if ! unmount_partitions "$disk"; then
      err "$MSG_ERR_PARTITION_UNMOUNT"
      return 1
    fi
  fi

  if partitions_exist "$disk"; then
    if ! delete_partitions "$disk"; then
      err "$MSG_ERR_PARTITION_DELETE"
      return 1
    fi
  fi

  if ! create_partitions "$disk" "$efi_size"; then
    err "$MSG_ERR_PARTITION_CREATE"
    return 1
  fi

  if ! format_partitions "$disk"; then
    err "$MSG_ERR_PARTITION_FORMAT"
    return 1
  fi

  if ! mount_partitions "$disk"; then
    err "$MSG_ERR_PARTITION_MOUNT"
    return 1
  fi
}

# Mostra informações sobre os discos detectados no sistema
show_disks() {
  lsblk --output NAME,MODEL,SIZE,FSUSED,FSUSE%,FSTYPE,MOUNTPOINTS >&2
}

# Mostra o esquema de partições a ser usado na instalação
# $1: disco selecionado (hda, sdb, nvme0n1, etc)
# $2: tamanho em MiB da partição EFI
show_partition_scheme() {
  local -r COLOR_HIGHLIGHT=$'\e[36m'
  local -r COLOR_RESET=$'\e[0m'
  local disk="$1"
  local efi_size="$2"

  is_disk_valid "$disk" || return 1
  is_efi_size_valid "$efi_size" || return 1

  cat <<EOF
Tipo: GPT
Dispositivo: ${COLOR_HIGHLIGHT}${disk}${COLOR_RESET}
${COLOR_HIGHLIGHT}${disk}1${COLOR_RESET}: Boot (EFI) - FAT32 - tamanho: ${COLOR_HIGHLIGHT}${efi_size}${COLOR_RESET} MiB
${COLOR_HIGHLIGHT}${disk}2${COLOR_RESET}: Sistema    - ext4  - tamanho: resto do disco
EOF
}

# Desmonta todas as partições do disco selecionado
# $1: disco selecionado (hda, sdb, nvme0n1, etc)
unmount_partitions() {
  local disk="$1"
  local -a mountpoint=()
  local mountpoint

  is_disk_valid "$disk" || return 1
  get_mountpoints mountpoints "$disk" || return 1

  for mountpoint in "${mountpoints[@]}"; do
    umount "$mountpoint" || return 1
  done
}
