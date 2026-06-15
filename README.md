# ff-ansible — SSH Hardening

Automatisation du durcissement SSH sur les serveurs Ubuntu via Ansible.

Ce projet applique le rôle `ssh_hardening` qui configure :
- **SSH** — port personnalisé, auth par clé uniquement, crypto moderne
- **UFW** — firewall avec règles minimales (SSH, 80, 443)
- **Fail2ban** — protection contre le brute-force

---

## Prérequis

- Ansible ≥ 2.14 (`pip install ansible`)
- Collection `ansible.posix` : `ansible-galaxy collection install ansible.posix`
- Accès SSH au serveur (mot de passe pour le premier run, clé ensuite)

---

## Structure

```
ff-ansible/
├── ansible.cfg                          # Config globale Ansible
├── playbooks/
│   └── ssh_hardening.yml                # Playbook principal
├── inventories/
│   └── dev/
│       ├── hosts.yml                    # Serveurs cibles
│       └── group_vars/
│           └── all.yml                  # Variables (port, clés, fail2ban…)
└── roles/
    └── ssh_hardening/                   # Rôle de durcissement
```

---

## Personnalisation

### 1. Ajouter / modifier un serveur — `inventories/dev/hosts.yml`

```yaml
dev-server-01:
  ansible_host: 54.37.51.84     # IP du serveur
  ansible_user: ubuntu           # User de connexion
  ansible_port: 2222             # Port SSH (après le premier run)
  ansible_ssh_private_key_file: "~/.ssh/fairfare_dev"
```

> Lors du **premier run**, le port est encore `22`. Change `ansible_port: 22` avant, puis remets `2222` après.

### 2. Autoriser des clés SSH — `inventories/dev/group_vars/all.yml`

```yaml
ssh_authorized_keys:
  - "ssh-ed25519 AAAA... aristide@macbook"
  - "ssh-ed25519 AAAA... deploy@github-actions"
```

Récupère ta clé publique locale avec :
```bash
cat ~/.ssh/id_ed25519.pub
```

### 3. Changer le port SSH

Dans `group_vars/all.yml` :
```yaml
ssh_hardening_port: 2222   # change ici
```

Puis mets à jour `ansible_port` dans `hosts.yml` en conséquence.

### 4. Whitelist Fail2ban (IP fixes, VPN…)

```yaml
ssh_hardening_fail2ban_ignore_ips:
  - 127.0.0.1/8
  - ::1
  - 203.0.113.42    # ton IP fixe
```

### 5. Ouvrir des ports supplémentaires dans UFW

Dans `group_vars/all.yml`, surcharge la variable `ssh_hardening_ufw_rules` :
```yaml
ssh_hardening_ufw_rules:
  - { rule: limit, port: "2222", proto: tcp }
  - { rule: allow, port: 80,    proto: tcp }
  - { rule: allow, port: 443,   proto: tcp }
  - { rule: allow, port: 5432,  proto: tcp }   # Postgres
```

---

## Premier lancement (serveur vierge, auth par mot de passe)

> Le mot de passe SSH n'est pas encore désactivé.

**Étape 1** — Passe le port à `22` dans `hosts.yml` (le serveur écoute encore sur 22) :
```yaml
ansible_port: 22
```

**Étape 2** — Remplis `ssh_authorized_keys` dans `group_vars/all.yml` avec ta clé publique.

**Étape 3** — Lance en mode simulation d'abord :
```bash
ansible-playbook -i inventories/dev playbooks/ssh_hardening.yml --check --ask-pass --ask-become-pass
```

**Étape 4** — Si tout est OK, applique pour de vrai :
```bash
ansible-playbook -i inventories/dev playbooks/ssh_hardening.yml --ask-pass --ask-become-pass
```

**Étape 5** — Repasse le port à `2222` dans `hosts.yml`. L'auth par mot de passe est désormais désactivée.

---

## Lancements suivants (clé SSH en place)

```bash
# Simulation
ansible-playbook -i inventories/dev playbooks/ssh_hardening.yml --check

# Application
ansible-playbook -i inventories/dev playbooks/ssh_hardening.yml

# Cibler uniquement SSH (sans UFW ni Fail2ban)
ansible-playbook -i inventories/dev playbooks/ssh_hardening.yml --tags ssh

# Cibler uniquement les clés SSH
ansible-playbook -i inventories/dev playbooks/ssh_hardening.yml --tags keys

# Un seul serveur
ansible-playbook -i inventories/dev playbooks/ssh_hardening.yml --limit dev-server-01
```

---

## Variables du rôle (toutes dans `defaults/main.yml`)

| Variable | Défaut | Description |
|---|---|---|
| `ssh_hardening_port` | `2222` | Port SSH |
| `ssh_hardening_permit_root_login` | `no` | Désactive le login root |
| `ssh_hardening_password_authentication` | `no` | Désactive l'auth par mot de passe |
| `ssh_hardening_max_auth_tries` | `3` | Tentatives max avant déconnexion |
| `ssh_hardening_allow_users` | `[]` | Users Unix autorisés (obligatoire) |
| `ssh_hardening_allow_groups` | `[]` | Groupes Unix autorisés (obligatoire si allow_users vide) |
| `ssh_hardening_fail2ban_ban_time` | `3600` | Durée de ban en secondes |
| `ssh_hardening_fail2ban_max_retry` | `5` | Tentatives avant ban |
| `ssh_hardening_configure_ufw` | `true` | Active/désactive UFW |
| `ssh_hardening_configure_fail2ban` | `true` | Active/désactive Fail2ban |
