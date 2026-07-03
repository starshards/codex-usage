export function redactSourceText(text) {
  return String(text)
    .replace(/(authorization\s*:\s*bearer\s+)[^\s\\]+/gi, "$1[REDACTED]")
    .replace(/(cookie\s*:\s*)[^\n\r]+/gi, "$1[REDACTED]")
    .replace(/("accessToken"\s*:\s*")[^"]+(")/gi, "$1[REDACTED]$2")
    .replace(/("id_token"\s*:\s*")[^"]+(")/gi, "$1[REDACTED]$2")
    .replace(/("session"\s*:\s*")[^"]+(")/gi, "$1[REDACTED]$2")
    .replace(/("(?:user_id|account_id|email)"\s*:\s*")[^"]+(")/gi, "$1[REDACTED]$2");
}
