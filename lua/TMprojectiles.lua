#****************************************************************************
#**
#**  File     : /cdimage/lua/modules/BlackOpsARprojectiles.lua
#**  Author(s): 
#**
#**  Summary  :
#**
#**  Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
#****************************************************************************
#------------------------------------------------------------------------
#					
#------------------------------------------------------------------------
local Projectile = import('/lua/sim/projectile.lua').Projectile
local DefaultProjectileFile = import('/lua/sim/defaultprojectiles.lua')
local EmitterProjectile = DefaultProjectileFile.EmitterProjectile
local OnWaterEntryEmitterProjectile = DefaultProjectileFile.OnWaterEntryEmitterProjectile
local SingleBeamProjectile = DefaultProjectileFile.SingleBeamProjectile
local SinglePolyTrailProjectile = DefaultProjectileFile.SinglePolyTrailProjectile
local MultiPolyTrailProjectile = DefaultProjectileFile.MultiPolyTrailProjectile
local SingleCompositeEmitterProjectile = DefaultProjectileFile.SingleCompositeEmitterProjectile
local Explosion = import('/lua/defaultexplosions.lua')
local NullShell = DefaultProjectileFile.NullShell
local EffectTemplate = import('/lua/EffectTemplates.lua')
local DefaultExplosion = import('/lua/defaultexplosions.lua')
local DepthCharge = import('/lua/defaultantiprojectile.lua').DepthCharge
local util = import('/lua/utilities.lua')
local EffectTemplate = import('/lua/EffectTemplates.lua')

local TMEffectTemplate = import('/mods/BlackOpsFAF-ACUs-YYPatch/lua/TMEffectTemplates.lua')
local DepthCharge = import('/lua/defaultantiprojectile.lua').DepthCharge
local util = import('/lua/utilities.lua')

#----------------
# Null Shell
#----------------
EXNullShell = Class(Projectile) {}

#----------------
# UEF Tech 3 Rocket Defense
#----------------
UefBRNT3PDROproj = Class(SingleBeamProjectile) {
    FxTrails = {'/effects/emitters/missile_munition_trail_01_emit.bp',},
    FxTrailOffset = -1,
    BeamName = '/effects/emitters/missile_munition_exhaust_beam_01_emit.bp',
    FxImpactUnit = TMEffectTemplate.UEFHEAVYROCKET02,
    FxUnitHitScale = 2.2,
    FxImpactProp = TMEffectTemplate.UEFHEAVYROCKET02,
    FxPropHitScale = 2.2,
    FxImpactLand = TMEffectTemplate.UEFHEAVYROCKET02,
    FxLandHitScale = 2.2,
    FxImpactUnderWater = TMEffectTemplate.UEFHEAVYROCKET02,
    FxImpactWater = TMEffectTemplate.UEFHEAVYROCKET02,
    FxWaterHitScale = 2.2,
}

