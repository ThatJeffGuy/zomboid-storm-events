#!/usr/bin/env bash
source "$(dirname "${BASH_SOURCE[0]}")/pz-storm-lib.sh"

STORM_NAME="The Long Night"
: "${STORM_HOURS:=}"
: "${STORM_END_TIME:=22}"
STORM_BLURB="<RGB:0.6,0.6,1>The sun did not come up today.<LINE><RGB:0.4,1,0.4>The dead cannot see or hear well, and alarms and helicopters stay quiet.<LINE><RGB:1,0.9,0.5>Sneaking, Lightfooted and Nimble all train at 4x for the whole storm.<LINE><RGB:1,0.5,0.5>Sleep is disabled until the sun returns. It seems Zombies prefer the night anyway.. Good luck."

OVERRIDES="
  MultiplierConfig.GlobalToggle = false
  NightLength = 1
  NightDarkness = 2
  ZombieLore.Sight = 3
  ZombieLore.Hearing = 3
  Alarm = 2
  Helicopter = 1
  LightBulbLifespan = 8.0
  BFFloorLights.radiusMult = 0.6
  HandCrankFlashlights.LightDistance = 25
  HandCrankFlashlights.ConditionLoseRate = 10
  ZombieLore.Sight = 2
  ZombieLore.Hearing = 2
  ZombieLore.SprinterPercentage = 3
  MultiplierConfig.Sneak = 4.0
  MultiplierConfig.Lightfoot = 4.0
  MultiplierConfig.Nimble = 4.0
"

INI_START="SleepAllowed=false"
INI_END="SleepAllowed=true"

run_storm "$@"
