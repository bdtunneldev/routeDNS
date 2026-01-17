#!/bin/bash
# Certificate deployment script for HAProxy production
set -e

CERT_SRC="/etc/letsencrypt/live/dns.routedns.io"
CERT_DEST="./haproxy/certs"

# Check if source certificates exist
if [ ! -f "$CERT_SRC/fullchain.pem" ] || [ ! -f "$CERT_SRC/privkey.pem" ]; then
    echo "Error: Certificates not found in $CERT_SRC"
    echo "Please run certbot first to obtain certificates."
    exit 1
fi

# Create destination directory if it doesn't exist
mkdir -p "$CERT_DEST"

# Copy Let's Encrypt certificates
sudo cp "$CERT_SRC/fullchain.pem" "$CERT_DEST/"
sudo cp "$CERT_SRC/privkey.pem" "$CERT_DEST/"

# Create combined PEM file for HAProxy (cert + key in one file)
sudo sh -c "cat $CERT_DEST/fullchain.pem $CERT_DEST/privkey.pem > $CERT_DEST/dot.pem"

# Set proper ownership and permissions
sudo chown $(id -u):$(id -g) "$CERT_DEST"/*.pem
sudo chmod 644 "$CERT_DEST/fullchain.pem"
sudo chmod 600 "$CERT_DEST/privkey.pem"
sudo chmod 600 "$CERT_DEST/dot.pem"

echo "Certificates deployed successfully!"
echo "Now run: docker compose restart haproxy"