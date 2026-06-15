# vps-secure — SSH Hardening

Ansible automation to harden SSH access on Ubuntu servers.

Applies the `ssh_hardening` role which configures:
- **SSH** — custom port, key-only authentication, modern crypto
- **UFW** — minimal firewall rules (SSH, 80, 443)
- **Fail2ban** — brute-force protection

---

## Requirements

- Ansible ≥ 2.14 (`pip install ansible`)
- Collection `ansible.posix`: `ansible-galaxy collection install ansible.posix`
- SSH access to the server (password for the first run, key-based afterwards)

---

## Structure

```
vps-secure/
├── ansible.cfg                          # Global Ansible config
├── playbooks/
│   └── ssh_hardening.yml                # Main playbook
├── inventories/
│   └── dev/
│       ├── hosts.yml                    # Target servers
│       └── group_vars/
│           └── all.yml                  # Variables (port, keys, fail2ban…)
└── roles/
    └── ssh_hardening/                   # Hardening role
```

---

## Customization

### 1. Add / update a server — `inventories/dev/hosts.yml`

```yaml
dev-server-01:
  ansible_host: 54.xx.xx.xx
  ansible_user: ubuntu
  ansible_port: 2222             # SSH port (after the first run)
  ansible_ssh_private_key_file: "~/.ssh/key"
```

> On the **first run**, the server still listens on port `22`. Set `ansible_port: 22` first, then switch back to `2222` after.

### 2. Authorize SSH keys — `inventories/dev/group_vars/all.yml`

```yaml
ssh_authorized_keys:
  - "ssh-ed25519 AAAA... user@macbook"
  - "ssh-ed25519 AAAA... deploy@github-actions"
```

Get your local public key with:
```bash
cat ~/.ssh/id_ed25519.pub
```

### 3. Change the SSH port

In `group_vars/all.yml`:
```yaml
ssh_hardening_port: 2222   # change here
```

Then update `ansible_port` in `hosts.yml` accordingly.

### 4. Fail2ban whitelist (static IPs, VPN…)

```yaml
ssh_hardening_fail2ban_ignore_ips:
  - 127.0.0.1/8
  - ::1
  - 203.0.113.42    # your static IP
```

### 5. Open additional UFW ports

In `group_vars/all.yml`, override `ssh_hardening_ufw_rules`:
```yaml
ssh_hardening_ufw_rules:
  - { rule: limit, port: "2222", proto: tcp }
  - { rule: allow, port: 80,    proto: tcp }
  - { rule: allow, port: 443,   proto: tcp }
  - { rule: allow, port: 5432,  proto: tcp }   # Postgres
```

---

## First run (fresh server, password authentication)

> Password authentication is not yet disabled.

**Step 1** — Set the port to `22` in `hosts.yml` (the server still listens on 22):
```yaml
ansible_port: 22
```

**Step 2** — Fill in `ssh_authorized_keys` in `group_vars/all.yml` with your public key.

**Step 3** — Run in check mode first:
```bash
ansible-playbook -i inventories/dev playbooks/ssh_hardening.yml --check --ask-pass --ask-become-pass
```

**Step 4** — If everything looks good, apply for real:
```bash
ansible-playbook -i inventories/dev playbooks/ssh_hardening.yml --ask-pass --ask-become-pass
```

**Step 5** — Switch `ansible_port` back to `2222` in `hosts.yml`. Password authentication is now disabled.

---

## Subsequent runs (SSH key in place)

```bash
# Dry run
ansible-playbook -i inventories/dev playbooks/ssh_hardening.yml --check

# Apply
ansible-playbook -i inventories/dev playbooks/ssh_hardening.yml

# SSH only (skip UFW and Fail2ban)
ansible-playbook -i inventories/dev playbooks/ssh_hardening.yml --tags ssh

# SSH keys only
ansible-playbook -i inventories/dev playbooks/ssh_hardening.yml --tags keys

# Single server
ansible-playbook -i inventories/dev playbooks/ssh_hardening.yml --limit dev-server-01
```

---

## Role variables (all defined in `defaults/main.yml`)

| Variable | Default | Description |
|---|---|---|
| `ssh_hardening_port` | `2222` | SSH port |
| `ssh_hardening_permit_root_login` | `no` | Disable root login |
| `ssh_hardening_password_authentication` | `no` | Disable password authentication |
| `ssh_hardening_max_auth_tries` | `3` | Max authentication attempts before disconnect |
| `ssh_hardening_allow_users` | `[]` | Allowed Unix users (required) |
| `ssh_hardening_allow_groups` | `[]` | Allowed Unix groups (required if allow_users is empty) |
| `ssh_hardening_fail2ban_ban_time` | `3600` | Ban duration in seconds |
| `ssh_hardening_fail2ban_max_retry` | `5` | Failed attempts before ban |
| `ssh_hardening_configure_ufw` | `true` | Enable/disable UFW configuration |
| `ssh_hardening_configure_fail2ban` | `true` | Enable/disable Fail2ban configuration |
