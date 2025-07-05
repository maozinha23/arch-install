#!/bin/sh

# Installation guide (Português)
# https://wiki.archlinux.org/title/Installation_guide_(Portugu%C3%AAs)

# Funções auxiliares {{{
# Verifica a conectividade com a internet tentando pingar um servidor confiável
is_connected() {
  _host='8.8.8.8'  # IP do DNS público do Google
  _count=2         # Número de tentativas de ping
  _timeout=5       # Tempo limite por tentativa em segundos

  ping -c "${_count}" -W "${_timeout}" "${_host}" > /dev/null 2>&1
}
# }}}

# 1 - Pré-instalação {{{

# 1.1 - Obter uma imagem de instalação {{{
# }}}

# 1.2 - Verificar a assinatura {{{
# }}}

#1.3 - Preparar uma mídia de instalação {{{
# }}}

# 1.4 - Inicializar o ambiente live {{{
# }}}

# 1.5 - Definir o layout e fonte do teclado do console {{{
loadkeys br-abnt2
setfont ter-120n
# }}}

# 1.6 - Definir o idioma do ambiente live {{{
# }}}

# 1.7 - Verificar o modo de inicialização {{{
#cat /sys/firmware/efi/fw_platform_size
# }}}

# 1.8 - Conectar à internet {{{
# Verifica se foi possível conectar à internet
# Se não foi possível conectar por uma interface ethernet, tenta através de uma
# interface wireless
printf "Verificando a conexão com a internet ...\n"

if ! is_connected; then
  printf "Não foi possível conectar à internet.\n"

  iwctl device list

  printf "Escolha o dispositivo: "
  read -r _device

  if iwctl device "${_device}" set-property Powered on; then
    iwctl station "${_device}" scan
    iwctl station "${_device}" get-networks

    printf "Escolha a rede sem fio: "
    read -r _ssid

    printf "Digite a senha: "
    stty -echo
    read -r _passphrase
    stty echo
    printf "\n"

    printf "Tentando conectar-se a rede %s ...\n" "${_ssid}"
    iwctl --passphrase "${_passphrase}" station "${_device}" connect "${_ssid}"
  else
    printf "Não foi possível ligar o dispositivo %s\n" "${_device}"
  fi
fi

# Finaliza o script se não foi possível conectar à internet
if ! is_connected; then
  printf "Não foi possível conectar à internet.\nO script de instalação será \
encerrado."
  exit 1
fi
# }}}

# 1.9 - Atualizar o relógio do sistema {{{
timedatectl set-timezone America/Sao_Paulo
# }}}

# 1.10 - Partição dos discos {{{
printf "O script utilizará o seguinte esquema de partições:\n\
label: gpt\n\
device: disco_escolhido\n\
disco_escolhido1: EFI System       - tamanho: 36MiB\n\
disco_escolhido2: Linux filesystem - tamanho: resto do disco\n"

lsblk
printf "Escolha o disco para instalação: "
read -r _disk

printf "O sistema será instalado no dispositivo %s\n\
TODOS OS DADOS DO DISCO SERÃO PERDIDOS!\n\
Deseja continuar? Digite 's' para confirmar: " "${_disk}"
read -r _continue

if [ ! "${_continue}" = 's' ]; then
  printf "O script de instalação será encerrado.\n"
  exit 1
fi

sfdisk --delete /dev/"${_disk}"

# GUID para GPT:
# EFI              C12A7328-F81F-11D2-BA4B-00A0C93EC93B
# Linux Filesystem 0FC63DAF-8483-4772-8E79-3D69D8477DE4
# Linux Swap       0657FD6D-A4AB-43C4-84E5-0933C84B4F4F
cat << EOF | sfdisk /dev/"${_disk}"
label: gpt
device: /dev/${_disk}
unit: sectors
first-lba: 2048
sector-size: 512

/dev/${_disk}1 : start= , size=36M, type=C12A7328-F81F-11D2-BA4B-00A0C93EC93B
/dev/${_disk}2 : start= , size= , type=0FC63DAF-8483-4772-8E79-3D69D8477DE4
EOF
# }}}

# 1.11 - Formatar as partições {{{
# -F: FAT SIZE
umount -l /dev/"${_disk}"1
mkfs.fat -F 32 /dev/"${_disk}"1
umount -l /dev/"${_disk}"2
mkfs.ext4 -F /dev/"${_disk}"2
#mkswap /dev/partição_swap
# }}}

# 1.12 - Montar os sistemas de arquivos {{{
mount /dev/"${_disk}"2 /mnt
mount --mkdir /dev/"${_disk}"1 /mnt/efi
#swapon /dev/partição_swap
#}}}

# }}}

# 2 - Instalação {{{

# 2.1 - Selecionar os espelhos {{{
# /etc/pacman.d/mirrorlist
# }}}

# 2.2 - Instalar os pacotes essenciais {{{
# Verifica se o sistema possui um CPU AMD ou Intel para instalar o microcode
[ "$(lscpu | grep --ignore-case --count 'amd')" -gt 0 ] \
  && cpu_microcode=amd-ucode \
  || cpu_microcode=intel-ucode

# amd-ucode : Microcode update image for AMD CPUs
# base : Minimal package set to define a basic Arch Linux installation
# base-devel : Basic tools to build Arch Linux packages
# dosfstools : DOS filesystem utilities
# e2fsprogs : Ext2/3/4 filesystem utilities
# efibootmgr : Linux user-space application to modify the EFI Boot Manage
# grub : GNU GRand Unified Bootloader (2)
# intel-ucode : Microcode update files for Intel CPUs
# linux :	The Linux kernel and modules
# linux-firmware : Firmware files for Linux - Default set
# man-db : A utility for reading man pages
# man-pages : Linux man pages
# neovim : Fork of Vim aiming to improve user experience, plugins, and GUIs
# networkmanager : Network connection manager and user applications
# ntfs-3g : NTFS filesystem driver and utilities
# zsh : A very advanced and programmable command interpreter (shell) for UNIX
pacstrap -K /mnt base base-devel ${cpu_microcode} dosfstools e2fsprogs \
  efibootmgr grub linux linux-firmware man-db man-pages neovim networkmanager \
  ntfs-3g zsh
# }}}

# }}}

# 3 - Configurar o sistema {{{

# 3.1 - Fstab {{{
genfstab -U /mnt >> /mnt/etc/fstab
# }}}

# 3.2 - Chroot {{{
arch-chroot /mnt /bin/sh -c '
# }}}

# 3.3 - Horário {{{
ln --symbolic --force /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
systemctl enable systemd-timesyncd.service
# }}}

# 3.4 - Localização {{{
# Remove o comentário de pt_BR.UTF-8 e gera os locales
sed --in-place "s/^#\(pt_BR.UTF-8\)/\1/" /etc/locale.gen
locale-gen

# Cria o arquivo locale.conf e define a variável LANG adequadamente
printf "LANG=pt_BR.UTF-8\n" > /etc/locale.conf

# Armazena as definições do layout do teclado do console em vconsole.conf(5)
printf "KEYMAP=br-abnt2\n" > /etc/vconsole.conf
# }}}

# 3.5 - Configuração de rede {{{
# Cria o arquivo hostname:
printf "Digite seu hostname: "
read -r HOSTNAME
print "%s\n" "${HOSTNAME}" > /etc/hostname

# /etc/hosts
cat << EOF > /etc/hosts
# The following lines are desirable for IPv4 capable hosts
127.0.0.1 localhost
# 127.0.1.1 is often used for the FQDN of the machine
127.0.1.1 ${HOSTNAME}.example.org ${HOSTNAME}

# The following lines are desirable for IPv6 capable hosts
::1 localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

# Ativa o serviço do NetworkManager na inicialização do sistema
systemctl enable NetworkManager.service
# }}}

# 3.6 - Initramfs {{{
# mkinitcpio --allpresets
# }}}

# 3.7 - Senha do root {{{
printf "Digite seu nome de usuário: "
read -r _user
useradd --create-home --groups wheel --shell /bin/zsh "${_user}"
passwd "${_user}"

# Permite que usuários do grupo wheel executem qualquer comando
#visudo
sed --in-place "s/^# *\(%wheel ALL=(ALL:ALL) ALL\)/\1/" /etc/sudoers

# Desabilita o login do usuário root
passwd --lock root
# }}}

# 3.8 - Gerenciador de boot {{{
grub-install --target=x86_64-efi --efi-directory=/efi --bootloader-id=GRUB
grub-mkconfig --output=/boot/grub/grub.cfg
# }}}

# }}}

# 4 - Reiniciar {{{

exit
'
umount -R /mnt
reboot
# }}}
