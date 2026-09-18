# ADR-014 — Structured Security Event Logging

## Statut

Accepté pour la Phase 14.

## Contexte

DevShield produit des evidences provenant de contrôles différents : scanners, Cosign, OPA, deployment authorization, ZAP, Coraza et Falco. Ces événements doivent être corrélables et exportables, mais le dépôt ne doit pas imposer un backend d'observabilité ou un service réseau.

## Décision

DevShield écrit des événements de sécurité normalisés dans `reports/logs/security-events.jsonl`. Chaque ligne est un événement JSON indépendant avec un schéma versionné `1.0`, un `event_id`, un timestamp, un type, une severity, un composant, un environnement et un statut. Les identifiants d'artifact, de pipeline, de build, de deployment et de commit sont conservés lorsqu'ils sont disponibles.

Le writer valide le type, la severity, le statut, le timestamp et le digest avant écriture. Il applique une redaction minimale des champs et motifs sensibles. Il n'appelle aucun service externe. Le fichier est borné par taille et l'ancienne génération est conservée en `.1`.

Un collecteur externe reste responsable du transport, stockage long terme, dashboards, recherche et alerting.

## Alternatives rejetées pour cette phase

Prometheus/Grafana, Loki, ELK/OpenSearch, OpenTelemetry Collector embarqué, SIEM et SOAR sont volontairement hors périmètre. Ils pourront être raccordés par l'infrastructure sans changer le contrat JSONL.

## Raisons

Cette décision apporte un faible couplage, la portabilité local/CI, l'absence de dépendance réseau pour journaliser, une intégration simple avec plusieurs collecteurs et une séparation claire entre logs et evidences de sécurité. Elle évite de transformer l'observabilité en nouvelle couche de décision.

## Implications de sécurité

Les secrets ne doivent pas être fournis au logger. La redaction intégrée masque les motifs courants, mais elle ne remplace pas la minimisation à la source. Un échec d'export externe ne devient pas automatiquement un `OPA DENY` ou un blocage de déploiement. Un échec d'écriture locale est explicite et peut être traité par le workflow selon la criticité de l'événement.

Les logs ne sont pas une preuve cryptographique. Les evidences Cosign, OPA, SBOM et deployment authorization restent dans leurs formats dédiés.

## Évolution

Un adaptateur vers le collecteur retenu pourra être ajouté ultérieurement. Il devra conserver le schéma, éviter les labels à forte cardinalité et préserver les corrélateurs, en particulier `artifact.digest`.

