# DevShield — Security Event Logging

## Objectif

DevShield produit des événements de sécurité structurés sans embarquer de backend d'observabilité. Les événements sont écrits localement en JSON Lines afin d'être collectés par Fluent Bit, Vector, Filebeat, OpenTelemetry Collector ou un agent équivalent choisi par l'infrastructure.

```text
Security components → normalized event → reports/logs/security-events.jsonl
                                      → external collector → external service
```

Prometheus, Grafana, Loki, ELK, SIEM et SOAR ne sont pas des dépendances de DevShield Phase 14.

## Event contract

Chaque ligne est un objet JSON indépendant et contient au minimum :

```json
{
  "schema_version": "1.0",
  "event_id": "uuid",
  "timestamp": "2026-09-18T10:20:30Z",
  "event_type": "security.scan.completed",
  "severity": "INFO",
  "component": "trivy",
  "environment": "ci",
  "status": "PASS"
}
```

Les champs de corrélation sont conservés lorsqu'ils sont disponibles : `source.commit`, `pipeline.pipeline_id`, `pipeline.build_id`, `artifact.digest` et `deployment.deployment_id`. Le digest immuable est l'identifiant principal de corrélation d'un artifact.

Le schéma est versionné. Une modification compatible peut rester en `1.x`; une modification incompatible doit passer en `2.0`.

Les types acceptés sont déclarés dans `security/observability/logger.sh` et couvrent les événements pipeline, scans, SBOM, artifacts, policy, deployment, DAST, WAF et runtime. Un type inconnu est rejeté.

## Usage

```bash
make observability-validate

DEVSHIELD_LOG_FILE=reports/logs/security-events.jsonl \
  security/observability/logger.sh --event-json event.json
```

Ou créer un événement minimal :

```bash
security/observability/logger.sh \
  --event-type security.policy.deny \
  --component opa --severity ERROR --environment production \
  --status DENY --reason "policy denied artifact"
```

Le writer ne contacte aucun service réseau. Un échec d'export externe ne bloque donc pas l'écriture locale ni une décision de sécurité. Un échec d'écriture locale retourne `LOCAL_LOGGING_FAILURE`.

## Redaction

Avant écriture, le writer masque les champs dont le nom contient notamment `password`, `token`, `secret`, `api_key`, `private_key`, `authorization`, `cookie` ou `credential`. Il masque aussi les formes courantes telles que `Bearer TOKEN` et `password=value`.

La redaction est une protection de premier niveau, pas une classification complète. Les composants ne doivent pas envoyer de secrets inutiles au logger.

## Logs et evidence

`reports/logs/security-events.jsonl` est un journal opérationnel. Il ne remplace pas les evidences dédiées de SBOM, Cosign, OPA ou deployment authorization et ne fournit pas à lui seul une intégrité cryptographique.

## Rotation et rétention

La taille maximale par défaut est de 10 MiB (`DEVSHIELD_LOG_MAX_BYTES`). Lorsqu'elle est dépassée, le fichier courant est déplacé vers `security-events.jsonl.1` avant la nouvelle écriture. La rétention long terme et la suppression relèvent du CI ou du collecteur externe.

## Export externe

Le collecteur externe doit suivre le fichier, parser une ligne à la fois et conserver au minimum `event_type`, `severity`, `timestamp`, `component`, `environment`, `source.commit`, `artifact.digest`, `pipeline.pipeline_id`, `pipeline.build_id` et `deployment.deployment_id` lorsqu'ils existent. Aucun fournisseur n'est imposé.

## Failure semantics

Une panne d'export externe est distincte d'un échec de sécurité. Une vulnérabilité critique, un `OPA DENY` ou une autorisation refusée conservent leurs propres décisions. L'état local peut être `LOCAL_LOGGING=HEALTHY` et `EXTERNAL_EXPORT=NOT_CONFIGURED` ou `UNAVAILABLE`.

## Tests

```bash
make observability-validate
make observability-test
make observability-security
```

Les tests couvrent JSON invalide, champs absents, severity invalide, digest malformé, redaction, corrélation, événements OPA/WAF/Falco, absence de service externe, échec filesystem et écritures concurrentes.

## Limites

Cette phase n'installe pas de collecteur, ne fournit pas de dashboard, d'alerting ou de stockage long terme et n'intègre pas automatiquement chaque script historique. Les wrappers futurs doivent appeler le writer sans modifier les décisions de sécurité existantes.

