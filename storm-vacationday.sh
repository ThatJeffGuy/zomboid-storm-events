#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/pz-storm-lib.sh"

STORM_NAME="A Day Off In The Sun"
: "${STORM_HOURS:=1}"
: "${STORM_END_TIME:=}"
STORM_BLURB="<RGB:0.4,1,0.4>Time to kick back and relax..<LINE><RGB:0.8,1,0.8>Zombies are as fragile, blind, and sluggish as they get, with zero sprinters on the map. Hunger, thirst, and fatigue drain at a crawl, and food in the fridge never rots.<LINE><RGB:0.4,0.8,1>Loot respawns are fast and at 10x rates, along with all skills and books. Take a breath and catch up - fast!"

OVERRIDES="
  MultiplierConfig.GlobalToggle = false
  StatsDecrease = 5
  FoodRotSpeed = 5
  FridgeFactor = 6
  NatureAbundance = 5
  PlantAbundance = 5
  ZombieLore.Toughness = 3
  ZombieLore.Sight = 3
  ZombieLore.Hearing = 3
  ZombieLore.SprinterPercentage = 0
  FoodLootNew = 4.0
  MedicalLootNew = 4.0
  WeaponLootNew = 4.0
  RangedWeaponLootNew = 4.0
  AmmoLootNew = 4.0
  CookwareLootNew = 4.0
  SkillBookLoot = 4.0
  LiteratureLootNew = 4.0
  RecipeResourceLoot = 4.0
  MultiplierConfig.Fitness = 10.0
  MultiplierConfig.Strength = 10.0
  MultiplierConfig.Maintenance = 10.0
"

run_storm "$@"
