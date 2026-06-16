#!/usr/bin/env bash

# Verifica se está conectado na internet
is_connected() {
  local -r -i COUNT=2
  local -r -i TIMEOUT=5
  # IP do DNS público do Google
  local -r HOST='8.8.8.8'

  ping -c "$COUNT" -W "$TIMEOUT" "$HOST" &> /dev/null
}
