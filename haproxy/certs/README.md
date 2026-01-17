# HAProxy Certificates Directory

Place your SSL/TLS certificates in this directory. HAProxy expects certificate files in PEM format.

## Setup Instructions

1. Generate or obtain your SSL certificates
2. Place them in this directory with a `.pem` extension
3. HAProxy will automatically use all `.pem` files in this directory

### Example: Creating a Self-Signed Certificate

```bash
openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes
cat cert.pem key.pem > combined.pem
```

Then place `combined.pem` in this directory.
