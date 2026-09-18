#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/pz-storm-lib.sh"

STORM_NAME="28 Seconds Later"
: "${STORM_HOURS:=}"
: "${STORM_END_TIME:=22}"
STORM_BLURB="<RGB:1,0.2,0.2>Rule 2: Cardio.<LINE><RGB:0.4,1,0.4>Fitness, Sprinting, and melee combat skills gain 4x XP, but the Varsity Track and Field team from Zarvard are here practising."

OVERRIDES="
  MultiplierConfig.GlobalToggle = false
  ZombieLore.Speed = 1
  ZombieLore.Sight = 3
  ZombieLore.Memory = 3
  ZombieLore.Hearing = 3
  AmmoLootNew = 2.0
  MedicalLootNew = 2.0
  MultiplierConfig.Fitness = 4.0
  MultiplierConfig.Sprinting = 4.0
  MultiplierConfig.Axe = 4.0
  MultiplierConfig.Blunt = 4.0
  MultiplierConfig.SmallBlunt = 4.0
  MultiplierConfig.Spear = 4.0
  ZombieLore.SprinterPercentage = 50
"

run_storm "$@"
