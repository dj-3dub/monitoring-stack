# A disposable "remote host" for tests/terraform/run.sh: SSH + Docker.
FROM docker:29-dind

RUN apk add --no-cache bash curl openssh-server sudo \
 && adduser -D -s /bin/bash deploy \
 && passwd -u deploy \
 && echo 'deploy ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/deploy \
 && ssh-keygen -A

COPY entrypoint.sh /usr/local/bin/test-host-entrypoint.sh
ENTRYPOINT ["/usr/local/bin/test-host-entrypoint.sh"]
