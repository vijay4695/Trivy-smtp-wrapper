# Trivy Static Analysis Wrapper

A lightweight wrapper tool for running Static Application Security Testing (SAST) using Trivy on local codebases or Git repositories.

This tool provides a safe and reproducible scanning workflow by executing scans on an isolated copy of the source code.

The wrapper ensures:

- No modification of the original source code
- Raw Trivy output without parsing or filtering
- Clean and reproducible scans
- Optional email delivery of reports via SMTP


--------------------------------------------------
INSTALLATION
--------------------------------------------------

Run the installer script:
```bash
chmod +x install.sh
./install.sh
```
The installer automatically installs required dependencies.

Dependencies installed:

- Docker
- Git
- Curl
- Rsync
- jq
- Trivy


--------------------------------------------------
USAGE
--------------------------------------------------

View help menu:
```bash
./main.sh -h
```

--------------------------------------------------
BASIC EXAMPLES
--------------------------------------------------

Scan a local project
```bash
./main.sh --file-path /path/to/project
```

Scan a Git repository
``` bash
./main.sh --repo https://github.com/user/repo.git
```

Scan and send email report
``` bash
./main.sh --file-path /path/to/project --email you@example.com
```
If email configuration is not provided, the tool automatically loads:

config/smtp.conf


--------------------------------------------------
SEVERITY FILTERING (OPTIONAL)
--------------------------------------------------
``` bash
./main.sh --file-path /project --severity HIGH,CRITICAL
```
Default scan includes:

UNKNOWN, LOW, MEDIUM, HIGH, CRITICAL


--------------------------------------------------
SMTP CONFIGURATION
--------------------------------------------------

SMTP configuration file location:

config/smtp.conf

Example configuration:
``` bash
SMTP_SERVER="smtp.gmail.com"
SMTP_PORT="587"
SMTP_USER="your_email@gmail.com"
SMTP_PASS="your_app_password"
FROM_EMAIL="your_email@gmail.com"
```
The install.sh script can create this file interactively.


--------------------------------------------------
SCANNER ENGINE
--------------------------------------------------

This wrapper uses Trivy filesystem scanning.

Internal command used:
``` bash
trivy fs --severity <levels> --scanners vuln,secret,misconfig
```
Trivy detects:

- Vulnerabilities
- Secrets
- Misconfigurations


--------------------------------------------------
PROJECT STRUCTURE
--------------------------------------------------

.
├── main.sh
├── install.sh
├── config/
│   └── smtp.conf
├── reports/
└── temp/


--------------------------------------------------
OUTPUT
--------------------------------------------------

Reports are stored in:

reports/

Example report filename:

reports/sast_YYYYMMDD_HHMMSS.txt

Reports contain raw Trivy scan results.


--------------------------------------------------
SCAN WORKFLOW
--------------------------------------------------

Local Code / Git Repository
        │
        ▼
Wrapper Script
        │
        ▼
Isolated Workspace (rsync copy)
        │
        ▼
Trivy Filesystem Scan
        │
        ▼
Raw Report Generated
        │
        ▼
Optional SMTP Email Delivery


--------------------------------------------------
FEATURES
--------------------------------------------------

- Safe isolated scan directory
- Raw Trivy output (no modification)
- Full severity scanning by default
- Optional severity filtering
- SMTP email delivery
- Git repository support
- Retry logic for stable scanning


--------------------------------------------------
SECURITY NOTES
--------------------------------------------------

- The original source code is never modified
- Scans run on an isolated temporary copy
- Results are not filtered or altered
- Email delivery is optional


--------------------------------------------------
USE CASES
--------------------------------------------------

- Security testing (VAPT)
- Developer self-assessment
- DevSecOps pipelines
- Pre-deployment security checks
- Bulk repository scanning


--------------------------------------------------
QUICK START
--------------------------------------------------
``` bash
chmod +x install.sh
./install.sh

./main.sh --file-path ./your-project
```
