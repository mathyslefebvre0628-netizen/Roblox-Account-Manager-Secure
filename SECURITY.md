# Security Policy

## Scope

This project is a security-hardened continuation of the archived Roblox Account Manager. It is intended to protect locally stored account data and reduce the attack surface of local API/WebSocket features.

## Security rules

- Never commit `.ROBLOSECURITY` cookies, passwords, API tokens, `AccountData.json`, or exported account databases.
- Local API and WebSocket features must bind to loopback only unless a future release explicitly documents a secure authenticated remote mode.
- Authentication secrets must be generated locally and must never be written to logs.
- Dangerous developer/automation features are disabled by default.
- Updates must use HTTPS and should be integrity-verified before execution.

## Reporting

If you find a security vulnerability, do not publish credentials, cookies, proof-of-concept account takeovers, or other sensitive material in a public issue. Open a private security report through GitHub's security reporting mechanism when available, or contact the repository owner privately.
