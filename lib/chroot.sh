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
