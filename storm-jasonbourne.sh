#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/pz-storm-lib.sh"

STORM_NAME="Jesus Christ.. That's Jason Bourne.."
: "${STORM_HOURS:=}"
: "${STORM_END_TIME:=22}"
STORM_BLURB="<RGB:0.7,0.7,0.9>Jesus Christ.. That's Jason Bourne..<LINE><RGB:0.4,1,0.4>Like all the agents Jason took out, Zombies are dumb but they have ears everywhere! Hearing is set to maximum! Crouching makes you invisible. Gunpowder and firearms loot are doubled, with Aiming, Reloading, and Nimble XP all boosted.<LINE>"

OVERRIDES="
  MultiplierConfig.GlobalToggle = false
  ZombieLore.Sight = 1
  ZombieLore.Hearing = 1
  ZombieLore.Memory = 1
  RangedWeaponLootNew = 2.0
  AmmoLootNew = 2.0
  MultiplierConfig.Aiming = 4.0
  MultiplierConfig.Reloading = 4.0
  MultiplierConfig.Nimble = 4.0
"

run_storm "$@"
