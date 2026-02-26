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
  iwctl device list | grep --quiet 'wlan'
}
#-------------------------------------------------------------------------------
# Internet
#-------------------------------------------------------------------------------
# Se não foi possível conectar à internet por uma interface ethernet, tenta
# através de uma interface wireless
printf '\nConectando à internet ...\n'

if ! is_connected && is_wifi_detected; then
  printf 'Não foi possível acessar a internet através de conexão cabeada\n\n'

  iwctl device list
  printf '\nEscolha o dispositivo de rede sem fio: '
  read -r device

  iwctl device "${device}" set-property Powered off
  iwctl device "${device}" set-property Powered on
  iwctl station "${device}" scan
  iwctl station "${device}" get-networks

  printf '\nEscolha a rede sem fio: '
  read -r ssid

  printf 'Digite a senha: '
  stty -echo
  read -r passphrase
  stty echo

  printf '\nTentando conectar-se a rede %s (10s de espera)...\n' "${ssid}"
  iwctl --passphrase "${passphrase}" station "${device}" connect "${ssid}" \
    && sleep 10
fi

# Finaliza o script se não foi possível conectar à internet
if ! is_connected; then
  printf '\nNão foi possível conectar à internet.\n\
O script de instalação será encerrado.\n'
  exit 1
fi
#-------------------------------------------------------------------------------
# Partições
#-------------------------------------------------------------------------------
printf '\nParticionado os discos ...\n'

# Tamanho da partição EFI em MiB
efi_size=400

printf '\nO script utilizará o seguinte esquema de partições:\n\
label: gpt\n\
device: disco_escolhido\n\
disco_escolhido1: EFI System       - tamanho: %dMiB\n\
disco_escolhido2: Linux filesystem - tamanho: resto do disco\n\n' \
"${efi_size}"

lsblk
printf '\nEscolha o disco para instalação: '
read -r disk

printf 'O sistema será instalado no dispositivo %s\n\
TODOS OS DADOS DO DISCO SERÃO PERDIDOS!\n\
Deseja continuar? Digite "s" para confirmar: ' "${disk}"
read -r answer

if [ ! "${answer}" = 's' ]; then
  printf '\nO script de instalação será encerrado.\n'
  exit 1
fi

sfdisk --delete /dev/"${disk}"

# GUID para GPT
guid_efi='C12A7328-F81F-11D2-BA4B-00A0C93EC93B'
guid_linux_fs='0FC63DAF-8483-4772-8E79-3D69D8477DE4'

cat <<END | sfdisk /dev/"${disk}"
label: gpt
device: /dev/${disk}
unit: sectors
first-lba: 2048
sector-size: 512

/dev/${disk}1 : start= , size=${efi_size}M, type=${guid_efi}
/dev/${disk}2 : start= , size= , type=${guid_linux_fs}
END
#-------------------------------------------------------------------------------
# Formatação
#-------------------------------------------------------------------------------
printf '\nFormatando as partições ...\n'
# EFI - FAT32
mkfs.fat -F 32 /dev/"${disk}"1
# / - ext4
mkfs.ext4 -F /dev/"${disk}"2
#-------------------------------------------------------------------------------
# Montagem
#-------------------------------------------------------------------------------
printf '\nMontando os sistemas de arquivos ...\n'
mount /dev/"${disk}"2 /mnt
mount --mkdir /dev/"${disk}"1 /mnt/boot
#-------------------------------------------------------------------------------
# Instalação
#-------------------------------------------------------------------------------
printf '\nInstalando os pacotes essenciais ...\n'

# Verifica se o sistema possui um CPU AMD ou Intel para instalar o microcode
[ "$(lscpu | grep --ignore-case --count 'amd')" -gt 0 ] \
  && cpu_microcode=amd-ucode \
  || cpu_microcode=intel-ucode

# amd-ucode : Microcode update image for AMD CPUs
# base : Minimal package set to define a basic Arch Linux installation
# base-devel : Basic tools to build Arch Linux packages
# efibootmgr : Linux user-space application to modify the EFI Boot Manager
# intel-ucode : Microcode update files for Intel CPUs
# linux :	The Linux kernel and modules
# linux-firmware : Firmware files for Linux - Default set
# man-db : A utility for reading man pages
# man-pages : Linux man pages
# neovim : Fork of Vim aiming to improve user experience, plugins, and GUIs
# networkmanager : Network connection manager and user applications
pacstrap -K /mnt base base-devel ${cpu_microcode} efibootmgr linux \
  linux-firmware man-db man-pages neovim networkmanager
#-------------------------------------------------------------------------------
# Configuraração
#-------------------------------------------------------------------------------
printf '\nConfigurando o sistema ...\n'

printf '\nFstab ...\n'
genfstab -U /mnt >> /mnt/etc/fstab

# Copia o script de pós-instalação para a raiz do novo sistema
cp "$(pwd)"/01-post_install.sh /mnt/

printf '\nChroot ...\n'
arch-chroot /mnt /bin/sh -c '

printf "\nHorário ...\n"
ln --symbolic --force /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
systemctl enable systemd-timesyncd.service

printf "\nLocalização ...\n"
# Gera os locales para pt_BR.UTF-8
sed --in-place "s/^#\(pt_BR.UTF-8\)/\1/" /etc/locale.gen
locale-gen

# Cria o arquivo locale.conf e define a variável LANG adequadamente
printf "LANG=pt_BR.UTF-8\n" > /etc/locale.conf

# Armazena as definições do layout do teclado do console
printf "KEYMAP=br-abnt2\n" > /etc/vconsole.conf

printf "\nConfiguração de rede ...\n"
# Cria o arquivo hostname:
printf "Digite seu hostname: "
read -r hostname
printf "%s\n" "${hostname}" > /etc/hostname

# Ativa o serviço do NetworkManager na inicialização do sistema
systemctl enable NetworkManager.service

printf "\nCriação do usuário ...\n"
printf "Digite seu nome de usuário: "
read -r user
useradd --create-home --groups wheel "${user}"
passwd "${user}"

# Move o script de pós-instalação para a "home" do usuário recém criado
chmod 777 /01-post_install.sh
mv /01-post_install.sh /home/"${user}"

# Permite que usuários do grupo "wheel" executem qualquer comando
sed --in-place "s/^# *\(%wheel ALL=(ALL:ALL) ALL\)/\1/" /etc/sudoers

# Desabilita o login do usuário root
passwd --lock root

printf "\nGerenciador de boot ...\n"
bootctl install

# Configuração do systemd boot
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
options root=UUID=${uuid_root} rw quiet loglevel=3
EOF

exit
'
#-------------------------------------------------------------------------------
# Conclusão
#-------------------------------------------------------------------------------
printf '\nInstalação finalizada.\n\
Pressione ENTER para reiniciar.\n'
read -r _

umount -R /mnt
reboot
