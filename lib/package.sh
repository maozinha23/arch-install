#!/usr/bin/env bash

# Obtém a lista de pacotes de um arquivo. Desconsidera linhas em branco e
# inciadas com #
# $1: array recebido como referência
# $2: caminho do arquivo
get_package_list() {
  [[ -z "$1" || ! -f "$2" ]] && return 1

  local -n pkg_list=$1
  local file="$2"

  mapfile -t pkg_list < <(grep --extend-regexp --invert-match '^(#|$)' "$file")

  (( ${#pkg_list[@]} == 0 )) && return 1
}

# Obtém o nome do pacote referente ao microcode do dispositivo (AMD/Intel)
get_microcode_package() {
  local -r MICROCODE_AMD='amd-ucode'
  local -r MICROCODE_INTEL='intel-ucode'

  lscpu | grep --quiet --ignore-case 'amd' \
    && echo "$MICROCODE_AMD" \
    || echo "$MICROCODE_INTEL"
}

# Instala os pacotes básicos do sistema
install_base_packages() {
  local -r PACKAGES_BASE_FILE="$(dirname -- "${BASH_SOURCE[0]}")/packages/base"
  [[ -f "$PACKAGES_BASE_FILE" ]] || return 1

  local cpu_microcode
  local -a pkg_list=()

  cpu_microcode="$(get_microcode_package)" || return 1
  get_package_list pkg_list "$PACKAGES_BASE_FILE" || return 1
  pkg_list+=("$cpu_microcode")

  pacstrap -K /mnt "${pkg_list[@]}"
}
