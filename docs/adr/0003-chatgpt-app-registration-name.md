# 0003 ChatGPT sign-in registers the app as "Pinpoint"

Status: accepted (2026-11-27)

**Decision:** "Sign in with ChatGPT" uses OpenAI's dynamic app registration with agent name `Pinpoint` (`ChatGPTOAuth.agentName`, `Sources/PinpointCore/ChatGPTPlan.swift`). The issued client and tokens are kept in the Keychain.

**Why:** lets people use their ChatGPT plan without an API key.

**Consequences:** users see this name when approving access. Changing it or the registration flow means existing users have to sign in again.
