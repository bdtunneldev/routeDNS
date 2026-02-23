# HAProxy with Lua support for tenant validation
FROM haproxy:3.3.4-alpine

# Switch to root for package installation
USER root

# Install required packages for Lua HTTP client and utilities
# hadolint ignore=DL3018
RUN apk update && apk add --no-cache \
    lua5.4=~5.4 \
    lua5.4-socket=~3.1 \
    ca-certificates \
    curl \
    netcat-openbsd

# Create necessary directories
RUN mkdir -p /usr/local/etc/haproxy/certs \
    && mkdir -p /usr/local/etc/haproxy/lua \
    && mkdir -p /var/run/haproxy

# Set proper permissions for all haproxy directories
RUN chown -R haproxy:haproxy /usr/local/etc/haproxy \
    && chown -R haproxy:haproxy /var/run/haproxy \
    && chmod 755 /usr/local/etc/haproxy/certs \
    && chmod 755 /usr/local/etc/haproxy/lua

# Copy configuration (done via volumes in docker-compose, but set defaults)
COPY --chown=haproxy:haproxy haproxy/haproxy.cfg /usr/local/etc/haproxy/haproxy.cfg

# Switch to non-root user for security
USER haproxy

# Note: Container runs as root to read mounted certs, but HAProxy can drop privileges if configured

# Expose ports
EXPOSE 853 8404

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD echo 'quit' | nc -w 1 127.0.0.1 8404 || exit 1

# Run HAProxy
CMD ["haproxy", "-f", "/usr/local/etc/haproxy/haproxy.cfg"]
