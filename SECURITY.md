# Security Policy

## Supported versions

LambdaDeck is currently in alpha. Security fixes may land without backporting.

## Reporting a vulnerability

Please do not open a public GitHub issue for security vulnerabilities.

Instead, use GitHub Security Advisories for private disclosure:

- Go to the repository page on GitHub.
- Click "Security" -> "Report a vulnerability".

If you cannot use GitHub Security Advisories, open a minimal issue that asks for a private contact channel and do not include exploit details.

## Security notes / threat model

LambdaDeck is intended for trusted local use.

- There is no authentication/authorization layer.
- Do not expose the server to untrusted networks.
- Prefer binding to localhost (default is `127.0.0.1`).
- If you bind to `0.0.0.0`, treat the server as accessible to your LAN and assume requests are not trusted.

The API currently implements a subset of the OpenAI surface focused on chat.
