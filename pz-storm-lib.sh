#!/usr/bin/env bash
#
# pz-storm-lib.sh — shared engine for the storm-*.sh event scripts.
# Not run directly. Each storm-*.sh sources this and calls run_storm "$@".
#
# Every storm is built by patching a pristine baseline, so storms can never
# stack and ending one is just "apply the baseline with no overrides".

set -euo pipefail

# Eastern wall-clock time (DST-aware), matching zomboid-server's own
# TZ=America/Toronto -- storms.sh already exports this too, so this line is
# what makes it correct even if a storm-*.sh is ever run standalone outside
# storms.sh's own process tree.
export TZ=America/Toronto

# ---------------------------------------------------------------- config ---
CONFIG_DIR="/opt/app/zomboid/config/Server"
SERVER_CONFIG_NAME="YourServerName"     # NOTE: if yours contains a space, keep it quoted.
CONTAINER="zomboid-server"

RCON_HOST="127.0.0.1"
RCON_PORT="27015"
RCON_PASS_FILE="/root/.pz-rcon"          # chmod 600

WARN_MINUTES=5                           # 0 to restart immediately

# Permanent top of the MOTD. The storm block is appended below it.
BASE_MOTD="Welcome to the server. Questions or problems, come find an admin. Have fun!"

INI_FILE="${CONFIG_DIR}/${SERVER_CONFIG_NAME}.ini"
SANDBOX_FILE="${CONFIG_DIR}/${SERVER_CONFIG_NAME}_SandboxVars.lua"
BASELINE_FILE="${CONFIG_DIR}/baseline_SandboxVars.lua"
LOCK_FILE="/root/pz-restart.lock"           # same file caretaking.sh's LOCK= uses -- keep them matching
END_UNIT="pz-storm-end"                     # legacy systemd unit, still cleaned up on start
STORM_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACTIVE_FILE="${STORM_DIR}/.active_storm"    # "<script> <end epoch>" - survives reboots
LAST_END_FILE="${STORM_DIR}/.last_storm_end" # epoch of the last end

# ------------------------------------------------------------------ guts ---
log()  { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }
die()  { log "ERROR: $*" >&2; exit 1; }
running() { [ "$(docker inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null)" = "true" ]; }

# No mcrcon binary on this host - same minimal raw RCON client pz-caretaking.sh uses.
RCON_PY="$(mktemp /tmp/pz-storm-rcon.XXXXXX.py)"
trap 'rm -f "$RCON_PY"' EXIT
cat >"$RCON_PY" <<'PYEOF'
import socket, struct, sys

SERVERDATA_AUTH, SERVERDATA_EXECCOMMAND = 3, 2

def encode(rid, typ, body):
    payload = struct.pack('<ii', rid, typ) + body.encode('utf-8') + b'\x00\x00'
    return struct.pack('<i', len(payload)) + payload

def recvall(sock, n):
    buf = b''
    while len(buf) < n:
        chunk = sock.recv(n - len(buf))
        if not chunk:
            return None
        buf += chunk
    return buf

def decode(sock):
    head = recvall(sock, 4)
    if not head:
        return None
    (length,) = struct.unpack('<i', head)
    data = recvall(sock, length)
    if data is None:
        return None
    rid, typ = struct.unpack('<ii', data[:8])
    return rid, typ, data[8:-2].decode('utf-8', 'replace')

def main():
    host, port, password, command = sys.argv[1], int(sys.argv[2]), sys.argv[3], sys.argv[4]
    try:
        sock = socket.create_connection((host, port), timeout=10)
    except OSError as e:
        print("connect failed: %s" % e, file=sys.stderr)
        return 3
    sock.settimeout(10)
    with sock:
        sock.sendall(encode(1, SERVERDATA_AUTH, password))
        reply = decode(sock)
        if reply and reply[1] == 0:
            reply = decode(sock)
        if not reply or reply[0] == -1:
            print("auth failed", file=sys.stderr)
            return 2
        sock.sendall(encode(2, SERVERDATA_EXECCOMMAND, command))
        out = []
        while True:
            try:
                pkt = decode(sock)
            except socket.timeout:
                break
            if pkt is None:
                break
            out.append(pkt[2])
            if len(pkt[2]) < 3700:
                break
        print(''.join(out).strip())
    return 0

sys.exit(main())
PYEOF
rcon() { python3 "$RCON_PY" "$RCON_HOST" "$RCON_PORT" "$(cat "$RCON_PASS_FILE")" "$1"; }

# When does this storm end? STORM_END_TIME wins if set, otherwise STORM_HOURS
# from now. Returns a unix timestamp. This one value drives both the MOTD line
# and the scheduled revert, so they can never disagree.
#
# STORM_END_TIME is an hour of the day, 1-24, on a 24h clock:
#   4  -> 04:00      16 -> 16:00      24 -> midnight
# If that hour has already gone by today, it rolls to tomorrow.
# "HH:MM" is still accepted if you ever need a non-round time.
end_epoch() {
  local t spec="${STORM_END_TIME:-}"
  if [ -n "$spec" ]; then
    if [[ "$spec" =~ ^[0-9]+$ ]]; then
      if [ "$spec" -lt 1 ] || [ "$spec" -gt 24 ]; then
        die "STORM_END_TIME must be an hour from 1 to 24 (got: $spec)"
      fi
      [ "$spec" -eq 24 ] && spec=0
      spec="$(printf '%02d:00' "$spec")"
    elif ! [[ "$spec" =~ ^[0-9]{1,2}:[0-9]{2}$ ]]; then
      die "STORM_END_TIME must be an hour from 1 to 24, or HH:MM (got: $spec)"
    fi
    t="$(date -d "today ${spec}" +%s)"
    [ "$t" -le "$(date +%s)" ] && t="$(date -d "tomorrow ${spec}" +%s)"
    echo "$t"
  else
    if ! [[ "${STORM_HOURS:-}" =~ ^[0-9]+$ ]] || [ "${STORM_HOURS}" -lt 1 ]; then
      die "this storm sets neither STORM_END_TIME nor a numeric STORM_HOURS - it has no end time"
    fi
    date -d "+${STORM_HOURS} hours" +%s
  fi
}

cancel_timer() {
  systemctl stop "${END_UNIT}.timer" >/dev/null 2>&1 || true
  systemctl reset-failed "${END_UNIT}.service" >/dev/null 2>&1 || true
  if command -v atq >/dev/null 2>&1 && [ -f /var/run/pz-storm.atjob ]; then
    atrm "$(cat /var/run/pz-storm.atjob)" >/dev/null 2>&1 || true
    rm -f /var/run/pz-storm.atjob
  fi
  if command -v crontab >/dev/null 2>&1; then
    crontab -l 2>/dev/null | grep -v " # ${END_UNIT}\$" | crontab - 2>/dev/null || true
  fi
}

# Record when this storm ends. Deliberately a FILE, not a timer: systemd-run
# transient units live in RAM and are destroyed by a container reboot, which is
# how Miracle Day ran five hours past its end on Sept 8. storms.sh ticks every
# five minutes and is what actually fires the revert, so an end time written
# here survives reboots, crashes and Docker restarts alike.
record_end() {
  local when="$1" self="$2"
  cancel_timer                      # clear any legacy timer from an older run
  printf '%s %s\n' "$(basename "$self")" "$when" > "$ACTIVE_FILE"
  log "End recorded for $(date -d "@${when}" '+%F %H:%M') (storms.sh will revert)"
}

usage() {
  cat <<USAGE
usage: $(basename "$0") [--end] [--dry]

  (no flags)   start the storm, and schedule its own end automatically
  --end        end it now: restore baseline settings and the plain MOTD
  --dry        build everything, show the diff, change nothing
  --no-timer   start it, but do NOT record an end time (you'll end it yourself)
USAGE
  exit 0
}

run_storm() {
  local mode="start" dry=0 timer=1
  local self; self="$(readlink -f "$0")"
  while [ $# -gt 0 ]; do
    case "$1" in
      --end)  mode="end" ;;
      --dry)  dry=1 ;;
      --no-timer) timer=0 ;;
      -h|--help) usage ;;
      *) die "unknown flag: $1" ;;
    esac
    shift
  done

  local overrides motd ini_over
  if [ "$mode" = "end" ]; then
    overrides=""
    ini_over="${INI_END:-}"
    motd="$BASE_MOTD"
  else
    overrides="$OVERRIDES"
    ini_over="${INI_START:-}"
    local until_str
    ENDS_AT="$(end_epoch)"
    until_str="$(date -d "@${ENDS_AT}" '+%A %-I:%M %p')"
    motd="${BASE_MOTD} <LINE> <LINE> <RGB:1,0.6,0>NOW ON: ${STORM_NAME} <LINE> ${STORM_BLURB} <LINE> <RGB:0.7,0.7,0.7>Back to normal ${until_str}."
  fi

  for f in "$INI_FILE" "$SANDBOX_FILE" "$BASELINE_FILE"; do
    [ -f "$f" ] || die "missing $f"
  done

  local staged_lua staged_ini
  staged_lua="$(mktemp)"; staged_ini="$(mktemp)"
  trap 'rm -f "$staged_lua" "$staged_ini"' RETURN

  # One pass: patch the sandbox baseline, and rewrite ServerWelcomeMessage.
  # Tracks table nesting, so top-level Farming and MultiplierConfig.Farming stay
  # distinct, and skips comment lines whose scale legends ("-- 1 = Insane") look
  # exactly like assignments. Aborts on a key it can't find, so a typo fails
  # loudly instead of silently doing nothing.
  OVERRIDES="$overrides" MOTD="$motd" INI_OVERRIDES="$ini_over" python3 - \
    "$BASELINE_FILE" "$staged_lua" "$INI_FILE" "$staged_ini" <<'PY'
import os, re, sys
base, out_lua, ini, out_ini = sys.argv[1:5]

want = {}
for line in os.environ["OVERRIDES"].splitlines():
    line = line.split('#')[0].strip()          # trailing "# was 3" notes
    if not line:
        continue
    k, v = line.split('=', 1)
    want[k.strip()] = v.strip().rstrip(',').strip()

OPEN   = re.compile(r'^\s*([A-Za-z_]\w*)\s*=\s*\{\s*$')
CLOSE  = re.compile(r'^\s*\},?\s*$')
ASSIGN = re.compile(r'^(\s*)([A-Za-z_]\w*)\s*=\s*(.*?),?\s*$')

stack, hit, lines = [], set(), []
for raw in open(base, encoding='utf-8'):
    line = raw.rstrip('\n')
    if line.strip().startswith('--'):
        lines.append(line); continue
    m = OPEN.match(line)
    if m:
        stack.append(m.group(1)); lines.append(line); continue
    if CLOSE.match(line):
        if stack: stack.pop()
        lines.append(line); continue
    m = ASSIGN.match(line)
    if m and stack:
        path = '.'.join(stack[1:] + [m.group(2)])   # drop the SandboxVars root
        if path in want:
            lines.append(f"{m.group(1)}{m.group(2)} = {want[path]},")
            hit.add(path); continue
    lines.append(line)

missing = sorted(set(want) - hit)
if missing:
    sys.exit("keys not found in baseline: " + ", ".join(missing))

open(out_lua, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')

# --- ini: the MOTD, plus any INI_OVERRIDES this storm declares ---
ini_want = {}
for line in os.environ.get("INI_OVERRIDES", "").splitlines():
    line = line.split('#')[0].strip()
    if not line:
        continue
    k, v = line.split('=', 1)
    ini_want[k.strip()] = v.strip()

motd, found, ini_hit = os.environ["MOTD"], False, set()
with open(ini, encoding='utf-8') as fh, open(out_ini, 'w', encoding='utf-8') as w:
    for line in fh:
        if line.startswith('ServerWelcomeMessage='):
            w.write(f"ServerWelcomeMessage={motd}\n"); found = True
            continue
        key = line.split('=', 1)[0] if '=' in line and not line.startswith('#') else None
        if key in ini_want:
            w.write(f"{key}={ini_want[key]}\n"); ini_hit.add(key)
        else:
            w.write(line)
    if not found:
        w.write(f"ServerWelcomeMessage={motd}\n")

ini_missing = sorted(set(ini_want) - ini_hit)
if ini_missing:
    sys.exit("ini keys not found: " + ", ".join(ini_missing))

extra = f", {len(ini_hit)} ini key(s)" if ini_hit else ""
print(f"{len(hit)} sandbox override(s) applied, MOTD rewritten{extra}")
PY

  if [ "$dry" = 1 ]; then
    log "DRY RUN (${mode}) — sandbox diff:"
    diff -u "$SANDBOX_FILE" "$staged_lua" || true
    log "DRY RUN — MOTD would be:"
    grep '^ServerWelcomeMessage=' "$staged_ini"
    return 0
  fi

  # One restart at a time across all this server's automation.
  exec 9>"$LOCK_FILE"
  flock -w 1800 9 || die "another job holds $LOCK_FILE"

  if running; then
    if [ "$WARN_MINUTES" -gt 0 ]; then
      if [ "$mode" = "end" ]; then
        rcon "servermsg \"${STORM_NAME} ends in ${WARN_MINUTES} minutes. Server will restart.\"" >/dev/null || true
      else
        rcon "servermsg \"Server restarting in ${WARN_MINUTES} minutes: ${STORM_NAME} is starting.\"" >/dev/null || true
      fi
      log "Warned players, waiting ${WARN_MINUTES}m"
      sleep $(( WARN_MINUTES * 60 ))
    fi
    log "Saving and shutting down"
    rcon "save" >/dev/null || log "WARN: save failed"
    sleep 15
    rcon "quit" >/dev/null 2>&1 || true
    sleep 10
    # Container has restart: unless-stopped, so "quit" alone gets auto-revived
    # by docker almost immediately with the old config still in place. An
    # explicit stop is what actually disables that policy and gives us a
    # clean window to swap files - polling for "already stopped" first would
    # rarely ever observe it, since docker's revival beats our poll interval.
    log "Stopping container"
    docker stop -t 120 "$CONTAINER" >/dev/null
  fi

  cp -a "$SANDBOX_FILE" "${SANDBOX_FILE}.prev"
  cp -a "$INI_FILE"     "${INI_FILE}.prev"
  install -m 644 "$staged_lua" "$SANDBOX_FILE"
  install -m 644 "$staged_ini" "$INI_FILE"

  if [ "$mode" = "end" ]; then
    cancel_timer
    rm -f "$ACTIVE_FILE"
    date +%s > "$LAST_END_FILE"
    log "Ended: ${STORM_NAME} — baseline restored"
  else
    log "Started: ${STORM_NAME}"
    if [ "$timer" = 1 ]; then
      record_end "$ENDS_AT" "$self"
    else
      log "--no-timer: you must run '$self --end' yourself"
    fi
  fi

  docker start "$CONTAINER" >/dev/null
  log "Server starting."
}
