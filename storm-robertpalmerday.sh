#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/pz-storm-lib.sh"

STORM_NAME="Robert Palmer Day"
: "${STORM_HOURS:=}"
: "${STORM_END_TIME:=22}"
STORM_BLURB="<RGB:0.2,1,0.6>Everyone seemingly has a bad case of Loving You.<LINE><RGB:1,0.4,0.4>Everything aches all over. Hunger, Thirst and Durability drain at 4x.<LINE><RGB:0.4,1,0.4>Clinics, closets and bookshelves are overflowing with medical supplies. Doctor and Tailoring gain 4x XP.<LINE><RGB:1,1,0.4>Watch that propofol dosage, and good luck!"

OVERRIDES="
  MultiplierConfig.GlobalToggle = false
  MultiplierConfig.Doctor = 4.0
  MultiplierConfig.Tailoring = 4.0
  StatsDecrease = 1
  InjurySeverity = 3
  BoneFracture = true
  BloodLevel = 4
  ClothingDegradation = 2
  Rain = 5
  Temperature = 2
  MaxRainFxIntensity = 1
  MaxFogIntensity = 1
  MedicalLootNew = 2.5
  ClothingLootNew = 2.0
  LiteratureLootNew = 1.5
  SkillBookLoot = 2.0
"

run_storm "$@"
