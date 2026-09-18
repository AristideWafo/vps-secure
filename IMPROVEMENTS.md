# vps-secure — Fixes, améliorations, nouvelles features

## 🔴 Fixes (bugs / risques réels)

1. **`meta/main.yml` : `dependencies: []` alors que le rôle utilise `ansible.posix` et `community.general`**
   Rôle cassé sur machine sans ces collections pré-installées. Ajouter un `requirements.yml` à la racine :
   ```yaml
   collections:
     - name: ansible.posix
     - name: community.general
   ```
   + mention dans README (`ansible-galaxy collection install -r requirements.yml`).

2. **`inventories/dev/hosts.yml` : `ansible_ssh_private_key_file: "~/.ssh/key.pub"`**
   Pointe sur la clé **publique** (`.pub`) au lieu de la privée. Copier-coller foireux — cassera toute connexion SSH par clé. Corriger en `~/.ssh/key`.

3. **Pas de garde-fou anti-lockout réel**
   `validate.yml` affiche juste un `debug` warning — n'empêche rien. Si `ssh_authorized_keys` est vide ou mal formé, ou si `ansible_user` n'est pas dans `allow_users`, le déploiement casse l'accès SSH sans rollback possible (rôle non « two-phase »). Ajouter un `assert` bloquant : vérifier que `ssh_authorized_keys | length > 0` et qu'au moins une clé matche avant d'appliquer `PasswordAuthentication no`.

4. **`AuthorizedKeysFile .ssh/authorized_keys` en dur dans le template**
   Ignore le cas où l'utilisateur cible n'est pas `ubuntu` (le playbook déploie les clés uniquement pour `user: ubuntu` dans `pre_tasks`, mais `allow_users`/`allow_groups` peut désigner d'autres comptes). Généraliser le déploiement de clé par utilisateur listé dans `ssh_hardening_allow_users`.

5. **`ufw` policy outgoing = allow** (défaut) — cohérent avec un usage simple mais pas documenté comme choix de sécurité. Si un jour on durcit outgoing, il faudra des règles egress explicites (DNS, NTP, apt). À noter au moins en commentaire.

6. **Pas de gestion des host keys existantes / rotation**
   Le template référence `ssh_host_ed25519_key` et `ssh_host_rsa_key` mais rien ne garantit leur présence si `openssh-server` est fraîchement installé sur un système minimal (cloud-init peut les avoir supprimées). Ajouter une tâche `ssh-keygen -A` idempotente.

## 🟡 Améliorations qualité

- **CI** : ajouter GitHub Actions avec `ansible-lint` + `yamllint` + `ansible-playbook --syntax-check`. Zero CI actuellement.
- **Tests** : intégrer **Molecule** (docker driver) pour tester le rôle sur un conteneur Ubuntu avant tout run réel — critique vu le risque de lockout SSH.
- **Idempotence** : vérifier via `--check --diff` en CI que 2 runs consécutifs ne produisent aucun changement.
- **`ansible.cfg`** : `host_key_checking = False` en dur — pratique mais dangereux en environnement partagé (MITM silencieux). Documenter le compromis ou passer par `known_hosts` géré.
- **Secrets** : aucune clé privée/API dans le repo actuellement (bien), mais pas de `.gitignore` pour `*.retry`, `vault.yml`, etc. Ajouter un `.gitignore` minimal.
- **Vault** : pas d'usage d'`ansible-vault` — si un jour on ajoute des secrets (ex: notif Slack sur ban fail2ban), prévoir dès maintenant `group_vars/all/vault.yml`.
- **Multi-environnement** : un seul inventaire `dev`. Prévoir `inventories/prod/` avec sa propre structure pour matcher le README qui parle déjà de "environnements".
- **Documentation inline** : `playbooks/ssh_hardening.yml` mélange commentaires FR et code — cohérent avec le README (FR), mais uniformiser (`meta/main.yml` a author "jerry" — incohérent avec l'auteur réel, à corriger).
- **Tags manquants** : pas de tag `validate` séparé, pas de tag `fail2ban` distinct testable isolément malgré son usage dans `main.yml` (en fait si — mais README ne le documente pas). Documenter tous les tags dans README.
- **Molecule scenario pour rollback** : tester qu'un `ssh_hardening_password_authentication: no` mal configuré est rattrapable (ex: via console web du provider).

## 🟢 Nouvelles features (valeur ajoutée)

1. **Rôle `base_hardening` complémentaire** : unattended-upgrades, sysctl hardening (disable IP forwarding sauf besoin, SYN cookies, ASLR), auditd, chrony/ntp sync — étendre au-delà du SSH pour un vrai "VPS secure".

2. **Rotation / gestion multi-clé avec expiration** : support de clés avec commentaire de date, tâche qui alerte si une clé a > N mois (hygiène).

3. **Notifications fail2ban** : intégration webhook (Slack/Discord/ntfy) sur ban — variable `ssh_hardening_fail2ban_notify_webhook`.

4. **Support 2FA SSH (PAM + Google Authenticator ou TOTP)** : option `ssh_hardening_enable_2fa` pour environnements sensibles.

5. **Rapport de conformité** : tâche finale qui génère un résumé (port, auth methods, ufw status, fail2ban status) exporté en JSON/Markdown après chaque run — utile pour audit.

6. **Support d'autres OS** : Debian, ou distros RHEL-like (dnf au lieu d'apt, firewalld au lieu d'ufw) — ouvrir le champ d'application au-delà d'Ubuntu.

7. **Bootstrap "zero to secure"** : script/playbook d'amorçage qui automatise le cycle port 22 → 2222 en un seul run avec confirmation interactive, au lieu du process manuel en 5 étapes documenté au README.

8. **Scan de vulnérabilités post-run** : intégration `lynis` ou `openscap` en tâche optionnelle pour valider le durcissement obtenu.

9. **Ansible collection packaging** : publier `ssh_hardening` comme collection Galaxy réutilisable (namespace + `galaxy.yml`) pour que d'autres projets puissent la consommer sans copier le repo.

10. **Dashboard/état** : petit playbook `status.yml` qui interroge fail2ban (bans actifs), sshd (sessions actives), ufw (règles actives) — visibilité opérationnelle sans se connecter manuellement.

## Priorisation suggérée
1. Fix #1 et #2 (cassent le rôle / la doc immédiatement)
2. Fix #3 (risque de lockout — le plus dangereux)
3. CI + Molecule (empêche la régression future)
4. Feature #1 (base_hardening) pour vraie valeur "vps-secure" au-delà du SSH
