############################################################
# Final Stage - Corrected
############################################################
FROM registry.web.boeing.com/container/images/stack/ubi9minimal-jdk17:9.1.0-1829-5-1

ENV RESOURCE_DIR=/opt/resources
ENV SCRIPT_DIR=/opt/scripts
ENV PATH=$PATH:/usr/bin

# --- CHANGED ---
# Using microdnf to install utilities. 'shadow-utils' provides the 'useradd' command.
# 'util-linux' is good practice for minimal images.
RUN microdnf install -y shadow-utils util-linux && microdnf clean all

# Copy files from the builder stage
# --- REMOVED --- No longer copying the ma-common rpm
COPY --from=builder ${SCRIPT_DIR}/startup.sh ${SCRIPT_DIR}/
COPY --from=builder ${RESOURCE_DIR}/vault /usr/bin/
COPY --from=builder ${RESOURCE_DIR}/vault-config.hcl /vault/config/

# --- CHANGED ---
# Replaced 'rpm' install and 'ma-common setup-image' with direct commands
RUN chmod +x ${SCRIPT_DIR}/startup.sh \
 && chmod 775 /usr/bin/vault \
 && useradd --uid 1000 --gid 0 --no-create-home --shell /bin/bash developer \
 && echo "Image built on: $(date)" > /opt/build_info

EXPOSE 8200

# --- CHANGED ---
# The CMD now calls startup.sh directly instead of using 'ma-common start'
CMD ["/opt/scripts/startup.sh"]
