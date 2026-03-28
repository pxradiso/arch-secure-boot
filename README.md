# Arch-secure-boot
Shell script to enable secure boot in Arch Linux (i use arch, btw)

## Pre-use steps
1. Enter your BIOS and reset Secure Boot to **Setup Mode**
2. **DO NOT** enter any other operating system after this — head straight into the Arch installation you want to sign for Secure Boot

## Usage
Clone and cd into this repository with:
```bash
git clone https://github.com/pxradiso/arch-secure-boot.git && cd arch-secure-boot
```
Then run the script as root with:
```bash
sudo sh secureboot-arch.sh
```

## What the script does
1. Installs `sbctl` and `grub` via pacman
2. Checks sbctl status and Setup Mode
3. Creates and enrolls your custom Secure Boot keys (with optional Microsoft keys for Valorant/Battlefield compatibility)
4. **Backs up your GRUB themes** to `/root/grub-themes-backup-YYYYMMDD_HHMMSS` before proceeding
5. Reinstalls GRUB with `--disable-shim-lock` to fix the `shim_lock_verifier_init:177` error
6. Restores your GRUB themes
7. Regenerates GRUB config
8. Signs all unsigned EFI binaries and kernel images
9. Prompts you to reboot and enable Secure Boot in BIOS

## Known issues & fixes
### `error: kern/efi/sb.c:shim_lock_verifier_init:177: prohibited by secure boot policy`
This error occurs when GRUB is built expecting shim chainloading but custom keys are used instead. The script automatically fixes this by reinstalling GRUB with `--disable-shim-lock`. If you hit this on an existing install before running the script, boot from an Arch live USB, chroot into your system, and run the script from there.

## Issues
Please open an issue in [#issues](https://github.com/pxradiso/arch-secure-boot/issues) so I can find the fixes

## Contributions
Everyone is welcome to contribute. Fork this repository and open a pull request along with a description of your changes
