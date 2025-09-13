# Use UBI9 base image
FROM registry.redhat.com/ubi9/ubi:9.6-1753469805-1

# Set environment variables for Vault
ARG SRES_API_TOKEN
ARG SRES_USERNAME

# Install necessary packages
RUN yum update -y && \
    yum install -y wget curl unzip && \
    yum clean all

# Create vault user and directories
RUN useradd --system --home-dir /opt/vault --shell /bin/false vault && \
    mkdir -p /opt/vault/data /opt/vault/logs /etc/vault.d && \
    chown -R vault:vault /opt/vault && \
    chmod 755 /opt/vault

# Download and install Vault RPM
RUN curl -L "https://sres.web.boeing.com/artifactory/hashicorp-rpm-remote/RHEL/9/x86_64/stable/vault-1.20.3-1.x86_64.rpm" \
    -H "X-JFrog-Art-Api: ${SRES_API_TOKEN}" \
    -o /tmp/vault-1.20.3-1.x86_64.rpm && \
    rpm -ivh /tmp/vault-1.20.3-1.x86_64.rpm && \
    rm -f /tmp/vault-1.20.3-1.x86_64.rpm

# Create Vault configuration
COPY config.hcl /etc/vault.d/config.hcl

# Set proper permissions
RUN chown vault:vault /etc/vault.d/config.hcl && \
    chmod 640 /etc/vault.d/config.hcl

# Add IPC_LOCK capability for Vault
RUN setcap cap_ipc_lock=+ep /usr/bin/vault

# Create a simple startup script
RUN echo '#!/bin/bash' > /usr/local/bin/start-vault.sh && \
    echo 'vault server -config=/etc/vault.d/config.hcl' >> /usr/local/bin/start-vault.sh && \
    chmod +x /usr/local/bin/start-vault.sh

# Switch to vault user
USER vault

# Expose Vault port
EXPOSE 8200

# Set working directory
WORKDIR /opt/vault

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD vault status || exit 1

# Start Vault
CMD ["/usr/local/bin/start-vault.sh"]
