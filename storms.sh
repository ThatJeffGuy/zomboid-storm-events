#!/usr/bin/env bash
# ==============================================================================
# Script Name: storms.sh
# Description: Scheduler for the storm-*.sh event scripts. Runs every 5 minutes
#              from cron, all day. A storm starts every STORM_INTERVAL_DAYS
#              days (2 = every other day), rotating through all storm-*.sh
#              scripts in random order with the vacation day always closing
#              out each rotation cycle, then reshuffling for the next one --
#              then, critically, ends it when the recorded end time passes.
#
#              The end lives in a file (.active_storm), not a systemd timer.
#              Transient timers are held in RAM and die with the container; on
#              Sept 8 a reboot at 12:00 destroyed one and Miracle Day ran until
#              it was stopped by hand. A file plus a tick survives reboots.
#
#              Whichever day the interval happens to land on, that day's
#              window still applies:
#                Saturday   10:00-16:00
#                Sunday     12:00-18:00
#                Mon-Fri    16:00-22:00
#              (all Eastern wall-clock -- see the TZ export below)
#
# Options:
#   --dry       Show what would happen. Changes nothing.
#   --status    Print current state (active storm, cadence, queue) and exit.
#   --end       End the running storm now.
#   --force <storm-x.sh>   Start a specific storm immediately, ignoring the
#                          interval/window gate. Does not consume a queue
#                          slot and does not count as this cycle's start for
#                          interval purposes.
#   --allow-tonight        Waive the interval gate for today, so the regular
#                          window tick can fire even if it's too soon since
#                          the last storm. Does NOT start anything itself and
#                          does not touch the time-of-day gate -- the queued
#                          storm still only starts once the clock reaches
#                          today's window-open hour. A no-op if today is
#                          already interval-eligible.
#   --resetqueue           Reshuffle which storm runs next.
# ==============================================================================

set -euo pipefail

# This host's clock is assumed Etc/UTC (cron runs as root on the host, not
# inside the game container) -- but the windows above are meant as Eastern wall-clock
# time, matching zomboid-server's own TZ=America/Toronto and what players
# actually experience. Exporting TZ here makes every `date` call in this
# script (and in pz-storm-lib.sh, which inherits it) resolve against Eastern
# time instead, DST included, without touching cron itself.
export TZ=America/Toronto

STORMS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

STORM_INTERVAL_DAYS=2    # minimum days between storm starts (2 = every other day)
START_GRACE_MIN=25       # how late a missed window-open tick may still start
LEAD_MIN=5                # fire --end this early, so the lib's 5m player
                          # warning lands the restart on the hour
VACATION_STORM="storm-vacationday.sh"

QUEUE_FILE="${QUEUE_FILE:-$STORMS_DIR/.storm_queue}"
ACTIVE_FILE="${ACTIVE_FILE:-$STORMS_DIR/.active_storm}"
LAST_END_FILE="${LAST_END_FILE:-$STORMS_DIR/.last_storm_end}"
LAST_START_DATE_FILE="${LAST_START_DATE_FILE:-$STORMS_DIR/.last_storm_start_date}"
LOCK_FILE="${LOCK_FILE:-/var/lock/pz-storm-tick.lock}"

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*"; }

DRY=0; ACTION="tick"; FORCE_STORM=""
while [ $# -gt 0 ]; do
  case "$1" in
    --dry)        DRY=1 ;;
    --status)     ACTION="status" ;;
    --end)        ACTION="end" ;;
    --resetqueue) ACTION="resetqueue" ;;
    --force)      ACTION="force"; FORCE_STORM="${2:-}"; shift
                  [ -n "$FORCE_STORM" ] || { echo "--force needs a storm script name" >&2; exit 64; } ;;
    --allow-tonight) ACTION="allow_tonight" ;;
    *) echo "unknown flag: $1" >&2; exit 64 ;;
  esac
  shift
done

# Never let two ticks overlap. An --end takes ~5.5 minutes (player warning plus
# restart), which is longer than the cron interval, so this matters.
exec 9>"$LOCK_FILE"
flock -n 9 || exit 0

NOW="$(date +%s)"
TODAY="$(date +%F)"        # YYYY-MM-DD, dedupes "already started today"
TODAY_ABBR="$(date +%a)"   # Mon, Tue, ... Sun

read_active() {
  ACTIVE_SCRIPT=""; ACTIVE_END=0
  [ -f "$ACTIVE_FILE" ] || return 0
  read -r ACTIVE_SCRIPT ACTIVE_END < "$ACTIVE_FILE" || true
  [[ "$ACTIVE_END" =~ ^[0-9]+$ ]] || ACTIVE_END=0
}

last_end() { [ -f "$LAST_END_FILE" ] && cat "$LAST_END_FILE" || echo 0; }

# Window for a given day abbreviation (Mon/Tue/.../Sun): "<start_hour> <end_hour>"
window_for_day() {
  case "$1" in
    Sat) echo "10 16" ;;
    Sun) echo "12 18" ;;
    *)   echo "16 22" ;;
  esac
}

build_queue() {
  local pool=() f base
  for f in "$STORMS_DIR"/storm-*.sh; do
    base="$(basename "$f")"
    [ "$base" = "$VACATION_STORM" ] && continue
    pool+=("$base")
  done
  [ "${#pool[@]}" -gt 0 ] || { log "ERROR: no storm scripts found in $STORMS_DIR"; exit 1; }
  # Competitive storms in random order, then the vacation day last.
  { printf '%s\n' "${pool[@]}" | shuf; echo "$VACATION_STORM"; } | tr '\n' ' ' | sed 's/ $//' > "$QUEUE_FILE"
  log "New rotation cycle: $(cat "$QUEUE_FILE")"
}

# Days since the last recorded storm start, or unbounded (no gate) if none is
# on record yet. Comparing calendar dates (not "now minus start epoch") means
# a storm that started at 21:00 still counts today as day zero, matching how
# an operator would count "every other day" by eye.
days_since_last_start() {
  local last_date last_epoch today_epoch
  [ -f "$LAST_START_DATE_FILE" ] || { echo 999999; return 0; }
  last_date="$(cat "$LAST_START_DATE_FILE")"
  last_epoch="$(date -d "$last_date" +%s)" || { echo 999999; return 0; }
  today_epoch="$(date -d "$TODAY" +%s)"
  echo $(( (today_epoch - last_epoch) / 86400 ))
}

interval_satisfied() {
  [ "$(days_since_last_start)" -ge "$STORM_INTERVAL_DAYS" ]
}

start_storm() {
  local next="$1" env_args=() start_hour end_hour
  [ -x "$STORMS_DIR/$next" ] || { log "ERROR: $next missing or not executable"; return 1; }
  # Competitive storms are forced into today's window (see window_for_day).
  # The vacation day keeps its own short STORM_HOURS - it's a breather, not
  # a full slot, so it doesn't inherit the window's end hour.
  if [ "$next" != "$VACATION_STORM" ]; then
    read -r start_hour end_hour < <(window_for_day "$TODAY_ABBR")
    env_args=(STORM_END_TIME="$end_hour")
  fi

  if [ "$DRY" = 1 ]; then
    log "DRY RUN — would start $next"
    env "${env_args[@]}" "$STORMS_DIR/$next" --dry
    return 0
  fi

  log "Starting $next"
  # The lib records its own end time in .active_storm, so the end time in the
  # MOTD and the end time we act on are the same number by construction.
  env "${env_args[@]}" "$STORMS_DIR/$next"
}

end_storm() {
  local script="$1"
  if [ "$DRY" = 1 ]; then log "DRY RUN — would run $script --end"; return 0; fi
  log "Ending $script"
  if ! "$STORMS_DIR/$script" --end; then
    log "ERROR: $script --end failed. STORM SETTINGS ARE STILL LIVE."
    log "       Retrying on the next tick. Fix by hand: $STORMS_DIR/$script --end"
    return 1
  fi
}

read_active

case "$ACTION" in
  status)
    if [ -n "$ACTIVE_SCRIPT" ]; then
      echo "ACTIVE : $ACTIVE_SCRIPT until $(date -d "@$ACTIVE_END" '+%F %H:%M')"
    else
      echo "ACTIVE : nothing running"
      le="$(last_end)"
      [ "$le" -gt 0 ] && echo "LAST   : ended $(date -d "@$le" '+%F %H:%M')"
    fi
    if [ -f "$LAST_START_DATE_FILE" ]; then
      last_date="$(cat "$LAST_START_DATE_FILE")"
      since="$(days_since_last_start)"
      echo "CADENCE: every $STORM_INTERVAL_DAYS day(s) -- last started $last_date ($since day(s) ago)"
      if interval_satisfied; then
        echo "         eligible today, waiting for the window to open"
      else
        echo "         next eligible $(date -d "$last_date +$STORM_INTERVAL_DAYS days" '+%F')"
      fi
    else
      echo "CADENCE: every $STORM_INTERVAL_DAYS day(s) -- no prior start on record, eligible today"
    fi
    echo "QUEUE  : $( [ -f "$QUEUE_FILE" ] && cat "$QUEUE_FILE" || echo '(will be built on first start)' )"
    exit 0 ;;

  end)
    [ -n "$ACTIVE_SCRIPT" ] || { log "Nothing running."; exit 0; }
    end_storm "$ACTIVE_SCRIPT"; exit $? ;;

  resetqueue)
    build_queue; exit 0 ;;

  force)
    [ -z "$ACTIVE_SCRIPT" ] || { log "ERROR: $ACTIVE_SCRIPT is already running. End it first."; exit 1; }
    start_storm "$FORCE_STORM"; exit $? ;;

  allow_tonight)
    [ -z "$ACTIVE_SCRIPT" ] || { log "ERROR: $ACTIVE_SCRIPT is already running -- can't waive the interval while something's active."; exit 1; }
    if interval_satisfied; then
      log "Already interval-eligible today -- nothing to waive."
      exit 0
    fi
    rm -f "$LAST_START_DATE_FILE"
    log "Cleared the last-start record so today's window tick can fire despite the ${STORM_INTERVAL_DAYS}-day interval."
    exit 0 ;;
esac

# ---------------------------------------------------------------- the tick ---

# A storm is running: end it when due, otherwise leave it alone.
if [ -n "$ACTIVE_SCRIPT" ]; then
  if [ "$NOW" -ge $(( ACTIVE_END - LEAD_MIN * 60 )) ]; then
    end_storm "$ACTIVE_SCRIPT"
  fi
  exit 0
fi

# Idle. Only start once the interval since the last storm has elapsed --
# this alone also covers "already started today" (day zero never satisfies a
# >=1 day interval), so there's no separate same-day dedupe check needed.
if ! interval_satisfied; then
  exit 0
fi

# Only start in the window that today's day-of-week opens.
read -r START_HOUR END_HOUR < <(window_for_day "$TODAY_ABBR")
HOUR="$(date +%-H)"; MIN="$(date +%-M)"
if [ "$DRY" = 0 ] && { [ "$HOUR" -ne "$START_HOUR" ] || [ "$MIN" -ge "$START_GRACE_MIN" ]; }; then
  exit 0
fi

[ -s "$QUEUE_FILE" ] || build_queue
read -r -a QUEUE <<< "$(cat "$QUEUE_FILE")"
[ "${#QUEUE[@]}" -gt 0 ] || { build_queue; read -r -a QUEUE <<< "$(cat "$QUEUE_FILE")"; }

NEXT="${QUEUE[0]}"

if [ "$DRY" = 1 ]; then
  log "DRY RUN — next up is $NEXT (queue not consumed)"
  start_storm "$NEXT"
  exit 0
fi

if start_storm "$NEXT"; then
  printf '%s' "${QUEUE[*]:1}" > "$QUEUE_FILE"     # consume only on success
  printf '%s' "$TODAY" > "$LAST_START_DATE_FILE"
else
  log "ERROR: $NEXT failed to start — leaving it at the head of the queue"
  exit 1
fi
