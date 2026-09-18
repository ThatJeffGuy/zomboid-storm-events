#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/pz-storm-lib.sh"

STORM_NAME="Blood and Thunder"
: "${STORM_HOURS:=}"
: "${STORM_END_TIME:=22}"
STORM_BLURB="<RGB:1,0.4,0.2>FOR THE HORDE!!<LINE><RGB:0.4,1,0.4>Melee weapon loot is increased and because of it, zombies are more fragile. All melee combat skills + Maintenance gain 4x XP.<LINE><RGB:1,0.3,0.3>Firearms and ammunition have stopped spawning entirely. Get up close and personal."

OVERRIDES="
  MultiplierConfig.GlobalToggle = false
  RangedWeaponLootNew = 0
  AmmoLootNew = 0
  WeaponLootNew = 2.5
  ZombieLore.Toughness = 3
  MultiplierConfig.Axe = 4.0
  MultiplierConfig.Blunt = 4.0
  MultiplierConfig.SmallBlunt = 4.0
  MultiplierConfig.LongBlade = 4.0
  MultiplierConfig.SmallBlade = 4.0
  MultiplierConfig.Spear = 4.0
  MultiplierConfig.Maintenance = 4.0
"

run_storm "$@"
