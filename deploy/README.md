# DevShield Docker Deployment Adapter

Cette couche déploie une image Harbor sur un hôte Docker/VPS après autorisation DevShield. Elle ne réinstalle pas Harbor et ne remplace pas OPA.

## Flux

```text
image@sha256:digest
        ↓
deployment authorization evidence
        ↓
pull exact digest
        ↓
compare local digest
        ↓
start controlled container
        ↓
healthcheck
        ├── PASS → deployment success
        └── FAIL → rollback previous digest
```

Le déploiement exige une référence construite sous la forme :

```text
HARBOR_REGISTRY/HARBOR_PROJECT/HARBOR_REPOSITORY@EXPECTED_DIGEST
```

Les tags mutables, `latest`, `main`, `dev`, `production` et `stable` sont refusés. `EXPECTED_DIGEST` et une evidence `AUTHORIZED` correspondant exactement au digest sont obligatoires.

## Fichiers

- `deploy.sh` : pull, contrôle de digest, remplacement contrôlé et rollback automatique ;
- `healthcheck.sh` : vérification du container et de l’URL de santé ;
- `rollback.sh` : restauration de la précédente référence immuable ;
- `common.sh` : validation et sérialisation de l’état ;
- `runtime.env.example` : configuration sans secrets.

## Configuration

Copier `runtime.env.example` vers un fichier géré par l’opérateur sur le VPS. Ne jamais le committer. Les credentials Harbor ne sont pas transmis au container applicatif : un éventuel `CONTAINER_ENV_FILE` doit être un fichier runtime séparé et protégé.

Variables principales :

```text
HARBOR_REGISTRY
HARBOR_PROJECT
HARBOR_REPOSITORY
EXPECTED_DIGEST
CONTAINER_NAME
CONTAINER_PORT
HOST_PORT
HEALTHCHECK_URL
HEALTHCHECK_TIMEOUT
HEALTHCHECK_RETRIES
DEPLOYMENT_ENVIRONMENT
RUNTIME_NETWORK
CONTAINER_ENV_FILE
ROLLBACK_ENABLED
DEVSHIELD_DEPLOYMENT_STATE_FILE
DEVSHIELD_DEPLOYMENT_AUTHORIZATION
```

## Exécution

L’evidence doit d’abord être produite par le contrat DevShield :

```bash
security/deployment/authorize.sh \
  --artifact "$HARBOR_REGISTRY/$HARBOR_PROJECT/$HARBOR_REPOSITORY@$EXPECTED_DIGEST" \
  --environment "$DEPLOYMENT_ENVIRONMENT" \
  --policy-input reports/policy-input.json \
  --output "$DEVSHIELD_DEPLOYMENT_AUTHORIZATION"
```

Puis le déploiement :

```bash
deploy/deploy.sh --env-file /etc/devshield/runtime.env
```

`deploy.sh` n’accepte aucune option `--force` et ne contient aucun bypass de l’autorisation.

## État et rollback

L’état est écrit hors Git, par défaut sous `/var/lib/devshield/deployment/<container>.json`, avec le digest courant, le digest précédent, l’environnement, l’evidence d’autorisation et le timestamp. Aucun secret n’y est stocké.

Le rollback vérifie la référence immuable et, lorsque l’evidence précédente est disponible, la revalide avant de démarrer l’ancienne version. Une défaillance du rollback produit `ROLLBACK_FAILED` et un état `rollback_failed`.

## Sécurité Docker

Le container est démarré avec `--cap-drop ALL`, `--security-opt no-new-privileges:true`, `--init`, une restart policy explicite, un port explicite et un réseau optionnel explicite. Un contrôle non-root est actif par défaut (`REQUIRE_NON_ROOT=1`). Aucun mode privilégié, socket Docker ou secret n’est ajouté.

## Limites

Cette phase ne configure pas Kubernetes, GitOps, Falco, Coraza, ZAP, Prometheus ou Grafana. Elle ne lance pas de déploiement pendant les tests. L’intégration GitHub Actions devra être ajoutée après validation locale/VPS de cet adaptateur.
