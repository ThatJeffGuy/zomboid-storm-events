#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/pz-storm-lib.sh"

STORM_NAME="Race Wars - not that kind.."
: "${STORM_HOURS:=}"
: "${STORM_END_TIME:=22}"
STORM_BLURB="<RGB:1,0.1,0.1>It's not always about family, Dom..<LINE><RGB:0.4,1,0.4>Every engine in town burns through a full tank in seconds, so nobody's actually going anywhere today.<LINE><RGB:0.8,1,0.8>Might as well pop the hood: Mechanics skill trains at 4x XP, and car parts and repair scrap turn up everywhere. Watch out for other fast racers, they're extra popular today.."

OVERRIDES="
  MultiplierConfig.GlobalToggle = false
  CarGasConsumption = 100
  MechanicsLootNew = 2.5
  RecipeResourceLoot = 1.6
  MultiplierConfig.Mechanics = 4.0
  ZombieLore.DoorOpeningPercentage = 100
  ZombieLore.SprinterPercentage = 10
"

run_storm "$@"
