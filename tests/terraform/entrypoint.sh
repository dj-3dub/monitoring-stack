#!/bin/sh
# Install the test's public key, start sshd, then hand over to Docker's own
# dind entrypoint (which starts dockerd).
set -eu
mkdir -p /home/deploy/.ssh
cp /test-key.pub /home/deploy/.ssh/authorized_keys
chown -R deploy:deploy /home/deploy/.ssh
chmod 700 /home/deploy/.ssh && chmod 600 /home/deploy/.ssh/authorized_keys
/usr/sbin/sshd
exec dockerd-entrypoint.sh "$@"
