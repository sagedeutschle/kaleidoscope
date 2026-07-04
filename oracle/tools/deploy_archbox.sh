#!/usr/bin/env bash
# Deploy / update The Wizard King's Decree on archbox (Claude Max SUBSCRIPTION path).
#
# Run from the Mac:   bash tools/deploy_archbox.sh
#
# archbox specifics (verified 2026-06-26):
#   * `claude` is an npm-global binary at ~/.local/share/npm/bin/claude (authed to the Max plan)
#   * Arch ships NO cron -> we use a systemd *user* timer + linger
#   * `--config` is a GLOBAL flag: `wkd --config PATH run`  (NOT `wkd run --config PATH`)
#   * DHCP IP drifts; try mDNS + known IPs (archbox is on a different tailnet than this Mac)
set -euo pipefail

KEY="${WKD_SSH_KEY:-$HOME/.ssh/id_ed25519}"
HOSTS=("saged@archbox.lan" "saged@192.168.0.114" "saged@192.168.0.113" "saged@100.108.54.108")
REMOTE_DIR="/home/saged/wizard-kings-decree"
LOCAL_DIR="$(cd "$(dirname "$0")/.." && pwd)"
RUN_AT="${WKD_RUN_AT:-09:00:00}"

say() { printf '\033[1;35m==>\033[0m %s\n' "$*"; }
die() { printf '\033[1;31mERROR:\033[0m %s\n' "$*" >&2; exit 1; }

# 1. pick a reachable host -----------------------------------------------------
HOST=""
for h in "${HOSTS[@]}"; do
  if ssh -i "$KEY" -o ConnectTimeout=10 -o StrictHostKeyChecking=accept-new "$h" true 2>/dev/null; then HOST="$h"; break; fi
done
[ -n "$HOST" ] || die "archbox unreachable. Power it on / reconnect WiFi (its DHCP IP drifts; find it by MAC f8:3d:c6:b1:db:24), then retry."
say "using $HOST"

# 2. prereqs (claude authed on the Max plan) -----------------------------------
ssh -i "$KEY" "$HOST" 'python3 --version' || die "python3 missing on archbox."
ssh -i "$KEY" "$HOST" 'export PATH=$HOME/.local/share/npm/bin:$PATH; command -v claude >/dev/null' \
  || die "'claude' CLI not found on archbox. Install it / log into the Max plan first."
say "checking the subscription is authed (one tiny Haiku call)…"
ssh -i "$KEY" "$HOST" 'export PATH=$HOME/.local/share/npm/bin:$PATH; claude -p "reply: OK" --output-format json --model haiku 2>/dev/null | grep -q "\"is_error\":false"' \
  || die "'claude -p' failed on archbox — likely NOT logged in. Run 'claude' there (VNC) to authenticate, then retry."
say "subscription works on archbox"

# 3. sync code (exclude ONLY runtime artifacts — never wkd/chronicle.py!) -------
rsync -az --delete \
  --exclude '__pycache__' --exclude '*.pyc' --exclude '.git' \
  --exclude '*.db' --exclude '/chronicle/' --exclude '/chronicle-worldcup/' --exclude 'daily.log' \
  -e "ssh -i $KEY" \
  "$LOCAL_DIR/" "$HOST:$REMOTE_DIR/"
say "synced to $HOST:$REMOTE_DIR"

# 4. health check: offline suite on archbox ------------------------------------
say "running the offline test suite on archbox…"
ssh -i "$KEY" "$HOST" "cd $REMOTE_DIR && python3 -m unittest discover -s tests -t . 2>&1 | tail -3"

# 5. wrapper + systemd user timer (+ linger) -----------------------------------
ssh -i "$KEY" "$HOST" RUN_AT="$RUN_AT" 'bash -s' <<'REMOTE'
set -e
export XDG_RUNTIME_DIR="/run/user/$(id -u)"
mkdir -p ~/.config/systemd/user

cat > ~/wizard-kings-decree/run-daily.sh <<'WRAP'
#!/usr/bin/env bash
export PATH="$HOME/.local/share/npm/bin:$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
export WKD_DB_PATH="$HOME/wizard-kings-decree/worldcup.db"
export WKD_CHRONICLE_DIR="$HOME/wizard-kings-decree/chronicle-worldcup"
cd "$HOME/wizard-kings-decree" || exit 1
echo "----- $(date -u +%FT%TZ) -----" >> "$HOME/wizard-kings-decree/daily.log"
python3 -m wkd --config config.worldcup.json run >> "$HOME/wizard-kings-decree/daily.log" 2>&1
WRAP
chmod +x ~/wizard-kings-decree/run-daily.sh

cat > ~/.config/systemd/user/wkd-daily.service <<'SVC'
[Unit]
Description=The Wizard King's Decree - daily run
[Service]
Type=oneshot
ExecStart=%h/wizard-kings-decree/run-daily.sh
SVC

cat > ~/.config/systemd/user/wkd-daily.timer <<TMR
[Unit]
Description=Daily Wizard King's Decree run
[Timer]
OnCalendar=*-*-* ${RUN_AT}
Persistent=true
[Install]
WantedBy=timers.target
TMR

sudo loginctl enable-linger saged
systemctl --user daemon-reload
systemctl --user enable --now wkd-daily.timer
systemctl --user list-timers --no-pager | grep -i wkd || true
REMOTE

cat <<EOF

Deploy complete on $HOST.
  • code:      $REMOTE_DIR        (offline suite green)
  • daily run: $REMOTE_DIR/run-daily.sh   (systemd user timer wkd-daily.timer @ $RUN_AT)
  • log:       $REMOTE_DIR/daily.log
  • chronicle: $REMOTE_DIR/chronicle-worldcup/index.html

Smoke-test now:   ssh $HOST '$REMOTE_DIR/run-daily.sh'
NOTE: until a fixtures SOURCE is wired, daily runs harvest nothing (seed matters manually).
EOF
