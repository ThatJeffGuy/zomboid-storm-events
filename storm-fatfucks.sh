#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/pz-storm-lib.sh"

STORM_NAME="Why are you so fat?"
: "${STORM_HOURS:=}"
: "${STORM_END_TIME:=22}"
STORM_BLURB="<RGB:1,0.9,0.5>God damn it you look greasy.<LINE><RGB:0.4,1,0.4>Thankfully, the plants around you love it and are growing at 4x today. Food in your fridge tastes extra fresh and seemingly never expires.<LINE><RGB:1,0.3,0.3>You are always starving though, like the fatty you are. So are they, and they do not forget that you have chips in your pockets. Good luck!"

OVERRIDES="
  MultiplierConfig.GlobalToggle = false
  Farming = 1
  PlantAbundance = 5
  PlantResilience = 1
  NatureAbundance = 5
  FoodRotSpeed = 5
  FridgeFactor = 6
  FoodLootNew = 1.6
  CookwareLootNew = 1.4
  StatsDecrease = 1
  MultiplierConfig.Cooking = 2.0
  MultiplierConfig.Farming = 2.0
  ZombieLore.SprinterPercentage = 15
  ZombieLore.Hearing = 1
  ZombieLore.Memory = 1
  ZombieConfig.FollowSoundDistance = 200
"

run_storm "$@"
