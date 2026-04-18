#!/bin/bash
 
set -euo pipefail
 
# ========================

# HELP

# ========================

show_help() {

cat << EOF

Trivy Scan Tool (Raw Mode - Clean Output)
 
Usage:

  ./main.sh --image <image_name> [options]
 
Options:

  --image <image_name>        (required)

  --email <emails>            (comma-separated, wrap in quotes)

                               Example: --email "a@x.com,b@y.com"

  --config <file>

  --severity <levels>         (LOW,MEDIUM,HIGH,CRITICAL — comma-separated)

  --retries <num>

  -h, --help
 
Notes:

  - Emails must be comma-separated

  - Always wrap multi-email input in quotes to avoid shell issues

  - Output is optimized to reduce Trivy noise (no progress, minimal logs)

EOF

}
 
# ========================

# CONFIG

# ========================

BASE_DIR="$(cd "$(dirname "$0")" && pwd)"

REPORT_DIR="$BASE_DIR/reports"

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

OUTPUT_FILE="$REPORT_DIR/trivy_$TIMESTAMP.txt"

RETRIES=3

SEVERITY=""
 
# ========================

# LOGGING

# ========================

info()       { echo "[+] $1"; }

warn()       { echo "[!] $1"; }

error_exit() { echo "[❌ ERROR] $1"; exit 1; }
 
# ========================

# ARGS

# ========================

[[ "$#" -eq 0 ]] && { show_help; exit 0; }
 
IMAGE=""

EMAIL=""

CONFIG_FILE=""
 
while [[ "$#" -gt 0 ]]; do

  case $1 in

    --image)    IMAGE="$2"; shift ;;

    --email)    EMAIL="$2"; shift ;;

    --config)   CONFIG_FILE="$2"; shift ;;

    --severity) SEVERITY="$2"; shift ;;

    --retries)  RETRIES="$2"; shift ;;

    -h|--help)  show_help; exit 0 ;;

    *) error_exit "Unknown param: $1" ;;

  esac

  shift

done
 
# ========================

# AUTO CONFIG

# ========================

DEFAULT_CONFIG="$BASE_DIR/config/smtp.conf"

if [[ -z "${CONFIG_FILE:-}" && -f "$DEFAULT_CONFIG" ]]; then

  CONFIG_FILE="$DEFAULT_CONFIG"

  info "Using default config: $CONFIG_FILE"

fi
 
# ========================

# VALIDATION

# ========================

info "Validating inputs..."
 
[[ -z "$IMAGE" ]] && error_exit "--image required"
 
if [[ -n "${EMAIL:-}" ]]; then

  IFS=',' read -ra RECIPIENTS <<< "$EMAIL"

  for r in "${RECIPIENTS[@]}"; do

    r="$(echo "$r" | xargs)"

    [[ "$r" =~ ^[^@]+@[^@]+\.[^@]+$ ]] || error_exit "Invalid email: $r"

  done

fi
 
if [[ -n "${EMAIL:-}" && -z "${CONFIG_FILE:-}" ]]; then

  error_exit "--config required when using email"

fi
 
[[ -n "${CONFIG_FILE:-}" && ! -f "$CONFIG_FILE" ]] && \

  error_exit "SMTP config not found"
 
# ========================

# SAFE CONFIG PARSER

# ========================

if [[ -n "${EMAIL:-}" ]]; then

  while IFS='=' read -r key value; do

    [[ -z "${key// }" || "$key" =~ ^[[:space:]]*# ]] && continue
 
    key="${key#"${key%%[![:space:]]*}"}"

    key="${key%"${key##*[![:space:]]}"}"
 
    value="${value:-}"

    value="${value#"${value%%[![:space:]]*}"}"
 
    if [[ "$value" =~ ^\".*\"$ ]]; then

      value="${value:1:-1}"

    elif [[ "$value" =~ ^\'.*\'$ ]]; then

      value="${value:1:-1}"

    fi
 
    case "$key" in

      SMTP_SERVER) SMTP_SERVER="$value" ;;

      SMTP_PORT)   SMTP_PORT="$value" ;;

      SMTP_USER)   SMTP_USER="$value" ;;

      SMTP_PASS)   SMTP_PASS="$value" ;;

      FROM_EMAIL)  FROM_EMAIL="$value" ;;

    esac

  done < "$CONFIG_FILE"

fi
 
# ========================

# DEPENDENCIES

# ========================

command -v trivy  >/dev/null || error_exit "trivy not installed"

command -v curl   >/dev/null || error_exit "curl missing"

command -v base64 >/dev/null || error_exit "base64 required"
 
mkdir -p "$REPORT_DIR"
 
# ========================

# SEVERITY HANDLING

# ========================

if [[ -z "$SEVERITY" ]]; then

  info "No severity specified → running full scan (ALL severities)"

  SEVERITY_FLAG=()

else

  SEVERITY=$(echo "$SEVERITY" | tr '[:lower:]' '[:upper:]' | tr -d ' ')

  [[ "$SEVERITY" =~ ^[A-Z,]+$ ]] || error_exit "Invalid severity format"

  info "Requested severity: $SEVERITY"

  SEVERITY_FLAG=(--severity "$SEVERITY")

fi
 
# ========================

# RETRY

# ========================

retry() {

  local c=0

  until "$@"; do

    ((c++)) || true

    [[ $c -ge $RETRIES ]] && error_exit "Operation failed after $RETRIES retries"

    warn "Retry $c/$RETRIES..."

    sleep 2

  done

}
 
# ========================

# RUN SCAN (CLEAN OUTPUT)

# ========================

info "Running Trivy scan (clean mode)..."
 
if ! retry trivy image \

  --quiet \

  --no-progress \

  --scanners vuln \

  "${SEVERITY_FLAG[@]}" \

  "$IMAGE" \
> "$OUTPUT_FILE" 2>&1; then

  error_exit "Trivy scan failed"

fi
 
[[ -s "$OUTPUT_FILE" ]] || warn "Report is empty — scan may have failed silently"
 
echo "[+] Report saved: $OUTPUT_FILE"
 
# ========================

# EMAIL

# ========================

send_email() {

  local subject="Trivy Scan Report [$TIMESTAMP]"

  local attachment="$OUTPUT_FILE"
 
  info "Preparing email with attachment..."
 
  EMAIL_TMP=$(mktemp)

  BOUNDARY="====BOUNDARY_$(date +%s)===="
 
  {

    echo "From: $FROM_EMAIL"

    echo "To: $EMAIL"

    echo "Subject: $subject"

    echo "MIME-Version: 1.0"

    echo "Content-Type: multipart/mixed; boundary=\"$BOUNDARY\""

    echo ""
 
    echo "--$BOUNDARY"

    echo "Content-Type: text/plain; charset=UTF-8"

    echo ""

    echo "Hi,"

    echo ""

    echo "Please find the attached Trivy scan report."

    echo ""

    echo "Generated: $TIMESTAMP"

    echo ""
 
    echo "--$BOUNDARY"

    echo "Content-Type: application/octet-stream; name=\"$(basename "$attachment")\""

    echo "Content-Disposition: attachment; filename=\"$(basename "$attachment")\""

    echo "Content-Transfer-Encoding: base64"

    echo ""
 
    base64 -w 76 "$attachment"
 
    echo ""

    echo "--$BOUNDARY--"

  } > "$EMAIL_TMP"
 
  RCPT_ARGS=()

  IFS=',' read -ra RECIPIENTS <<< "$EMAIL"

  for r in "${RECIPIENTS[@]}"; do

    r="$(echo "$r" | xargs)"

    RCPT_ARGS+=(--mail-rcpt "$r")

  done
 
  info "Sending email via SMTP..."
 
  curl --fail --show-error \

    --url "smtp://$SMTP_SERVER:$SMTP_PORT" \

    --ssl-reqd \

    --mail-from "$FROM_EMAIL" \

    "${RCPT_ARGS[@]}" \

    --upload-file "$EMAIL_TMP" \

    --user "$SMTP_USER:$SMTP_PASS"
 
  rm -f "$EMAIL_TMP"

}
 
if [[ -n "${EMAIL:-}" ]]; then

  retry send_email

  info "Email sent"

else

  info "Skipping email"

fi
 
# ========================

# FINAL

# ========================

echo "=========================================="

echo " Trivy Scan Completed Successfully ✅"

echo "=========================================="
