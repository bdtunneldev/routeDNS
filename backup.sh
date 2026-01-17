#!/bin/bash
# =============================================================================
# RouteDNS Production Backup Script
# =============================================================================
# Usage: ./backup.sh [daily|weekly|manual]
# Cron example: 0 2 * * * /path/to/backup.sh daily
# =============================================================================

set -euo pipefail

# Configuration
BACKUP_DIR="${BACKUP_DIR:-./backups}"
RETENTION_DAILY=7
RETENTION_WEEKLY=4
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_TYPE="${1:-manual}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Create backup directory
mkdir -p "${BACKUP_DIR}/${BACKUP_TYPE}"

log_info "Starting ${BACKUP_TYPE} backup at ${TIMESTAMP}"

# -----------------------------------------------------------------------------
# Backup Valkey Data
# -----------------------------------------------------------------------------
backup_valkey() {
    log_info "Backing up Valkey data..."
    
    # Trigger BGSAVE in Valkey
    docker compose exec -T valkey valkey-cli -a "${VALKEY_PASSWORD}" BGSAVE 2>/dev/null || true
    sleep 2
    
    # Copy the RDB file
    docker compose cp valkey:/data/dump.rdb "${BACKUP_DIR}/${BACKUP_TYPE}/valkey_${TIMESTAMP}.rdb" 2>/dev/null || {
        log_warn "Valkey backup skipped (no dump.rdb or container not running)"
        return 0
    }
    
    # Compress
    gzip -f "${BACKUP_DIR}/${BACKUP_TYPE}/valkey_${TIMESTAMP}.rdb"
    log_info "Valkey backup complete: valkey_${TIMESTAMP}.rdb.gz"
}

# -----------------------------------------------------------------------------
# Backup Grafana Data
# -----------------------------------------------------------------------------
backup_grafana() {
    log_info "Backing up Grafana data..."
    
    docker compose cp grafana:/var/lib/grafana "${BACKUP_DIR}/${BACKUP_TYPE}/grafana_${TIMESTAMP}" 2>/dev/null || {
        log_warn "Grafana backup skipped (container not running)"
        return 0
    }
    
    # Compress
    tar -czf "${BACKUP_DIR}/${BACKUP_TYPE}/grafana_${TIMESTAMP}.tar.gz" \
        -C "${BACKUP_DIR}/${BACKUP_TYPE}" "grafana_${TIMESTAMP}"
    rm -rf "${BACKUP_DIR}/${BACKUP_TYPE}/grafana_${TIMESTAMP}"
    
    log_info "Grafana backup complete: grafana_${TIMESTAMP}.tar.gz"
}

# -----------------------------------------------------------------------------
# Backup Prometheus Data (optional - can be large)
# -----------------------------------------------------------------------------
backup_prometheus() {
    if [[ "${BACKUP_PROMETHEUS:-false}" == "true" ]]; then
        log_info "Backing up Prometheus data..."
        
        # Create snapshot via Prometheus API
        curl -s -X POST "http://127.0.0.1:9090/api/v1/admin/tsdb/snapshot" || {
            log_warn "Prometheus snapshot failed"
            return 0
        }
        
        log_info "Prometheus snapshot created (check container for files)"
    else
        log_info "Prometheus backup skipped (set BACKUP_PROMETHEUS=true to enable)"
    fi
}

# -----------------------------------------------------------------------------
# Backup Configuration Files
# -----------------------------------------------------------------------------
backup_configs() {
    log_info "Backing up configuration files..."
    
    tar -czf "${BACKUP_DIR}/${BACKUP_TYPE}/configs_${TIMESTAMP}.tar.gz" \
        --exclude='*.pem' \
        --exclude='*.key' \
        --exclude='.env' \
        haproxy/haproxy.cfg \
        haproxy/lua/*.lua \
        routedns/config.toml \
        monitoring/prometheus/prometheus.yml \
        monitoring/grafana/provisioning \
        monitoring/grafana/dashboards \
        docker-compose.yml \
        2>/dev/null || log_warn "Some config files not found"
    
    log_info "Config backup complete: configs_${TIMESTAMP}.tar.gz"
}

# -----------------------------------------------------------------------------
# Cleanup Old Backups
# -----------------------------------------------------------------------------
cleanup_old_backups() {
    log_info "Cleaning up old backups..."
    
    case "${BACKUP_TYPE}" in
        daily)
            find "${BACKUP_DIR}/daily" -name "*.gz" -mtime +${RETENTION_DAILY} -delete 2>/dev/null || true
            find "${BACKUP_DIR}/daily" -name "*.rdb" -mtime +${RETENTION_DAILY} -delete 2>/dev/null || true
            ;;
        weekly)
            find "${BACKUP_DIR}/weekly" -name "*.gz" -mtime +$((RETENTION_WEEKLY * 7)) -delete 2>/dev/null || true
            find "${BACKUP_DIR}/weekly" -name "*.rdb" -mtime +$((RETENTION_WEEKLY * 7)) -delete 2>/dev/null || true
            ;;
    esac
    
    log_info "Cleanup complete"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    # Load environment
    if [[ -f .env ]]; then
        source .env
    fi
    
    backup_configs
    backup_valkey
    backup_grafana
    backup_prometheus
    cleanup_old_backups
    
    log_info "=========================================="
    log_info "Backup complete!"
    log_info "Location: ${BACKUP_DIR}/${BACKUP_TYPE}/"
    log_info "=========================================="
    
    # List backup files
    ls -lh "${BACKUP_DIR}/${BACKUP_TYPE}/"*"${TIMESTAMP}"* 2>/dev/null || true
}

main "$@"
