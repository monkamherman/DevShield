# DevShield — Deployment Readiness Report

## A. Résumé exécutif

Le repository contient une chaîne de sécurité avancée jusqu’à l’autorisation de déploiement :

~~~text
SAST → Secrets → SCA → Container Scan → SBOM → Harbor optionnel → Cosign optionnel → OPA → Deployment Authorization
~~~

Le déploiement réel n’est pas encore implémenté.

- Harbor est considéré comme déjà installé et fonctionnel sur le VPS, conformément au contexte fourni.
- Aucun manifeste de déploiement, Docker Compose applicatif ou script de déploiement VPS n’est présent.
- Le workflow GitHub Actions ne déploie pas l’application.
- DAST, WAF et Falco sont préparés mais optionnels/non déployés.
- Le dépôt était propre au moment de l’audit.
- Branche : dev.
- Dernier commit : 1c6a204 feat(security): implement structured security event logging and observability contract.

Références : .github/workflows/security.yml, deploy/README.md, README.md.

## B. Composants

| Composant | Code présent | Configuré | CI intégré | VPS requis | État |
|---|---:|---:|---:|---:|---|
| Semgrep | Oui | Oui | Oui | Non | READY |
| Gitleaks | Oui | Oui | Oui | Non | READY |
| Trivy SCA | Oui | Oui | Oui | Non | READY |
| Trivy Container | Oui | Oui | Oui | Non | READY |
| Syft SBOM | Oui | Oui | Oui | Non | READY |
| Cosign | Oui | Oui | Optionnel | Harbor | PARTIAL |
| OPA/Rego | Oui | Oui | Oui | Non | READY |
| OWASP ZAP | Oui | Oui | Optionnel | Staging | PARTIAL |
| Falco | Oui | Oui | Non | Hôte Docker/Linux | PARTIAL |
| Coraza | Oui | Oui | Validation uniquement | Reverse proxy | PARTIAL |
| OWASP CRS | Oui, image externe | Oui | Validation uniquement | WAF | PARTIAL |
| Harbor | Intégration présente | Exemple configuré | Optionnel | Oui | PARTIAL |
| Robot Account | Non vérifiable dans Git | Variables prévues | Oui | Oui | PARTIAL |
| Promotion d’images | Non | Non | Non | Oui | MISSING |
| Déploiement applicatif | Non | Non | Non | Oui | MISSING |
| Rollback | Non | Non | Non | Oui | MISSING |
| Docker Compose applicatif | Non | Non | Non | Oui | MISSING |
| Monitoring externe | Non | Non | Non | Oui | MISSING |

## C. CI/CD

Le workflow ci.yml vérifie la fondation du repository et exécute make help, make lint, make test et make build. Il ne construit pas encore une application métier réelle.

Le workflow security.yml contient :

1. Semgrep ;
2. Gitleaks ;
3. Trivy SCA ;
4. build et scan container ;
5. génération et validation SBOM ;
6. security gate ;
7. publication Harbor optionnelle ;
8. signature et vérification Cosign optionnelles ;
9. décision OPA ;
10. deployment authorization optionnelle ;
11. DAST optionnel ;
12. validation WAF optionnelle.

Chaîne réellement disponible :

~~~text
Push / Pull Request
  ↓
Semgrep + Gitleaks + Trivy + Container/SBOM
  ↓
Security Gate
  ↓
Harbor optionnel
  ↓
Cosign optionnel sur main
  ↓
OPA
  ↓
Deployment Authorization optionnelle
  ↓
DAST optionnel
  ↓
WAF validation optionnelle
~~~

Absents : deployment réel, rollback, promotion Harbor, runtime Falco dans le workflow et validation post-déploiement complète.

Points importants :

- Harbor est activé par DEVSHIELD_HARBOR_ENABLED.
- Harbor utilise un runner self-hosted.
- Cosign est limité aux pushes vers main lorsque DEVSHIELD_COSIGN_ENABLED=true.
- Cosign utilise GitHub OIDC keyless.
- L’autorisation dépend de DEVSHIELD_DEPLOYMENT_ENABLED.
- DAST nécessite une cible déjà déployée ; le workflow ne la déploie pas.
- WAF réalise une validation, pas une protection production.
- Falco n’est pas intégré au workflow.

## D. Harbor

Harbor est déjà installé sur le VPS selon le contexte fourni. Sa réinstallation n’est pas nécessaire.

Le flux DevShield prévu est :

~~~text
Image scannée → docker save → runner self-hosted → docker load → Harbor push → digest → Cosign
~~~

security/registry/push.sh :

- exige le security gate ;
- utilise HARBOR_REGISTRY, HARBOR_PROJECT et HARBOR_REPOSITORY ;
- utilise HARBOR_USERNAME et HARBOR_PASSWORD ;
- pousse un tag sha-<commit> ;
- récupère le digest Harbor ;
- compare le digest Harbor au digest du build ;
- écrit reports/registry-push-evidence.json.

Gaps :

- hostname réel du VPS absent du repository ;
- Robot Account réel non vérifiable dans Git ;
- RBAC effectif non vérifiable dans Git ;
- promotion entre environnements absente ;
- SBOM non attaché comme artefact OCI Harbor ;
- rétention VPS non vérifiable depuis le repository ;
- signature encore optionnelle dans le workflow.

## E. Security Stack

| Outil | État réel |
|---|---|
| Semgrep | READY — version 1.172.0, configuration, CI et tests présents. |
| Gitleaks | READY — version 8.30.1, configuration, rapport redacted, CI et tests présents. |
| Trivy SCA | READY — version 0.73.0, politique CRITICAL/HIGH/UNKNOWN bloquante, tests présents. |
| Trivy Container | READY — scan image et Dockerfile, digest associé, CI et tests présents. |
| Syft | READY — version 1.51.0, SBOM CycloneDX JSON et inventory validée. |
| Cosign | PARTIAL — version 3.1.3, key-based local et keyless CI présents ; validation VPS et déploiement réel manquants. |
| OPA/Rego | READY — OPA 1.20.2, policy versionnée, tests et décisions ALLOW/DENY présents. |
| OWASP ZAP | PARTIAL — version 2.15.0, baseline JSON/HTML et allowlist ; pas de staging réel. |
| Falco | PARTIAL — version 0.44.1, Modern eBPF, règles et evidence ; pas de runtime VPS. |
| Coraza | PARTIAL — configuration et tests Docker ; pas de reverse proxy production. |
| OWASP CRS | PARTIAL — version 4.25.0 et règles versionnées ; trafic réel et tuning manquants. |

## F. Deployment

Le repository ne contient pas de déploiement applicatif réel. deploy/ contient uniquement une documentation confirmant l’absence de runtime, manifests, Kubernetes, GitOps et rollback.

security/deployment/authorize.sh valide un digest immuable et produit une evidence. Il ne lance aucun container.

Manquants :

- deploy.sh ;
- rollback.sh ;
- healthcheck post-déploiement ;
- Docker Compose ou autre orchestrateur applicatif ;
- stratégie de remplacement de container ;
- promotion d’environnements ;
- liaison vérifiable entre digest autorisé et container lancé.

## G. Runtime Security

### Falco

Configuration et tests statiques présents. Déploiement runtime VPS absent.

~~~text
Configuration : READY
Tests statiques : READY
Runtime réel : PARTIAL
Production : MISSING
~~~

### Coraza/CRS

Wrapper Docker de test présent. Reverse proxy production absent.

### Logs

Le writer JSONL Phase 14 existe dans security/observability/. Il fournit validation, redaction, event ID, timestamp et corrélation digest/commit/pipeline/deployment. Tous les composants historiques ne l’utilisent pas encore automatiquement.

### Monitoring

Aucun Prometheus, Grafana, Loki, SIEM ou système d’alerting n’est intégré. Cette absence est volontaire pour la Phase 14.

## H. Secrets

### GitHub Secrets

~~~text
HARBOR_USERNAME
HARBOR_PASSWORD
~~~

### GitHub Variables

~~~text
HARBOR_REGISTRY
HARBOR_PROJECT
HARBOR_REPOSITORY
DEVSHIELD_HARBOR_ENABLED
DEVSHIELD_COSIGN_ENABLED
DEVSHIELD_TRUSTED_SIGNER
DEVSHIELD_POLICY_ENVIRONMENT
DEVSHIELD_DEPLOYMENT_ENABLED
DEVSHIELD_DAST_ENABLED
DEVSHIELD_DAST_TARGET_URL
DEVSHIELD_DAST_ALLOWED_HOSTS
DEVSHIELD_DAST_ENVIRONMENT
DEVSHIELD_DAST_ARTIFACT
DEVSHIELD_WAF_ENABLED
DEVSHIELD_WAF_UPSTREAM
~~~

### Variables locales/runtime

~~~text
HARBOR_URL
HARBOR_CA_CERT
HARBOR_TAG
EXPECTED_DIGEST
COSIGN_PASSWORD
COSIGN_CERTIFICATE_IDENTITY
COSIGN_CERTIFICATE_OIDC_ISSUER
DEVSHIELD_COSIGN_PRIVATE_KEY
DEVSHIELD_COSIGN_PUBLIC_KEY
TARGET_UPSTREAM
RUNTIME_ARTIFACT_DIGEST
~~~

### Secrets Harbor locaux

~~~text
HARBOR_INSTALLER_SHA256
HARBOR_ADMIN_PASSWORD
HARBOR_DATABASE_PASSWORD
HARBOR_USERNAME
HARBOR_PASSWORD
~~~

Les secrets SSH de déploiement et secrets runtime applicatifs ne sont pas déclarés dans le repository.

## I. Tests

| Domaine | Tests présents |
|---|---|
| SAST | Fixtures positive/négative |
| Secrets | Fixtures positive/négative |
| SCA | Clean/vulnerable/tool failure |
| Container | Build, non-root, vulnerable, no-secret |
| SBOM | Valid/corrupt/mismatch/missing digest |
| Cosign | Digest, signer, missing signature |
| OPA | Allow/deny/tampering |
| Deployment authorization | Digest/tag/OPA failure |
| DAST | Target, URL invalide, finding, tool failure |
| WAF | Configuration/evidence/runtime Docker |
| Falco | Règles/evidence/failure |
| Observability | JSONL/redaction/correlation/concurrency |
| End-to-end VPS | Absent |

Les tests n’ont pas été relancés durant cet audit afin de respecter la contrainte stricte de lecture seule.

Tests manquants :

- build → push Harbor VPS → sign → verify ;
- authorization → déploiement réel ;
- container lancé avec le digest autorisé ;
- WAF devant l’application réellement déployée ;
- DAST contre cette application ;
- Falco contre ce container ;
- rollback après échec healthcheck ;
- corrélation complète de l’artifact jusqu’au runtime ;
- validation du Robot Account réel ;
- test de promotion Harbor.

## J. Gaps

### BLOCKER

1. Aucun déploiement applicatif réel.
2. Aucun script ou manifest de déploiement VPS.
3. Aucun rollback.
4. Aucun healthcheck post-déploiement relié au rollback.
5. Aucun mécanisme garantissant que le container lancé correspond au digest autorisé.
6. Aucun runtime production réellement configuré.
7. Aucun test end-to-end complet.

### HIGH

1. Harbor publication optionnelle.
2. Cosign optionnel.
3. Deployment authorization optionnelle.
4. DAST et WAF optionnels.
5. Falco absent du workflow et du VPS.
6. SBOM non attaché à Harbor.
7. Promotion par digest absente.
8. Robot Account/RBAC réel non vérifiable dans Git.
9. Actions GitHub non pinées par SHA.
10. Environnement CI par défaut potentiellement development.
11. Aucune validation post-push automatique depuis le VPS.

### MEDIUM

1. Logger non intégré automatiquement dans tous les composants.
2. Rétention des logs JSONL côté VPS non définie.
3. Collecteur externe non configuré.
4. TLS production WAF non défini.
5. Tuning CRS sur trafic réel absent.
6. Authentification DAST absente.
7. Backup/restore Harbor non validé depuis DevShield.
8. Base image Docker non pinée par digest.

### LOW

1. Dashboard externe absent.
2. Alerting externe absent.
3. API de monitoring absente.
4. OpenTelemetry non intégré.
5. Promotion multi-environnements à formaliser.
6. Rotation avancée des certificats et clés à documenter côté exploitation.

## K. Deployment Roadmap

### 1. Valider DevShield → Harbor VPS

Objectif : confirmer l’accès du runner au Harbor VPS.

~~~bash
HARBOR_URL=<url-vps> make registry-status
HARBOR_REGISTRY=<registry> \
HARBOR_USERNAME=<robot-account> \
HARBOR_PASSWORD=<secret> \
make registry-test
~~~

Résultat attendu : Harbor accessible, authentification réussie et cohérence du digest.

### 2. Activer la publication Harbor

Configurer :

~~~text
DEVSHIELD_HARBOR_ENABLED=true
HARBOR_REGISTRY
HARBOR_PROJECT
HARBOR_REPOSITORY
HARBOR_USERNAME
HARBOR_PASSWORD
~~~

Résultat attendu : image publiée et digest égal au digest buildé/scanné.

### 3. Activer Cosign keyless sur main

Configurer :

~~~text
DEVSHIELD_COSIGN_ENABLED=true
DEVSHIELD_TRUSTED_SIGNER
COSIGN_CERTIFICATE_IDENTITY
COSIGN_CERTIFICATE_OIDC_ISSUER
~~~

Résultat attendu : signature et vérification réussies sur le digest Harbor exact.

### 4. Configurer OPA en production

Configurer :

~~~text
DEVSHIELD_POLICY_ENVIRONMENT=production
DEVSHIELD_TRUSTED_REGISTRY
DEVSHIELD_TRUSTED_SIGNER
DEVSHIELD_TRUSTED_REPOSITORY
~~~

Résultat attendu : ALLOW uniquement avec registry, digest, SBOM, signature, signer et provenance conformes.

### 5. Créer l’adaptateur de déploiement VPS

Fichiers futurs :

~~~text
deploy/deploy.sh
deploy/rollback.sh
deploy/healthcheck.sh
deploy/runtime.env.example
~~~

Résultat attendu : seul le digest autorisé est lancé ; les tags mutables sont refusés ; le healthcheck est obligatoire ; l’échec déclenche un rollback.

### 6. Déployer l’application

L’unique application disponible est la fixture apps/fixture. Il manque encore son orchestration runtime.

### 7. Placer Coraza devant l’application

Configurer upstream, réseau Docker, port public, TLS et règles CRS.

### 8. Exécuter DAST sur staging

Configurer la target, l’allowlist d’hôtes, l’environnement staging et le digest exact.

### 9. Déployer Falco sur le nœud runtime

Configurer le host Docker/Linux, Modern eBPF, règles, permissions et collecte des événements.

### 10. Valider la chaîne end-to-end

~~~text
Source → Build → Security Gate → Harbor → Digest → Cosign → OPA → Authorization → Deployment → WAF → DAST → Falco → Security Logs
~~~

## L. Première prochaine action

**NEXT ACTION**

Valider depuis le runner destiné au déploiement la connectivité et l’authentification du Robot Account vers le Harbor VPS avec make registry-status puis make registry-test, sans modifier la configuration ni pousser une image de production.

