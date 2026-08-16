# Security Policy

Covenant is a governance/enforcement tool for AI-assisted development — its own security
posture matters more than most projects'. For the full technical threat model (what Covenant
reads/writes, what it never touches, what it explicitly does *not* protect against), see
[`CovenantMac/docs/SECURITY_POSTURE.md`](CovenantMac/docs/SECURITY_POSTURE.md). Read that document
before relying on Covenant for a compliance/audit story — it is deliberately specific about the
limits (keyword-only secrets scanning, a client-side agent-detection signal, an integrity
manifest with no external trust anchor until CODEOWNERS + branch protection are enabled) so
you can make an informed call about your own threat model.

## Reporting a vulnerability

If you find a security issue in Covenant itself (a bypass of the trust-root lockdown, a way to
defeat the integrity manifest, a flaw in the secrets scanner's matching logic, or anything
that would let an AI agent disarm its own governance undetected):

- **Do not open a public GitHub issue for it.**
- Open a [GitHub Security Advisory](../../security/advisories/new) on this repository (this
  is the private disclosure channel GitHub provides), or email the maintainer directly if
  you cannot use that path.
- Include: the affected version/commit, a reproduction, and the impact you believe it has.

We'll acknowledge reports within a few days and aim to have a fix or a documented mitigation
before any public disclosure. Given the project's current stage (see `CHANGELOG.md` for
version history), there is no bug-bounty program.

## What's already known and disclosed

[`CovenantMac/docs/SECURITY_POSTURE.md`](CovenantMac/docs/SECURITY_POSTURE.md) §7 already
documents every currently-known limitation in detail — check there first; if you've found
something not already listed, that's exactly the kind of report worth filing.
