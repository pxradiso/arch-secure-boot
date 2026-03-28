#!/usr/bin/env bash
echo "Using sbctl to activate secure boot: https://github.com/Foxboron/sbctl"

if [[ "$EUID" -ne 0 ]]; then
    echo "Run this script in superuser"
    exit 1
fi

echo "=== Downloading sbctl ==="
pacman -Syu --noconfirm
pacman -S sbctl grub --noconfirm

echo -e "\n=== Checking if sbctl is working ==="
sbctl status

read -rp "Do you play Valorant or Battlefield 6? (Y/n): " dualboot

enroll_keys() {
    if [[ "$dualboot" =~ ^[Yy]$ ]]; then
        sbctl enroll-keys --microsoft
    else
        sbctl enroll-keys
    fi
}

setup_mode=$(sbctl status | grep "Setup Mode" | awk '{print $NF}')

if [[ "$setup_mode" == "✓" ]]; then
    echo -e "\n=== Setup Mode is Enabled ==="
    echo "Creating and enrolling keys..."
    sbctl create-keys
    enroll_keys
    echo -e "\nContinuing without reboot..."
else
    echo -e "\n=== Setup Mode is Disabled ==="
    enroll_keys
    echo -e "\nContinuing without reboot..."
fi

echo -e "\n=== Post enrollment status ==="
sbctl status

echo -e "\n=== Detecting EFI directory ==="
if mountpoint -q /boot/efi; then
    EFI_DIR="/boot/efi"
elif mountpoint -q /efi; then
    EFI_DIR="/efi"
elif mountpoint -q /boot; then
    EFI_DIR="/boot"
else
    echo "⚠️ Could not detect EFI mount point. Defaulting to /boot/efi"
    EFI_DIR="/boot/efi"
fi
echo "Using EFI directory: $EFI_DIR"

echo -e "\n⚠️  WARNING: GRUB will be reinstalled with --disable-shim-lock."
echo "   This is required to fix the shim_lock_verifier_init:177 secure boot error."
echo "   Your existing GRUB installation will be overwritten."
read -rp "   Continue? (Y/n): " confirm_grub
if [[ ! "$confirm_grub" =~ ^[Yy]$ ]]; then
    echo "Aborted by user."
    exit 0
fi

BACKUP_DIR="/root/grub-themes-backup-$(date +%Y%m%d_%H%M%S)"
if [[ -d /boot/grub/themes ]]; then
    echo -e "\n=== Backing up GRUB themes to $BACKUP_DIR ==="
    cp -r /boot/grub/themes "$BACKUP_DIR"
    echo "✅ Themes backed up to $BACKUP_DIR"
else
    echo -e "\n No GRUB themes found, skipping backup."
fi

echo -e "\n=== Reinstalling GRUB with --disable-shim-lock ==="
grub-install --target=x86_64-efi \
    --efi-directory="$EFI_DIR" \
    --bootloader-id=GRUB \
    --modules="tpm" \
    --disable-shim-lock || { echo "❌ grub-install failed. Aborting."; exit 1; }

if [[ -d "$BACKUP_DIR" ]]; then
    echo -e "\n=== Restoring GRUB themes ==="
    cp -r "$BACKUP_DIR" /boot/grub/themes
    echo "✅ Themes restored"
fi

echo -e "\n=== Regenerating GRUB config ==="
grub-mkconfig -o /boot/grub/grub.cfg

echo -e "\n=== Signing and verifying EFI binaries ==="

while true; do
    verify_output=$(sbctl verify 2>&1 | grep -v "failed to verify file")

    echo "$verify_output"

    unsigned_efi=$(echo "$verify_output" | grep "✗" | awk '{print $2}' | grep -E "\.efi$|\.EFI$" || true)

    if [[ -z "$unsigned_efi" ]]; then
        echo -e "\n✅ All EFI binaries are signed!"
        break
    fi

    echo -e "\n=== Found unsigned EFI binaries ==="
    echo "$unsigned_efi"

    while read -r file; do
        [[ -z "$file" ]] && continue
        echo "Signing: $file"
        sbctl sign -s "$file" || echo "⚠️ Failed to sign $file"
    done <<< "$unsigned_efi"
done

echo -e "\n=== Checking kernel images ==="
kernels=(/boot/vmlinuz-*)

if [[ ${#kernels[@]} -gt 0 ]]; then
    for kernel in "${kernels[@]}"; do
        echo "Signing kernel: $kernel"
        sbctl sign -s "$kernel" || echo "⚠️ Failed to sign $kernel"
    done
else
    echo "No kernel images found in /boot/"
fi

echo -e "\n=== Final sbctl verify ==="
sbctl verify | grep -v "failed to verify file"

echo -e "\n✅ All unsigned EFI binaries and kernels have been signed!"
echo -e "\n🔒 Now reboot the system and enable Secure Boot in BIOS"
echo -e "\n❤️ Thanks pxradise (me) for porting it on Arch [https://github.com/pxradiso](https://github.com/pxradise) and the creator of this script! https://github.com/degenerate-kun-69"
echo -e "\n🌟 Star this repo and the original repo. Thanks!"
