# Ubuntu Hardening Toolkit

Simple toolkit for hardening a fresh Ubuntu Server setup.

---

## What it does
* configures SSH safely
* sets up UFW with sane defaults
* enables automatic updates
* supports dry-run mode
* rolls back selected changes on failure

---

## Usage
```bash
git clone https://github.com/gnu-szymon/ubuntu-hardening-toolkit.git
cd ubuntu-hardening-toolkit
sudo bash main.sh
```
Dry run:
```bash
DRY_RUN=yes sudo bash main.sh
```
Configuration:
```bash
vim config/default.conf
```

---

## Notes
* tested on Ubuntu Server 24.04
* designed for fresh system installs
* not a full configuration management tool
