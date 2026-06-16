#!/usr/bin/env bash

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

# Define a fonte do console e duplica seu tamanho
# $1: fonte
set_console_font() {
  [[ -z "$1" ]] && return 1

  setfont -d "$1"
}

# Define o layout do teclado
# $1: layout do teclado
set_keyboard_layout() {
  [[ -z "$1" ]] && return 1

  loadkeys "$1"
}
