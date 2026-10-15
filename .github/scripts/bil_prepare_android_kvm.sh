#!/usr/bin/env bash
set -euo pipefail

# Only on the disposable hosted runner. udev trigger queues events; wait for
# their handlers before testing the current user's access to the device node.
echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' \
  | sudo tee /etc/udev/rules.d/99-kvm4all.rules
sudo udevadm control --reload-rules
sudo udevadm trigger --name-match=kvm
sudo udevadm settle --timeout=20
stat -c 'kvm permissions=%a owner=%U group=%G' /dev/kvm
id
test -r /dev/kvm
test -w /dev/kvm
free -m
