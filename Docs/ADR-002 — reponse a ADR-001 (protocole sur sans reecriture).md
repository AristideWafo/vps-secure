# ADR-002 — Réponse à ADR-001 : protocole d'apply sûr sans réécriture

2026-09-19 · Claude (vps-secure CLI)

## Statut

**Accepté, avec portée réduite.** Remplace la trajectoire "moteur Python + TUI" d'ADR-001 par une exécution incrémentale sur la stack existante (Bash CLI + rôle Ansible).

## Ce qui est repris d'ADR-001

- Le protocole d'apply sûr : sauvegarde, minuteur de rollback côté serveur, clé installée et **testée par connexion réelle** avant toute désactivation du mot de passe, sshd en double port, vérification externe avant de fermer l'ancien port.
- Les règles de validation BLOCK/WARN (accès non couvert par `allow_users`/`allow_groups`, empreinte de clé d'hôte changée, IP opérateur absente de la whitelist fail2ban, etc.).
- La correction d'un vrai trou de sécu déjà présent dans le projet : `ansible.cfg` a `host_key_checking = False` en dur — aucune protection MITM. À corriger.

## Ce qui est rejeté ou reporté

| Élément d'ADR-001 | Décision | Raison |
| --- | --- | --- |
| Réécriture Python + `ansible-runner` | Rejeté pour l'instant | Le CLI Bash actuel est testé et validé de bout en bout sur un vrai VPS (idempotent, 0 échec). Le réécrire avant d'avoir prouvé le besoin = risque élevé pour un gain non démontré. |
| État en fichiers TOML, modèle Server/Profile/Key/Run | Reporté | Scope "fleet management multi-serveur", pertinent seulement si plusieurs serveurs/utilisateurs réels apparaissent (cf. Phase 4 de IMPROVEMENTS.md). |
| Drift detection | Reporté | Même raison — utile une fois qu'il y a un existant à surveiller dans la durée. |
| TUI Textual | Reporté | Déjà tranché : pas de valeur tant qu'il n'y a pas d'état multi-serveur à visualiser en continu. |

## Mise en œuvre

Le protocole de sécurité et les règles de validation sont ajoutés comme évolutions du rôle Ansible existant (`roles/ssh_hardening`) et du CLI (`bin/vpssecure`), livrés en PR successives empilées :

1. Vérification d'empreinte de clé d'hôte (retire `host_key_checking = False`, ajoute un BLOCK explicite sur changement d'empreinte)
2. Clé testée par connexion réelle avant désactivation du mot de passe
3. sshd double port + UFW ouvre le nouveau port avant de fermer l'ancien
4. Minuteur de rollback côté serveur (`systemd-run --on-active=5min`)
5. Vérification externe post-apply + rollback automatique si échec

## Conséquences

**Positives** : le gain de sécurité principal d'ADR-001 (impossible de se verrouiller hors d'un serveur) arrive sans jeter le travail déjà testé, ni ajouter de nouvelle dépendance (Python/ansible-runner) à un outil qui fonctionne en Bash.

**Négatives** : pas de provenance affichée, pas de statuts dérivés, pas de gestion multi-profils — ces capacités restent à construire si le produit grandit.

**Révision** : si vps-secure gère un jour plusieurs serveurs par utilisateur avec des profils réutilisables, ADR-001 redevient pertinent et peut être ré-ouvert.
