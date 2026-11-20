# Stage 6: optional AI gateway

HESABU's analysis remains local Dart code. The optional AI feature is an
isolated gateway, not a required service and not an MCP server. MCP is useful
for developer tooling; shipping it inside the desktop or Android app would add
an unnecessary listening/service surface.

## What is in this build

- `AiRequest` contains an explicitly constructed, minimised summary and the
  fields the future provider would receive. It cannot read or enumerate the
  database.
- `AiConsent` is created by the consent dialog and is bound to a fingerprint of
  the purpose, provider name, listed fields and exact summary.
- `ConsentGuardedAiService` rejects mismatched or stale consent before a
  provider adapter receives a request.
- `DisabledAiService` is the shipping default. There is no provider adapter,
  HTTP client, endpoint, API key, analytics upload or background queue.

The gateway is intentionally dormant in this release: there is no visible AI
control, menu item or consent-preview screen. It is not consent and does not
make a provider available. A future reviewed entry point must show the
disclosure and require a new approval for each actual send.

## Connecting a future provider

Create a provider adapter that implements `AiService`, wrap it in
`ConsentGuardedAiService`, and inject it only after product, privacy and
security review. The adapter must send only `AiRequest.approvedSummary` and its
explicit allow-list. It must not access the encrypted database, selected files,
passwords, secure-storage keys, device identifiers or logs containing business
data. Keep provider credentials out of the app; use a reviewed entitlement and
proxy design before production.

The user can decline the dialog and continue using every base analysis feature.
Clearing all local data also clears the local AI-controls preference.
