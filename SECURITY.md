# Security reporting

This is an experimental developer build; there is no supported production release or security support SLA.

Report a vulnerability privately through [GitHub private vulnerability reporting](https://github.com/Domogo/photo-views/security/advisories/new) when enabled. If that route is unavailable, contact the maintainer through the [Domogo profile](https://github.com/Domogo) to arrange a private channel. Do not post exploit details, secrets, personal photos or catalogs in a public issue. A public issue asking for a private contact without sensitive details is acceptable.

Include the affected commit, macOS/runtime versions, impact and a synthetic reproduction. Avoid sending a real photo library. See [PRIVACY.md](PRIVACY.md) for locally stored sensitive data.

The app uses native file access, a local SQLite catalog and subprocesses. Setup downloads packages and checksum-verified models; baseline inference has no hosted provider. Ad-hoc signing is for local development, not notarized distribution. Repository code, dependencies and downloaded models should be reviewed before use with sensitive archives.
