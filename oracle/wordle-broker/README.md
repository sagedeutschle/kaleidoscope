# Wordgame Daily Broker

This broker keeps the app's daily Wordgame endpoint fresh without the iOS or
macOS clients contacting third-party puzzle sites.

Runtime path:

- Source object: `kaleidoscope-public/wordle/daily.json` in Supabase Storage
- Public proxy: `https://prismet.xyz/api/wordle`
- Local script: `oracle/wordle-broker/run-broker-mac.sh`
- LaunchAgent label: `com.gtrktscrb.wordle-broker.daily`

The script is intentionally idempotent. If the Supabase object already has
today's US/Eastern date, it exits before invoking Claude or touching Supabase.

## Install Or Refresh The LaunchAgent

```sh
cp oracle/wordle-broker/com.gtrktscrb.wordle-broker.daily.plist \
  ~/Library/LaunchAgents/com.gtrktscrb.wordle-broker.daily.plist
launchctl bootout gui/$(id -u) com.gtrktscrb.wordle-broker.daily 2>/dev/null || true
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/com.gtrktscrb.wordle-broker.daily.plist
launchctl print gui/$(id -u)/com.gtrktscrb.wordle-broker.daily
```

The current schedule runs at 01:15, 02:15, and 10:00 local time. The early
retries cover the midnight US/Eastern rollover; 10:00 is a recovery pass.

## Smoke Tests

```sh
curl -sS https://prismet.xyz/api/wordle
curl -sS https://cmufcjysgbiqhohozkrf.supabase.co/storage/v1/object/public/kaleidoscope-public/wordle/daily.json
```

Both should return JSON shaped like:

```json
{"answer":"amend","date":"2026-07-09","sourceName":"Daily"}
```

Generated `*.log` files in this directory are ignored.
