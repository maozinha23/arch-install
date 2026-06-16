#!/usr/bin/env bash

source "$(dirname -- "${BASH_SOURCE[0]}")/lib/chroot.sh" || exit 1
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/disk.sh" || exit 1
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/internet.sh" || exit 1
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/package.sh" || exit 1
source "$(dirname -- "${BASH_SOURCE[0]}")/lib/util.sh" || exit 1
#-------------------------------------------------------------------------------
main() {
  local -r CONSOLE_FONT='cp850-8x14'
  local -r KEYBOARD_LAYOUT='br-abnt2'

  local -r MSG_ERR_DISK='ERRO: falha ao preparar o disco para instalação'
  local -r MSG_ERR_FSTAB='ERRO: falha ao gerar novo arquivo fstab'
  local -r MSG_ERR_INTERNET='ERRO: não foi possível conectar à internet'
  local -r MSG_ERR_INSTALL='ERRO: instalação cancelada'
  local -r MSG_ERR_PACKAGE='ERRO: falha ao instalar os pacotes do sistema'

  clear
  set_keyboard_layout "$KEYBOARD_LAYOUT"
  set_console_font "$CONSOLE_FONT"

  if ! is_connected; then
    err "$MSG_ERR_INTERNET" "\n$MSG_ERR_INSTALL"
    return 1
  fi

  if ! prepare_disk; then
    err "$MSG_ERR_DISK" "\n$MSG_ERR_INSTALL"
    return 1
  fi

  if ! install_base_packages; then
    err "$MSG_ERR_PACKAGE" "\n$MSG_ERR_INSTALL"
    return 1
  fi

  if ! gen_file_system_table; then
    err "$MSG_ERR_FSTAB" "\n$MSG_ERR_INSTALL"
    return 1
  fi

  # if ! chroot_setup; then
  #   err "$MSG_ERR_INSTALL"
  #   return 1
  # fi
  #
  # finish_install
}
#-------------------------------------------------------------------------------
main "$@"
