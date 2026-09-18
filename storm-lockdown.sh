#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/pz-storm-lib.sh"

STORM_NAME="Lockdown Protocol"
: "${STORM_HOURS:=}"
: "${STORM_END_TIME:=22}"
STORM_BLURB="<RGB:1,0.8,0.2>JARVIS activate lockdown protocol alpha.<LINE><RGB:1,0.3,0.3>Yes sir. Locking every door window and engaging all alarms. Be aware that activating lockdown protocol will put those outside at high alert.<LINE><RGB:0.4,1,0.4>High-tier loot inside buildings surges, and Sneak, Lightfoot, and Nimble train at 4x XP."

OVERRIDES="
  MultiplierConfig.GlobalToggle = false
  LockedHouses = 6
  Alarm = 6
  ZombieConfig.FollowSoundDistance = 250
  RangedWeaponLootNew = 1.8
  AmmoLootNew = 1.8
  MedicalLootNew = 1.8
  MultiplierConfig.Sneak = 4.0
  MultiplierConfig.Lightfoot = 4.0
  MultiplierConfig.Nimble = 4.0
"

run_storm "$@"
