import test from "node:test";
import assert from "node:assert/strict";
import { redactSourceText } from "../src/redactSource.js";

test("redacts obvious secrets while preserving usage words", () => {
  const input = [
    "authorization: Bearer secret-token",
    "cookie: session=abc123",
    "5h usage remaining 72% resets at 18:30",
    "weekly usage remaining 41% resets Monday"
  ].join("\n");

  const redacted = redactSourceText(input);

  assert.equal(redacted.includes("secret-token"), false);
  assert.equal(redacted.includes("abc123"), false);
  assert.equal(redacted.includes("5h usage remaining 72%"), true);
  assert.equal(redacted.includes("weekly usage remaining 41%"), true);
});

test("redacts identity fields from JSON usage responses", () => {
  const input = JSON.stringify({
    user_id: "user-secret",
    account_id: "account-secret",
    email: "person@example.com",
    rate_limit: {
      primary_window: {
        used_percent: 17
      }
    }
  });

  const redacted = redactSourceText(input);

  assert.equal(redacted.includes("user-secret"), false);
  assert.equal(redacted.includes("account-secret"), false);
  assert.equal(redacted.includes("person@example.com"), false);
  assert.equal(redacted.includes('"used_percent":17'), true);
});
