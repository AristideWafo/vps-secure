# vps-secure — Contexte projet

## But
Ansible role qui durcit l'accès SSH sur serveurs Ubuntu (Jammy/Noble). Un seul rôle : `ssh_hardening`.

## Ce qu'il fait
1. **SSH** (`tasks/ssh.yml` + `templates/sshd_config.j2`)
   - Port custom (défaut 2222), root login off, password auth off, pubkey only
   - Crypto restreinte : KexAlgorithms/Ciphers/MACs modernes (curve25519, chacha20-poly1305, hmac-sha2-*-etm)
   - AllowUsers/AllowGroups obligatoire (validé en amont)
   - MaxAuthTries, LoginGraceTime, ClientAlive*, forwarding désactivé (X11/Agent/TCP)
   - Config validée avec `sshd -t` avant déploiement (`validate:` sur le template)

2. **UFW** (`tasks/ufw.yml`)
   - Policy deny incoming / allow outgoing
   - Règles : SSH (limit), 80, 443 — extensible via `ssh_hardening_ufw_rules`

3. **Fail2ban** (`tasks/fail2ban.yml` + `templates/fail2ban_jail.local.j2`)
   - Jail sshd sur le port custom, ignoreip, bantime/findtime/maxretry configurables

4. **Validation pré-run** (`tasks/validate.yml`)
   - Assert port valide (0 < port < 65535)
   - Assert allow_users OU allow_groups non vide (anti-lockout)
   - Warning debug avant application

## Architecture
```
vps-secure/
├── ansible.cfg                 # inventory=inventories/dev, remote_user=ubuntu, become=sudo
├── playbooks/ssh_hardening.yml # pre_tasks: check OS=Ubuntu + deploy authorized_keys, puis role
├── inventories/dev/
│   ├── hosts.yml                # 1 host: dev-server-01
│   └── group_vars/all.yml       # override port, allow_users, ssh_authorized_keys, fail2ban_ignore_ips
└── roles/ssh_hardening/
    ├── defaults/main.yml        # toutes les variables par défaut
    ├── tasks/{main,ssh,ufw,fail2ban,validate}.yml
    ├── templates/{sshd_config.j2,fail2ban_jail.local.j2}
    ├── handlers/main.yml        # restart sshd, restart fail2ban
    └── meta/main.yml            # galaxy info, deps: []
```

## Dépendances
- Ansible ≥ 2.14
- Collections : `ansible.posix` (authorized_key), `community.general` (ufw) — **non listées dans meta/main.yml** (dependencies: [])
- Cible : Ubuntu Jammy/Noble uniquement, vérifié via assert en pre_tasks

## Workflow d'usage
- Premier run : port 22 en clair, password auth encore active, `--ask-pass --ask-become-pass`
- Après premier run : bascule port 2222, password auth désactivée, clés seules
- Tags disponibles : `ssh`, `ufw`, `fail2ban`, `keys`, `always`
- 1 seul environnement défini : `dev`

## État actuel
- Projet jeune (3 commits : Initial commit, init, add readme)
- Pas de CI, pas de tests, pas de molecule
- Pas de `requirements.yml` pour les collections
- Un seul inventaire (dev) — pas de prod/staging
- README bien rédigé, exemples clairs, tableau de variables à jour
