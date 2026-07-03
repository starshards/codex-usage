# Usage Source Contract

Date: 2026-07-03

## Source

- Browser: Google Chrome
- Authentication: existing Chrome ChatGPT session
- Method: GET
- URL: `https://chatgpt.com/backend-api/wham/usage`
- Response kind: JSON
- Fixture: `extension/fixtures/usage-source-v1.redacted.json`

## Required Fields

- 5-hour Codex usage comes from top-level `rate_limit.primary_window`.
- Weekly Codex usage comes from top-level `rate_limit.secondary_window`.
- The source field is `used_percent`, so the displayed remaining percentage is `100 - used_percent`, clamped to `0...100`.
- The 5-hour reset label is derived from `primary_window.reset_at` and displayed as local `HH:mm`.
- The weekly reset label is derived from `secondary_window.reset_at` and displayed as a local weekday abbreviation.

## Excluded Fields

- `additional_rate_limits` is not displayed. In particular, model-specific limits such as `GPT-5.3-Codex-Spark` must not affect the two menu bar lines.
- Credits, spend controls, promo fields, and referral fields are not displayed in the initial menu bar app.

## Redaction Rules

- Do not store request headers.
- Do not store cookies.
- Do not store tokens.
- Do not store raw non-redacted HTML or JSON.
- Do not store user identity values such as `user_id`, `account_id`, or `email`.
- Fixtures may keep quota labels, percentages, reset timestamps, and object keys needed by the parser.

## Failure Rule

If this authenticated source stops exposing both quota windows, implementation stops and the product design must be revisited.
