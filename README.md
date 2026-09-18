# zomboid-storm-events

Bash scripts that temporarily change your Project Zomboid world settings
for special scripted events -- loot/XP multipliers, zombie behavior
changes, and the like -- then automatically revert everything afterward.

**Live example:** see active/upcoming events at https://zomboid.wubcord.app

- Can be scheduled or randomized via a crontab entry.
- Add, remove, or edit event scripts freely -- they're read fresh before
  every launch, nothing needs to be registered elsewhere.
- Automatically reverts settings after the event ends (standard 0-24h time).
- Rewrites the server MOTD to announce the event, and exposes flags a
  companion website can read to show what's active/next to players (see
  [zomboid-status-page](https://github.com/ThatJeffGuy/zomboid-status-page)).

> **Note:** this is the current version of what used to ship inside
> [zomboid-scripts](https://github.com/ThatJeffGuy/zomboid-scripts) as
> `event-*.sh`/`pz-event-lib.sh` -- renamed to `storm-*.sh`/
> `pz-storm-lib.sh` and split out to its own repo.

## How it works

- `storms.sh` is the scheduler. Run it every 5 minutes from cron. Each ISO
  week it randomly picks a few days to run a storm on; when that day's time
  window opens, it starts the next queued storm, and ends it when the
  recorded end time passes. State (active storm, this week's picked days,
  the rotation queue) lives in plain files in this directory, not a systemd
  timer -- timers live in RAM and don't survive a container/host reboot.
- `pz-storm-lib.sh` is the shared engine every `storm-*.sh` sources. It
  patches a pristine baseline `SandboxVars.lua` with each storm's overrides,
  rewrites the server's MOTD to announce the storm, warns and restarts the
  server, and reverts everything back to baseline when the storm ends.
- Each `storm-*.sh` is one event: a name, an in-game MOTD blurb, and a block
  of sandbox variable overrides. Ten examples are included (loot/zombie
  behavior remixes) -- add your own the same way.

```
storms.sh --dry             # show what would happen, change nothing
storms.sh --status          # print active storm, this week's days, queue
storms.sh --end             # end the running storm now
storms.sh --force <storm-x.sh>   # start a specific storm immediately
storms.sh --allow-tonight   # add today to this week's storm days
storms.sh --resetqueue      # reshuffle which storm runs next
storms.sh --resetdays       # re-roll this week's storm days
```

## Setup

1. Edit `pz-storm-lib.sh`'s config block: `CONFIG_DIR`/`SERVER_CONFIG_NAME`
   (must match your actual `.ini`/`_SandboxVars.lua` filenames), `CONTAINER`,
   RCON connection, and `BASE_MOTD`.
2. Create a `baseline_SandboxVars.lua` in `CONFIG_DIR` -- a copy of your
   server's normal (non-event) sandbox settings. This is what every storm
   patches from and every "end" reverts back to.
3. Drop this directory somewhere your Zomboid server's config lives (the
   scripts default to `/opt/app/zomboid/config/storms`, override paths as
   needed) and add `storms.sh` to root's crontab, every 5 minutes:
   `*/5 * * * * /path/to/storms.sh`.
4. Write your own `storm-*.sh` files following the existing examples --
   `STORM_NAME`, `STORM_BLURB` (uses PZ's `<RGB:r,g,b>`/`<LINE>` MOTD
   markup), and an `OVERRIDES` block of `SandboxVar = value` lines (must
   match keys that exist in your baseline file).

## Requirements

- `bash`, `python3` (embedded RCON client), `docker` CLI.
- A `baseline_SandboxVars.lua` matching your server's real sandbox schema.

## Related

- [zomboid-scripts](https://github.com/ThatJeffGuy/zomboid-scripts) --
  `caretaking.sh` shares a restart lock file with this repo's `storms.sh`
  (see the `LOCK`/`LOCK_FILE` variables in each) so the two never restart
  the server at the same time. Keep those two paths matching if you run
  both.
- [zomboid-status-page](https://github.com/ThatJeffGuy/zomboid-status-page) --
  a web status/admin page that can optionally display the active/next storm
  by reading this repo's state files.

## License

CC0 1.0 Universal -- see [LICENSE](LICENSE). Public domain, no attribution
required, though a link back is always appreciated.
