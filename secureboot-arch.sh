#!/usr/bin/env bash
echo "Using sbctl to activate secure boot: https://github.com/Foxboron/sbctl"
if [[ "$EUID" -ne 0 ]]; then
    echo "Run this script in superuser"
    exit 1
fi

echo "=== Downloading sbctl ==="
pacman -Syu --noconfirm
pacman -S sbctl --noconfirm

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
echo -e "\n❤️ Thanks pxradise (me) for porting it on Arch [https://github.com/pxradiso](https://github.com/pxradiso) and the creator of this script! https://github.com/degenerate-kun-69"
echo -e "\n🌟 Star this repo and the original repo. Thanks!"
