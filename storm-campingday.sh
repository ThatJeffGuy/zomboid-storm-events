#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/pz-storm-lib.sh"

STORM_NAME="Gone Camping"
: "${STORM_HOURS:=}"
: "${STORM_END_TIME:=22}"
STORM_BLURB="<RGB:0.4,1,0.4>Time to touch grass..<LINE><RGB:0.8,1,0.8>Foraging, Trapping, Fishing, and Cooking gain 4x XP.<LINE><RGB:1,0.9,0.5>Zombies have also gone camping, so they will be seen farther out today and in large groups more often. Good Luck!"

OVERRIDES="
  MultiplierConfig.GlobalToggle = false
  PlantAbundance = 5
  NatureAbundance = 5
  MultiplierConfig.PlantScavenging = 4.0
  MultiplierConfig.Trapping = 4.0
  MultiplierConfig.Fishing = 4.0
  MultiplierConfig.Cooking = 4.0
  ZombieConfig.RallyTravelDistance = 50
  ZombieConfig.RallyGroupSize = 25
"

run_storm "$@"
