# DevShield Falco rules

These rules are additive custom rules loaded after the official Falco rules. They detect suspicious runtime behavior and do not kill processes, terminate containers or isolate networks. Rule changes are versioned with the repository and must include positive and negative test cases.

The rules intentionally use container context and emit image repository/tag fields. Falco may not expose an image digest in every Docker event; the normalizer records a digest only when the event supplies one and never invents it.

No global disable, `continue-on-error` behavior or rule exclusion is configured.
