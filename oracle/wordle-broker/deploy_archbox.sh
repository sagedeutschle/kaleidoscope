#!/usr/bin/env bash
# Deploy the Wordgame Daily broker to Spelltower (archbox) as a systemd user timer.
#
# Run from the Mac:
#   bash oracle/wordle-broker/deploy_archbox.sh                  # code + tests + units + dry run
#   bash oracle/wordle-broker/deploy_archbox.sh --provision-key  # also install the Supabase key
#   bash oracle/wordle-broker/deploy_archbox.sh --run-now        # also publish today's word now
#
# Host identity is the host key, not the IP: strict checking against the `archbox`
# known_hosts entry. Spelltower's LAN IP drifts; override with ARCHBOX_HOST=saged@<ip>.
#
# --provision-key uses the Supabase CLI management token in the Mac login keychain to
# reveal (or create) a dedicated secret API key named wordle_broker_archbox, and pipes it
# straight into ~/.config/prismet-wordle-broker/supabase-key (0600) on archbox. The key is
# never printed, logged, or passed as a command-line argument. Revoke it in the Supabase
# dashboard (Settings > API Keys) without touching any other client.
set -euo pipefail

HOST="${ARCHBOX_HOST:-saged@10.2.1.11}"
SSH_KEY="${ARCHBOX_SSH_KEY:-$HOME/.ssh/id_ed25519}"
SSH=(ssh -o BatchMode=yes -o ConnectTimeout=8 -o StrictHostKeyChecking=yes
     -o HostKeyAlias=archbox -i "$SSH_KEY" "$HOST")
HERE="$(cd "$(dirname "$0")" && pwd)"
REMOTE_DIR="prismet-wordle-broker"
PROJECT_REF="cmufcjysgbiqhohozkrf"
KEY_NAME="wordle_broker_archbox"
UNIT="prismet-wordle-broker"

PROVISION=0
RUN_NOW=0
for arg in "$@"; do
  case "$arg" in
    --provision-key) PROVISION=1 ;;
    --run-now) RUN_NOW=1 ;;
    *) echo "unknown option: $arg" >&2; exit 2 ;;
  esac
done

say() { printf '\033[1;36m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

"${SSH[@]}" true 2>/dev/null \
  || die "archbox unreachable at $HOST (flaky Alfa Wi-Fi: wait and retry, or set ARCHBOX_HOST)."
say "connected to $("${SSH[@]}" hostname) via $HOST"

# 1. code -------------------------------------------------------------------------
COPYFILE_DISABLE=1 tar -C "$HERE" --exclude '__pycache__' --no-xattrs -cf - \
    wordle_broker.py tests systemd \
  | "${SSH[@]}" "mkdir -p ~/$REMOTE_DIR && tar -C ~/$REMOTE_DIR --warning=no-unknown-keyword -xf -"
say "synced to $HOST:~/$REMOTE_DIR"

say "offline test suite on archbox"
"${SSH[@]}" "cd ~/$REMOTE_DIR && python3 -m unittest discover -s tests -q"

# 2. key (optional) -----------------------------------------------------------------
if (( PROVISION )); then
  say "provisioning dedicated Supabase secret key '$KEY_NAME' (never printed)"
  MGMT_TOKEN="$(security find-generic-password -s "Supabase CLI" -w 2>/dev/null \
    | sed 's/^go-keyring-base64://' | base64 -d 2>/dev/null || true)"
  [[ -n "$MGMT_TOKEN" ]] || die "no Supabase CLI token in the login keychain (run 'supabase login')."
  MGMT_TOKEN="$MGMT_TOKEN" PROJECT_REF="$PROJECT_REF" KEY_NAME="$KEY_NAME" /usr/bin/python3 - <<'PY' \
    | "${SSH[@]}" 'umask 077 && mkdir -p ~/.config/prismet-wordle-broker &&
        cat > ~/.config/prismet-wordle-broker/supabase-key.tmp &&
        test -s ~/.config/prismet-wordle-broker/supabase-key.tmp &&
        mv ~/.config/prismet-wordle-broker/supabase-key.tmp ~/.config/prismet-wordle-broker/supabase-key &&
        chmod 600 ~/.config/prismet-wordle-broker/supabase-key'
import json, os, sys, urllib.error, urllib.request

token, ref, name = os.environ["MGMT_TOKEN"], os.environ["PROJECT_REF"], os.environ["KEY_NAME"]
base = f"https://api.supabase.com/v1/projects/{ref}/api-keys"

def call(method, url, body=None):
    req = urllib.request.Request(url, method=method, data=json.dumps(body).encode() if body else None,
                                 headers={"Authorization": f"Bearer {token}",
                                          "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=20) as resp:
            return json.load(resp)
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode(errors="replace")[:300]
        sys.exit(f"supabase management API {method} -> {exc.code}: {detail}")

existing = [k for k in call("GET", base) if k.get("type") == "secret" and k.get("name") == name]
if existing:
    key = call("GET", f"{base}/{existing[0]['id']}?reveal=true")
    print(f"reusing existing secret key {name}", file=sys.stderr)
else:
    key = call("POST", f"{base}?reveal=true", {
        "type": "secret", "name": name,
        "description": "Wordgame Daily broker on Spelltower (archbox); revoke freely",
        "secret_jwt_template": {"role": "service_role"},
    })
    print(f"created secret key {name}", file=sys.stderr)
api_key = key.get("api_key") or ""
if not api_key.startswith("sb_secret_"):
    sys.exit("management API did not return a revealed sb_secret_ key")
sys.stdout.write(api_key + "\n")
PY
  unset MGMT_TOKEN
  "${SSH[@]}" "cd ~/$REMOTE_DIR && python3 wordle_broker.py --check-key" \
    || die "key check failed on archbox"
fi

# 3. units --------------------------------------------------------------------------
say "installing systemd user units"
"${SSH[@]}" bash -s <<REMOTE
set -euo pipefail
mkdir -p ~/.config/systemd/user
install -m 644 ~/$REMOTE_DIR/systemd/$UNIT.service ~/$REMOTE_DIR/systemd/$UNIT.timer ~/.config/systemd/user/
systemd-analyze --user verify ~/.config/systemd/user/$UNIT.service ~/.config/systemd/user/$UNIT.timer
systemctl --user daemon-reload
systemctl --user enable --now $UNIT.timer
systemctl --user list-timers $UNIT.timer --no-pager
REMOTE

say "live dry run on archbox (reads sources, publishes nothing)"
"${SSH[@]}" "cd ~/$REMOTE_DIR && python3 wordle_broker.py --dry-run --no-llm --force" || true

if (( RUN_NOW )); then
  say "running the broker now"
  "${SSH[@]}" "systemctl --user start $UNIT.service; journalctl --user -u $UNIT.service -n 15 --no-pager -o cat"
fi
say "done. Logs: ssh archbox journalctl --user -u $UNIT.service"
