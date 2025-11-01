# My Vanilla Balance Checker (Apify Actor)
Rotates mobile device fingerprints and proxy session/IP per attempt using undetected Chrome.

## Secrets
Add a secret `APIFY_PROXY_PASSWORD` in the Actor's Settings → Secrets.

## Example input
{
  "url": "https://balance.vanillagift.com",
  "card_number": "4097580568698481",
  "exp_month": "02",
  "exp_year": "30",
  "cvv": "835",
  "max_attempts": 3,
  "use_apify_proxy": true,
  "apify_proxy_groups": "RESIDENTIAL",
  "apify_proxy_country": "US",
  "rotate_devices": true,
  "device_pool": ["iphone_13","iphone_14","pixel_7"],
  "apify_proxy_sessions": ["sessA","sessB","sessC"],
  "take_screenshot": true,
  "push_html_snapshot": true
}
