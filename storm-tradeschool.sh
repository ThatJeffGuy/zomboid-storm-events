#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/pz-storm-lib.sh"

STORM_NAME="The First Day of School"
: "${STORM_HOURS:=}"
: "${STORM_END_TIME:=22}"
STORM_BLURB="<RGB:1,0.9,0.5>I hope you didn't brain your damage.<LINE><RGB:0.8,1,0.8>Skill books and reading material are far more common while it lasts. Zeds are still looking to take your lunch money, and they can all open doors and windows now. Sprinters? You're lucky they're at an away game today.."

OVERRIDES="
  MultiplierConfig.GlobalToggle = false
  MultiplierConfig.Woodwork = 3.0
  MultiplierConfig.MetalWelding = 3.0
  MultiplierConfig.Blacksmith = 3.0
  MultiplierConfig.Masonry = 3.0
  MultiplierConfig.Pottery = 3.0
  MultiplierConfig.Carving = 3.0
  MultiplierConfig.Glassmaking = 3.0
  MultiplierConfig.Tailoring = 3.0
  MultiplierConfig.FlintKnapping = 3.0
  SkillBookLoot = 1.6
  LiteratureLootNew = 1.6
  RecipeResourceLoot = 1.4
  ZombieLore.DoorOpeningPercentage = 100
  ZombieLore.SprinterPercentage = 0
"

run_storm "$@"
