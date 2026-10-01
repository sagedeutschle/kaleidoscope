# Wordgame Daily Broker

Keeps the apps' Daily Wordgame word fresh. The iOS and macOS clients never contact
third-party puzzle sites: they read `https://prismet.xyz/api/wordle`, which proxies one
Supabase Storage object. This broker writes that object a few minutes after the
US-Eastern midnight rollover.

- Runtime: **Spelltower (archbox)**, systemd user timer `prismet-wordle-broker.timer`
  (moved off the Mac on 2026-10-01; the Mac LaunchAgent couldn't read the iCloud
  Desktop and had been failing since 2026-07-10).
- Source object: `kaleidoscope-public/wordle/daily.json` in Supabase Storage
- Public proxy: `https://prismet.xyz/api/wordle` (rejects any payload whose `date`
  isn't today in `America/New_York`)
- Code: `wordle_broker.py` (stdlib-only Python), tests in `tests/`

## Legal posture (do not weaken)

Carried over from the 2026-07-09 clean-room rebuild Sage approved:

1. **Never contacts nytimes.com** or any NYT infrastructure (the fetcher refuses NYT
   hosts and redirects). The answer is read from public games/news coverage that
   prints it every day. A single day's answer is an uncopyrightable fact.
2. **Only today's word** is published. No archive is kept or served.
3. **Cross-checked:** at least two *independent publishers* must state the same answer
   for the exact date and puzzle number, and no other answer may tie it.
4. The payload never uses the "Wordle" trademark (`sourceName` stays `"Daily"`).

## How a run decides

1. Reads the object from origin. If it already has today's date, exit 0 (one GET).
2. Fetches the sources below. Each parser only returns a word when the page ties it to
   today's exact date or puzzle number (`#N = days since 2021-06-19`), so a stale page or
   a markup change yields "no answer", never a guess.
3. Publishes when ≥2 independent publishers agree and no other answer ties them.
   TechRadar and Tom's Guide are both Future plc, so they count as **one** vote.
4. If there's no consensus, asks Codex (web search, on archbox's ChatGPT login) for one
   extra vote, at most 4 times a day. Codex alone can never publish.
5. PUTs `{"answer","date","sourceName":"Daily"}` with `Cache-Control: no-cache`, reads it
   back from origin, then polls `prismet.xyz/api/wordle` for up to ~3 minutes (a warning,
   not a failure, if the proxy lags).

Supabase's CDN keeps serving the previous object for about a minute after an upload, so
every read goes through a unique `?v=` query string to reach origin.

| Source | Publisher (vote) | What it reads |
|---|---|---|
| word.tips | word.tips | embedded `{date, number, answer}` data |
| wordfinder.yourdictionary.com | yourdictionary | embedded `{date:"YYMMDD", index, answer}` data |
| techradar.com | future-plc | "answer (game #N) is… WORD" |
| tomsguide.com | future-plc | "answer for game #N? … it's WORD" |
| rockpapershotgun.com | rockpapershotgun | per-day article "answer on Month D? … The word is… WORD" |

The puzzle goes live at each player's local midnight, so it's out in Asia-Pacific many
hours before New York, and these outlets post it the evening before (TechRadar and Tom's
Guide had 2026-10-01's answer up on 2026-09-30). By 00:03 ET the sources normally agree.

## Schedule

`systemd/prismet-wordle-broker.timer`: 00:03 ET, then every 10 minutes until 02:53,
then hourly at :03 as a catch-up. `Persistent=true` catches up after a reboot.
Once today's word is live, each run costs one GET.

## Deploy / operate (from the Mac)

```sh
bash oracle/wordle-broker/deploy_archbox.sh                  # sync code, run tests, install + enable timer, dry run
bash oracle/wordle-broker/deploy_archbox.sh --provision-key  # first time: install the Supabase key
bash oracle/wordle-broker/deploy_archbox.sh --run-now        # publish today's word immediately
ARCHBOX_HOST=saged@<ip> bash oracle/wordle-broker/deploy_archbox.sh   # if the LAN IP moved
```

The script uses strict host-key checking against the `archbox` known_hosts entry.

**Credential:** a dedicated Supabase secret API key named `wordle_broker_archbox`, stored
only at `~/.config/prismet-wordle-broker/supabase-key` (0600) on archbox. `--provision-key`
reveals or creates it through the Supabase CLI management token in the Mac login keychain
and pipes it straight to that file. It is never printed or passed as an argument. Revoke
it in the Supabase dashboard (Settings → API Keys) without affecting any other client.

On archbox:

```sh
journalctl --user -u prismet-wordle-broker.service -n 30 --no-pager   # last runs
systemctl --user list-timers prismet-wordle-broker.timer
cd ~/prismet-wordle-broker && python3 wordle_broker.py --dry-run       # what would publish now
python3 wordle_broker.py --check-key                                   # credential works (read-only)
python3 wordle_broker.py --force                                       # overwrite today's word
```

## Tests

```sh
cd oracle/wordle-broker && python3 -m unittest discover -s tests -v   # offline, synthetic fixtures
```

## Smoke

```sh
curl -sS https://prismet.xyz/api/wordle
curl -sS https://cmufcjysgbiqhohozkrf.supabase.co/storage/v1/object/public/kaleidoscope-public/wordle/daily.json
```

Both should return `{"answer":"ritzy","date":"2026-10-01","sourceName":"Daily"}`-shaped JSON
for today's US-Eastern date. A 502 `"still refreshing"` from the proxy means the object is
stale: check the journal on archbox.
