#!/bin/sh
# CHR startup script for CI.
# Replaces start.sh (which uses bridge networking for production).
# Uses -netdev user with port forwarding so CI can reach SSH on port 2222.
set -e

img=$(ls /diskimage/*.img)

kvm_flag=""
if [ -e /dev/kvm ]; then
    kvm_flag="-enable-kvm -cpu host"
fi

# shellcheck disable=SC2086
exec qemu-system-x86_64 $kvm_flag \
    -m 256 -smp 1 \
    -drive file="$img",format=raw \
    -nographic -monitor none \
    -serial telnet:0.0.0.0:5555,server,nowait \
    -netdev user,id=n1,hostfwd=tcp::2222-:22 \
    -device virtio-net-pci,netdev=n1
