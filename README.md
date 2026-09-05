# Roblox Account Manager Secure

Security-hardened continuation of the archived Roblox Account Manager project.

## Security goals

- Protect local account data with Windows current-user protection.
- Never log Roblox session cookies, passwords, or API tokens.
- Keep local APIs and WebSockets on loopback by default.
- Require authentication for local control endpoints.
- Validate input, paths, commands, and message sizes.
- Keep dangerous developer/automation features opt-in.
- Run automated secret scanning and build checks in GitHub Actions.

## Important

This project does **not** bypass Roblox security, anti-cheat, bans, or account protections. It is focused on protecting credentials and reducing the local attack surface.

> Never commit `AccountData.json`, `.ROBLOSECURITY` cookies, passwords, API tokens, or other secrets to Git.

## Status

The security foundation is being built first. The legacy application code will be imported and adapted only after its authentication, storage, network, logging, and update paths have been reviewed.
