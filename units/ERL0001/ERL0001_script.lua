-----------------------------------------------------------------
-- Author(s):  Exavier Macbeth
-- Summary  :  BlackOps: Adv Command Unit - Cybran ACU
-- Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
-----------------------------------------------------------------

local ACUUnit = import('/lua/defaultunits.lua').ACUUnit
local CWeapons = import('/lua/cybranweapons.lua')
local CCannonMolecularWeapon = CWeapons.CCannonMolecularWeapon
local CDFHeavyMicrowaveLaserGeneratorCom = CWeapons.CDFHeavyMicrowaveLaserGeneratorCom
local CDFOverchargeWeapon = CWeapons.CDFOverchargeWeapon
local CANTorpedoLauncherWeapon = CWeapons.CANTorpedoLauncherWeapon
local RocketPack = CWeapons.CDFRocketIridiumWeapon02
local EffectUtil = import('/lua/EffectUtilities.lua')
local Entity = import('/lua/sim/Entity.lua').Entity
local Buff = import('/lua/sim/Buff.lua')
local DeathNukeWeapon = import('/lua/sim/defaultweapons.lua').DeathNukeWeapon
local BOWeapons = import('/mods/BlackOpsFAF-ACUs-YYPatch/lua/ACUsWeapons.lua')
local EMPWeapon = BOWeapons.EMPWeapon
local CEMPArrayBeam01 = BOWeapons.CEMPArrayBeam01
local CEMPArrayBeam02 = BOWeapons.CEMPArrayBeam02

local WeaponsFile = import('/lua/terranweapons.lua')
local TDFGaussCannonWeapon = WeaponsFile.TDFLandGaussCannonWeapon

ERL0001 = Class(ACUUnit) {
    DeathThreadDestructionWaitTime = 2,
    PainterRange = {},

    Weapons = {
        DeathWeapon = Class(DeathNukeWeapon) {},
        RightRipper = Class(CCannonMolecularWeapon) {},
        TargetPainter = Class(CEMPArrayBeam01) {},
        RocketPack = Class(RocketPack) {},
        TorpedoLauncher = Class(CANTorpedoLauncherWeapon) {},
        EMPShot01 = Class(EMPWeapon) {},
        EMPShot02 = Class(EMPWeapon) {},
        EMPShot03 = Class(EMPWeapon) {},
        MLG01 = Class(CDFHeavyMicrowaveLaserGeneratorCom) {},
        MLG02 = Class(CDFHeavyMicrowaveLaserGeneratorCom) {},
        MLG03 = Class(CDFHeavyMicrowaveLaserGeneratorCom) {},
        AA01 = Class(CEMPArrayBeam02) {},
        AA02 = Class(CEMPArrayBeam02) {},
        AA03 = Class(CEMPArrayBeam02) {},
        AA04 = Class(CEMPArrayBeam02) {},
		MLRS1 = Class(TDFGaussCannonWeapon) {},
		MLRS2 = Class(TDFGaussCannonWeapon) {},
		MLRS3 = Class(TDFGaussCannonWeapon) {},
        OverCharge = Class(CDFOverchargeWeapon) {},
        AutoOverCharge = Class(CDFOverchargeWeapon) {},
    },
    
    __init = function(self)
        ACUUnit.__init(self, 'RightRipper')
    end,

    -- Storage for upgrade weapons status
    WeaponEnabled = {},

    OnCreate = function(self)
        ACUUnit.OnCreate(self)
        self:SetCapturable(false)
        self:SetupBuildBones()

        local bp = self:GetBlueprint()
        for _, v in bp.Display.WarpInEffect.HideBones do
            self:HideBone(v, true)
        end

        -- Restrict what enhancements will enable later
        self:AddBuildRestriction(categories.CYBRAN * (categories.BUILTBYTIER2COMMANDER + categories.BUILTBYTIER3COMMANDER + categories.BUILTBYTIER4COMMANDER))
    end,

    OnStopBeingBuilt = function(self, builder, layer)
        ACUUnit.OnStopBeingBuilt(self, builder, layer)
        self:SetWeaponEnabledByLabel('RightRipper', true)
        self:SetMaintenanceConsumptionInactive()
        self:DisableUnitIntel('Enhancement', 'RadarStealth')
        self:DisableUnitIntel('Enhancement', 'SonarStealth')
        self:DisableUnitIntel('Enhancement', 'Cloak')
        self:DisableUnitIntel('Enhancement', 'Sonar')
        self.EMPArrayEffects01 = {}
        self:ForkThread(self.GiveInitialResources)
        
        -- Disable Upgrade Weapons
        self:SetWeaponEnabledByLabel('RocketPack', false)
        self:SetWeaponEnabledByLabel('TorpedoLauncher', false)
        self:SetWeaponEnabledByLabel('EMPShot01', false)
        self:SetWeaponEnabledByLabel('EMPShot02', false)
        self:SetWeaponEnabledByLabel('EMPShot03', false)
        self:SetWeaponEnabledByLabel('MLG01', false)
        self:SetWeaponEnabledByLabel('MLG02', false)
        self:SetWeaponEnabledByLabel('MLG03', false)
        self:SetWeaponEnabledByLabel('AA01', false)
        self:SetWeaponEnabledByLabel('AA02', false)
        self:SetWeaponEnabledByLabel('AA03', false)
        self:SetWeaponEnabledByLabel('AA04', false)
		self:SetWeaponEnabledByLabel('MLRS1', false)
		self:SetWeaponEnabledByLabel('MLRS2', false)
		self:SetWeaponEnabledByLabel('MLRS3', false)
		
		self.RegenFieldFXBag = {}
    end,

    OnStartBuild = function(self, unitBeingBuilt, order)    
        ACUUnit.OnStartBuild(self, unitBeingBuilt, order)
        self.UnitBuildOrder = order
    end,

    GetUnitsToBuff = function(self, bp) --Для бафф командира
        local unitCat = ParseEntityCategory(bp.UnitCategory or 'BUILTBYTIER3FACTORY + BUILTBYQUANTUMGATE + NEEDMOBILEBUILD')
        local brain = self:GetAIBrain()
        local all = brain:GetUnitsAroundPoint(unitCat, self:GetPosition(), bp.Radius, 'Ally')
        local units = {}

        for _, u in all do
            if not u.Dead and not u:IsBeingBuilt() then
                table.insert(units, u)
            end
        end

        return units
    end,

    RegenBuffThread = function(self, enh)
        local bp = self:GetBlueprint().Enhancements[enh]
        local buff

        if enh == 'BuffEngineering' then
            buff = 'CybranSpeedAura'
		elseif enh == 'SupportEngineering' then
			buff = 'CybranSpeedAura2'
		elseif enh == 'AuxillaryEngineering' then
			buff = 'CybranSpeedAura3'
		elseif enh == 'AssistingEngineering' then
			buff = 'CybranSpeedAura4'
		end
   --     elseif enh == 'AssaultEngineering' then
     --       buff = 'SeraphimACUAdvancedRegenAura'
       -- end

        while not self.Dead do
            local units = self:GetUnitsToBuff(bp)
            for _,unit in units do
                Buff.ApplyBuff(unit, buff)
                unit:RequestRefreshUI()
            end
            WaitSeconds(5)
        end
    end,
	
    NavalRegenBuffThread = function(self, enh)
        local bp = self:GetBlueprint().Enhancements[enh]
        local buff

        if enh == 'ShipNanobots' then
            buff = 'ShipNanobotsACUCybranAura'
        end

        while not self.Dead do
            local units = self:GetUnitsToBuff(bp)
            for _,unit in units do
                Buff.ApplyBuff(unit, buff)
                unit:RequestRefreshUI()
            end
            WaitSeconds(5)
        end
    end,
	
    AirRegenBuffThread = function(self, enh)
        local bp = self:GetBlueprint().Enhancements[enh]
        local buff

        if enh == 'AircraftRepairField' then
            buff = 'AirNanobotsACUCybranAura'
        end

        while not self.Dead do
            local units = self:GetUnitsToBuff(bp)
            for _,unit in units do
                Buff.ApplyBuff(unit, buff)
                unit:RequestRefreshUI()
            end
            WaitSeconds(5)
        end
    end,

    -- New function to set up production numbers
    SetProduction = function(self, bp)
        local energy = bp.ProductionPerSecondEnergy or 0
        local mass = bp.ProductionPerSecondMass or 0
        
        local bpEcon = self:GetBlueprint().Economy
        
        self:SetProductionPerSecondEnergy(energy + bpEcon.ProductionPerSecondEnergy or 0)
        self:SetProductionPerSecondMass(mass + bpEcon.ProductionPerSecondMass or 0)
    end,
    
    -- Function to toggle the Ripper
    TogglePrimaryGun = function(self, RoF, radius)
        local wep = self:GetWeaponByLabel('RightRipper')
        local oc = self:GetWeaponByLabel('OverCharge')
        local aoc = self:GetWeaponByLabel('AutoOverCharge')
    
        local wepRadius = radius or wep:GetBlueprint().MaxRadius
        local ocRadius = radius or oc:GetBlueprint().MaxRadius
        local aocRadius = radius or aoc:GetBlueprint().MaxRadius

        -- Change RoF
        wep:ChangeRateOfFire(RoF)
        
        -- Change Radius
        wep:ChangeMaxRadius(wepRadius)
        oc:ChangeMaxRadius(ocRadius)
        aoc:ChangeMaxRadius(aocRadius)
        
        -- As radius is only passed when turning on, use the bool
        if radius then
            self:ShowBone('Right_Upgrade', true)
            self:SetPainterRange('JuryRiggedRipper', radius, false)
        else
            self:HideBone('Right_Upgrade', true)
            self:SetPainterRange('JuryRiggedRipperRemove', radius, true)
        end
    end,

    -- Target painter. 0 damage as primary weapon, controls targeting
    -- for the variety of changing ranges on the ACU with upgrades.
    SetPainterRange = function(self, enh, newRange, delete)
        if delete and self.PainterRange[string.sub(enh, 0, -7)] then
            self.PainterRange[string.sub(enh, 0, -7)] = nil
        elseif not delete and not self.PainterRange[enh] then
            self.PainterRange[enh] = newRange
        end 
        
        local range = 22
        for upgrade, radius in self.PainterRange do
            if radius > range then range = radius end
        end
        
        local wep = self:GetWeaponByLabel('TargetPainter')
        wep:ChangeMaxRadius(range)
    end,

    OnTransportDetach = function(self, attachBone, unit)
        ACUUnit.OnTransportDetach(self, attachBone, unit)
        self:StopSiloBuild()
    end,

    OnScriptBitClear = function(self, bit)
        if bit == 8 then -- Cloak toggle
            self:PlayUnitAmbientSound('ActiveLoop')
            self:SetMaintenanceConsumptionActive()
            self:EnableUnitIntel('ToggleBit8', 'Cloak')
            self:EnableUnitIntel('ToggleBit8', 'RadarStealth')
            self:EnableUnitIntel('ToggleBit8', 'SonarStealth')

            if self.MaintenanceConsumption then
                self.ToggledOff = false
            end
        else
            ACUUnit.OnScriptBitClear(self, bit)
        end
    end,

    OnScriptBitSet = function(self, bit)
        if bit == 8 then -- Cloak toggle
            self:StopUnitAmbientSound('ActiveLoop')
            self:SetMaintenanceConsumptionInactive()
            self:DisableUnitIntel('ToggleBit8', 'Cloak')
            self:DisableUnitIntel('ToggleBit8', 'RadarStealth')
            self:DisableUnitIntel('ToggleBit8', 'SonarStealth')

            if not self.MaintenanceConsumption then
                self.ToggledOff = true
            end
        else
            ACUUnit.OnScriptBitSet(self, bit)
        end
    end,

    CreateBuildEffects = function(self, unitBeingBuilt, order)
       EffectUtil.SpawnBuildBots(self, unitBeingBuilt, 5, self.BuildEffectsBag)
       EffectUtil.CreateCybranBuildBeams(self, unitBeingBuilt, self:GetBlueprint().General.BuildBones.BuildEffectBones, self.BuildEffectsBag)
    end,

    CreateEnhancement = function(self, enh, removal)
        ACUUnit.CreateEnhancement(self, enh)

        local bp = self:GetBlueprint().Enhancements[enh]
        if not bp then return end

        if enh == 'ImprovedEngineering' then
            self:RemoveBuildRestriction(categories.CYBRAN * categories.BUILTBYTIER2COMMANDER)
            self:updateBuildRestrictions()
            self:SetProduction(bp)
            
            if not Buffs['CYBRANACUT2BuildRate'] then
                BuffBlueprint {
                    Name = 'CYBRANACUT2BuildRate',
                    DisplayName = 'CYBRANACUT2BuildRate',
                    BuffType = 'ACUBUILDRATE',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        BuildRate = {
                            Add =  bp.NewBuildRate,
                            Mult = 1,
                        },
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                        Regen = {
                            Add = bp.NewRegenRate,
                            Mult = 1.0,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'CYBRANACUT2BuildRate')
        elseif enh == 'ImprovedEngineeringRemove' then
            if Buff.HasBuff(self, 'CYBRANACUT2BuildRate') then
                Buff.RemoveBuff(self, 'CYBRANACUT2BuildRate')
            end
            self:AddBuildRestriction(categories.CYBRAN * (categories.BUILTBYTIER2COMMANDER + categories.BUILTBYTIER3COMMANDER + categories.BUILTBYTIER4COMMANDER))
            self:SetProduction()
        elseif enh == 'AdvancedEngineering' then
            self:RemoveBuildRestriction(categories.CYBRAN * (categories.BUILTBYTIER3COMMANDER - categories.BUILTBYTIER4COMMANDER))
            self:updateBuildRestrictions()
            self:SetProduction(bp)
            
            if not Buffs['CYBRANACUT3BuildRate'] then
                BuffBlueprint {
                    Name = 'CYBRANACUT3BuildRate',
                    DisplayName = 'CYBRANCUT3BuildRate',
                    BuffType = 'ACUBUILDRATE',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        BuildRate = {
                            Add =  bp.NewBuildRate,
                            Mult = 1,
                        },
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                        Regen = {
                            Add = bp.NewRegenRate,
                            Mult = 1.0,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'CYBRANACUT3BuildRate')
        elseif enh == 'AdvancedEngineeringRemove' then
            if Buff.HasBuff(self, 'CYBRANACUT3BuildRate') then
                Buff.RemoveBuff(self, 'CYBRANACUT3BuildRate')
            end
            self:AddBuildRestriction(categories.CYBRAN * (categories.BUILTBYTIER2COMMANDER + categories.BUILTBYTIER3COMMANDER + categories.BUILTBYTIER4COMMANDER))
            self:SetProduction()
        elseif enh == 'ExperimentalEngineering' then
            self:RemoveBuildRestriction(categories.CYBRAN * (categories.BUILTBYTIER4COMMANDER))
            self:updateBuildRestrictions()
            self:SetProduction(bp)

            if not Buffs['CYBRANACUT4BuildRate'] then
                BuffBlueprint {
                    Name = 'CYBRANACUT4BuildRate',
                    DisplayName = 'CYBRANCUT4BuildRate',
                    BuffType = 'ACUBUILDRATE',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        BuildRate = {
                            Add =  bp.NewBuildRate,
                            Mult = 1,
                        },
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                        Regen = {
                            Add = bp.NewRegenRate,
                            Mult = 1.0,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'CYBRANACUT4BuildRate')
        elseif enh == 'ExperimentalEngineeringRemove' then
            if Buff.HasBuff(self, 'CYBRANACUT4BuildRate') then
                Buff.RemoveBuff(self, 'CYBRANACUT4BuildRate')
            end
            self:AddBuildRestriction(categories.CYBRAN * (categories.BUILTBYTIER2COMMANDER + categories.BUILTBYTIER3COMMANDER + categories.BUILTBYTIER4COMMANDER))
            self:SetProduction()
        elseif enh == 'ParagonEngineering' then
            self:SetProduction(bp)
            if not Buffs['UEFACUT5BuildRate'] then
                BuffBlueprint {
                    Name = 'UEFACUT5BuildRate',
                    DisplayName = 'UEFCUT5BuildRate',
                    BuffType = 'ACUBUILDRATE',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        BuildRate = {
                            Add =  bp.NewBuildRate,
                            Mult = 1,
                        },
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                        Regen = {
                            Add = bp.NewRegenRate,
                            Mult = 1.0,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'UEFACUT5BuildRate')
        elseif enh == 'ParagonEngineeringRemove' then
            if Buff.HasBuff(self, 'UEFACUT5BuildRate') then
                Buff.RemoveBuff(self, 'UEFACUT5BuildRate')
            end
            self:AddBuildRestriction(categories.UEF * (categories.BUILTBYTIER2COMMANDER + categories.BUILTBYTIER3COMMANDER + categories.BUILTBYTIER4COMMANDER))
            self:SetProduction()
        elseif enh == 'CombatEngineering' then
            self:RemoveBuildRestriction(categories.CYBRAN * (categories.BUILTBYTIER2COMMANDER))
            self:updateBuildRestrictions()
            
            if not Buffs['CYBRANACUT2BuildCombat'] then
                BuffBlueprint {
                    Name = 'CYBRANACUT2BuildCombat',
                    DisplayName = 'CYBRANACUT2BuildCombat',
                    BuffType = 'ACUBUILDRATE',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        BuildRate = {
                            Add =  bp.NewBuildRate,
                            Mult = 1,
                        },
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                        Regen = {
                            Add = bp.NewRegenRate,
                            Mult = 1.0,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'CYBRANACUT2BuildCombat')
            
            self:SetWeaponEnabledByLabel('RocketPack', true)
        elseif enh == 'CombatEngineeringRemove' then
            if Buff.HasBuff(self, 'CYBRANACUT2BuildCombat') then
                Buff.RemoveBuff(self, 'CYBRANACUT2BuildCombat')
            end

            self:AddBuildRestriction(categories.CYBRAN * (categories.BUILTBYTIER2COMMANDER + categories.BUILTBYTIER3COMMANDER + categories.BUILTBYTIER4COMMANDER))
			
            self:SetWeaponEnabledByLabel('RocketPack', false)
        elseif enh == 'AssaultEngineering' then
            self:RemoveBuildRestriction(categories.CYBRAN * (categories.BUILTBYTIER3COMMANDER - categories.BUILTBYTIER4COMMANDER))
            self:updateBuildRestrictions()
            
            if not Buffs['CYBRANACUT3BuildCombat'] then
                BuffBlueprint {
                    Name = 'CYBRANACUT3BuildCombat',
                    DisplayName = 'CYBRANCUT3BuildRate',
                    BuffType = 'ACUBUILDRATE',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        BuildRate = {
                            Add =  bp.NewBuildRate,
                            Mult = 1,
                        },
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                        Regen = {
                            Add = bp.NewRegenRate,
                            Mult = 1.0,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'CYBRANACUT3BuildCombat')
            
            local gun = self:GetWeaponByLabel('RocketPack')
            gun:AddDamageMod(bp.RocketDamageMod)
            gun:ChangeMaxRadius(bp.RocketMaxRadius)
            
            self:SetPainterRange(enh, bp.RocketMaxRadius, true)
        elseif enh == 'AssaultEngineeringRemove' then
            if Buff.HasBuff(self, 'CYBRANACUT3BuildCombat') then
                Buff.RemoveBuff(self, 'CYBRANACUT3BuildCombat')
            end
            
            self:AddBuildRestriction(categories.CYBRAN * (categories.BUILTBYTIER2COMMANDER + categories.BUILTBYTIER3COMMANDER + categories.BUILTBYTIER4COMMANDER))

            local gun = self:GetWeaponByLabel('RocketPack')
            gun:AddDamageMod(bp.RocketDamageMod)
            gun:ChangeMaxRadius(gun:GetBlueprint().MaxRadius)
            
            self:SetPainterRange(enh, 0, true)
        elseif enh == 'ApocalypticEngineering' then
            self:RemoveBuildRestriction(categories.CYBRAN * (categories.BUILTBYTIER4COMMANDER))
            self:updateBuildRestrictions()
            
            if not Buffs['CYBRANACUT4BuildCombat'] then
                BuffBlueprint {
                    Name = 'CYBRANACUT4BuildCombat',
                    DisplayName = 'CYBRANCUT4BuildRate',
                    BuffType = 'ACUBUILDRATE',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        BuildRate = {
                            Add =  bp.NewBuildRate,
                            Mult = 1,
                        },
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                        Regen = {
                            Add = bp.NewRegenRate,
                            Mult = 1.0,
                        },
                    },
                }
            end
            local gun = self:GetWeaponByLabel('RocketPack')
            gun:AddDamageMod(bp.RocketDamageMod)
            gun:ChangeMaxRadius(bp.RocketMaxRadius)
            
            self:SetPainterRange(enh, 0, true)			
            Buff.ApplyBuff(self, 'CYBRANACUT4BuildCombat')
        elseif enh == 'ApocalypticEngineeringRemove' then
            if Buff.HasBuff(self, 'CYBRANACUT4BuildCombat') then
                Buff.RemoveBuff(self, 'CYBRANACUT4BuildCombat')
            end  
            self:AddBuildRestriction(categories.CYBRAN * (categories.BUILTBYTIER2COMMANDER + categories.BUILTBYTIER3COMMANDER + categories.BUILTBYTIER4COMMANDER))
        elseif enh == 'ExterminatorEngineering' then
          
            if not Buffs['CYBRANACUT5BuildCombat'] then
                BuffBlueprint {
                    Name = 'CYBRANACUT5BuildCombat',
                    DisplayName = 'CYBRANCUT5BuildRate',
                    BuffType = 'ACUBUILDRATE',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        BuildRate = {
                            Add =  bp.NewBuildRate,
                            Mult = 1,
                        },
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                        Regen = {
                            Add = bp.NewRegenRate,
                            Mult = 1.0,
                        },
                    },
                }
            end
            local gun = self:GetWeaponByLabel('RocketPack')
            gun:AddDamageMod(bp.RocketDamageMod)
            gun:ChangeMaxRadius(bp.RocketMaxRadius)
			gun:ChangeRateOfFire(bp.RocketFireRate)
            
            self:SetPainterRange(enh, 0, true)			
            Buff.ApplyBuff(self, 'CYBRANACUT5BuildCombat')
        elseif enh == 'ExterminatorEngineeringRemove' then
            if Buff.HasBuff(self, 'CYBRANACUT5BuildCombat') then
                Buff.RemoveBuff(self, 'CYBRANACUT5BuildCombat')
            end
            self:AddBuildRestriction(categories.CYBRAN * (categories.BUILTBYTIER2COMMANDER + categories.BUILTBYTIER3COMMANDER + categories.BUILTBYTIER4COMMANDER))
		elseif enh == 'BuffEngineering' then
		    self:RemoveBuildRestriction(categories.CYBRAN * (categories.BUILTBYTIER2COMMANDER))
            self:updateBuildRestrictions()
			
            if not Buffs['CybranSpeedAura'] then
                BuffBlueprint {
                    Name = 'CybranSpeedAura',
                    DisplayName = 'CybranSpeedAura',
                    BuffType = 'COMMANDERAURA_RegenAura',
                    Stacks = 'STACKS',
                    Duration = 5,
                    Affects = {
                        MoveMult = {
                            Add = 0,
                            Mult = bp.SpeedMod,
                        },
						RateOfFire = {
							Add = 0,
							Mult = 1 / bp.FireRateMod,
						},
                    },
                }
            end	
			if self.RegenFieldFXBag then
                for k, v in self.RegenFieldFXBag do
                    v:Destroy()
                end
                self.RegenFieldFXBag = {}
            end

            if self.RegenThreadHandler then
                KillThread(self.RegenThreadHandler)
                self.RegenThreadHandler = nil
            end
            self.RegenThreadHandler = self:ForkThread(self.RegenBuffThread, enh)
			            table.insert(self.RegenFieldFXBag, CreateAttachedEmitter(self, 'Torso', self:GetArmy(), '/effects/emitters/seraphim_regenerative_aura_01_emit.bp'))
		elseif enh == 'BuffEngineeringRemove' then
		    if self.RegenThreadHandler then
                KillThread(self.RegenThreadHandler)
                self.RegenThreadHandler = nil
            end

            if self.RegenFieldFXBag then
                for k, v in self.RegenFieldFXBag do
                    v:Destroy()
                end
                self.RegenFieldFXBag = {}
            end
            self:AddBuildRestriction(categories.CYBRAN * (categories.BUILTBYTIER2COMMANDER + categories.BUILTBYTIER3COMMANDER + categories.BUILTBYTIER4COMMANDER))

		elseif enh == 'SupportEngineering' then
            self:RemoveBuildRestriction(categories.CYBRAN * (categories.BUILTBYTIER3COMMANDER - categories.BUILTBYTIER4COMMANDER))
            self:updateBuildRestrictions()
			
            if not Buffs['CybranSpeedAura2'] then
                BuffBlueprint {
                    Name = 'CybranSpeedAura2',
                    DisplayName = 'CybranSpeedAura2',
                    BuffType = 'COMMANDERAURA_RegenAura',
                    Stacks = 'STACKS',
                    Duration = 5,
                    Affects = {
                        MoveMult = {
                            Add = 0,
                            Mult = bp.SpeedMod,
                        },
						RateOfFire = {
							Add = 0,
							Mult = 1 / bp.FireRateMod,
						},
                    },
                }
            end	
			if self.RegenFieldFXBag then
                for k, v in self.RegenFieldFXBag do
                    v:Destroy()
                end
                self.RegenFieldFXBag = {}
            end

            if self.RegenThreadHandler then
                KillThread(self.RegenThreadHandler)
                self.RegenThreadHandler = nil
            end
            self.RegenThreadHandler = self:ForkThread(self.RegenBuffThread, enh)
			            table.insert(self.RegenFieldFXBag, CreateAttachedEmitter(self, 'Torso', self:GetArmy(), '/effects/emitters/seraphim_regenerative_aura_01_emit.bp'))
		elseif enh == 'SupportEngineeringRemove' then
		    if self.RegenThreadHandler then
                KillThread(self.RegenThreadHandler)
                self.RegenThreadHandler = nil
            end

            if self.RegenFieldFXBag then
                for k, v in self.RegenFieldFXBag do
                    v:Destroy()
                end
                self.RegenFieldFXBag = {}
            end
            self:AddBuildRestriction(categories.CYBRAN * (categories.BUILTBYTIER2COMMANDER + categories.BUILTBYTIER3COMMANDER + categories.BUILTBYTIER4COMMANDER))
			
		elseif enh == 'AuxillaryEngineering' then
            self:RemoveBuildRestriction(categories.CYBRAN * (categories.BUILTBYTIER3COMMANDER - categories.BUILTBYTIER4COMMANDER))
            self:updateBuildRestrictions()
			
            if not Buffs['CybranSpeedAura3'] then
                BuffBlueprint {
                    Name = 'CybranSpeedAura3',
                    DisplayName = 'CybranSpeedAura3',
                    BuffType = 'COMMANDERAURA_RegenAura',
                    Stacks = 'STACKS',
                    Duration = 5,
                    Affects = {
                        MoveMult = {
                            Add = 0,
                            Mult = bp.SpeedMod,
                        },
						RateOfFire = {
							Add = 0,
							Mult = 1 / bp.FireRateMod,
						},
                    },
                }
            end	
			if self.RegenFieldFXBag then
                for k, v in self.RegenFieldFXBag do
                    v:Destroy()
                end
                self.RegenFieldFXBag = {}
            end

            if self.RegenThreadHandler then
                KillThread(self.RegenThreadHandler)
                self.RegenThreadHandler = nil
            end
            self.RegenThreadHandler = self:ForkThread(self.RegenBuffThread, enh)
			            table.insert(self.RegenFieldFXBag, CreateAttachedEmitter(self, 'Torso', self:GetArmy(), '/effects/emitters/seraphim_regenerative_aura_01_emit.bp'))
		elseif enh == 'AuxillaryEngineeringRemove' then
		    if self.RegenThreadHandler then
                KillThread(self.RegenThreadHandler)
                self.RegenThreadHandler = nil
            end

            if self.RegenFieldFXBag then
                for k, v in self.RegenFieldFXBag do
                    v:Destroy()
                end
                self.RegenFieldFXBag = {}
            end
            self:AddBuildRestriction(categories.CYBRAN * (categories.BUILTBYTIER2COMMANDER + categories.BUILTBYTIER3COMMANDER + categories.BUILTBYTIER4COMMANDER))
			
		elseif enh == 'AssistingEngineering' then
            self:RemoveBuildRestriction(categories.CYBRAN * (categories.BUILTBYTIER3COMMANDER - categories.BUILTBYTIER4COMMANDER))
            self:updateBuildRestrictions()
			
            if not Buffs['CybranSpeedAura4'] then
                BuffBlueprint {
                    Name = 'CybranSpeedAura4',
                    DisplayName = 'CybranSpeedAura4',
                    BuffType = 'COMMANDERAURA_RegenAura',
                    Stacks = 'STACKS',
                    Duration = 5,
                    Affects = {
                        MoveMult = {
                            Add = 0,
                            Mult = bp.SpeedMod,
                        },
						RateOfFire = {
							Add = 0,
							Mult = 1 / bp.FireRateMod,
						},
                    },
                }
            end	
			if self.RegenFieldFXBag then
                for k, v in self.RegenFieldFXBag do
                    v:Destroy()
                end
                self.RegenFieldFXBag = {}
            end

            if self.RegenThreadHandler then
                KillThread(self.RegenThreadHandler)
                self.RegenThreadHandler = nil
            end
            self.RegenThreadHandler = self:ForkThread(self.RegenBuffThread, enh)
			            table.insert(self.RegenFieldFXBag, CreateAttachedEmitter(self, 'Torso', self:GetArmy(), '/effects/emitters/seraphim_regenerative_aura_01_emit.bp'))
		elseif enh == 'AssistingEngineeringRemove' then
		    if self.RegenThreadHandler then
                KillThread(self.RegenThreadHandler)
                self.RegenThreadHandler = nil
            end

            if self.RegenFieldFXBag then
                for k, v in self.RegenFieldFXBag do
                    v:Destroy()
                end
                self.RegenFieldFXBag = {}
            end
            self:AddBuildRestriction(categories.CYBRAN * (categories.BUILTBYTIER2COMMANDER + categories.BUILTBYTIER3COMMANDER + categories.BUILTBYTIER4COMMANDER))
             

		-- MLRS
		elseif enh == 'AdvancedLongRangePods' then
		
			self:SetWeaponEnabledByLabel('MLRS1', true)
			local gun = self:GetWeaponByLabel('RightRipper')
			gun:ChangeMaxRadius(bp.NewRange)
			local mlrs = self:GetWeaponByLabel('MLRS1')
			mlrs:ChangeMaxRadius(bp.NewRange)
		     
			
            if not Buffs['CybranMLRSHealth1'] then
                BuffBlueprint {
                    Name = 'CybranMLRSHealth1',
                    DisplayName = 'CybranMLRSHealth1',
                    BuffType = 'CybranArmorHealth',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
						Regen = {
							Add = bp.NewRegenRate,
							Mult = 1.0,
						},
                    },
                }
            end
            Buff.ApplyBuff(self, 'CybranMLRSHealth1')
			self:SetPainterRange(enh, bp.NewRange, true)		
			
		elseif enh == 'AdvancedLongRangePodsRemove' then
			self:SetWeaponEnabledByLabel('MLRS1', false)
			
			if Buff.HasBuff(self, 'CybranMLRSHealth1') then
                Buff.RemoveBuff(self, 'CybranMLRSHealth1')
            end
			
		elseif enh == 'MaximizedWarhead' then
			self:SetWeaponEnabledByLabel('MLRS1', false)
			self:SetWeaponEnabledByLabel('MLRS2', true)
			local gun = self:GetWeaponByLabel('RightRipper')
			gun:ChangeMaxRadius(bp.NewRange)
			local mlrs = self:GetWeaponByLabel('MLRS2')
			mlrs:ChangeMaxRadius(bp.NewRange)
			self:SetPainterRange(enh, bp.NewRange, true)
			
			
            if not Buffs['CybranMLRSHealth2'] then
                BuffBlueprint {
                    Name = 'CybranMLRSHealth2',
                    DisplayName = 'CybranMLRSHealth2',
                    BuffType = 'CybranArmorHealth',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
						Regen = {
							Add = bp.NewRegenRate,
							Mult = 1.0,
						},
                    },
                }
            end
            Buff.ApplyBuff(self, 'CybranMLRSHealth2')
			
		elseif enh == 'MaximizedWarheadRemove' then
			self:SetWeaponEnabledByLabel('MLRS2', false)
			
			if Buff.HasBuff(self, 'CybranMLRSHealth2') then
                Buff.RemoveBuff(self, 'CybranMLRSHealth2')
            end
			
		elseif enh == 'ExperimentalReloadTech' then
			self:SetWeaponEnabledByLabel('MLRS2', false)
			self:SetWeaponEnabledByLabel('MLRS3', true)
			local gun = self:GetWeaponByLabel('RightRipper')
			gun:ChangeMaxRadius(bp.NewRange)
			local mlrs = self:GetWeaponByLabel('MLRS3')
			mlrs:ChangeMaxRadius(bp.NewRange)
			self:SetPainterRange(enh, bp.NewRange, true)

            if not Buffs['CybranMLRSHealth3'] then
                BuffBlueprint {
                    Name = 'CybranMLRSHealth3',
                    DisplayName = 'CybranMLRSHealth3',
                    BuffType = 'CybranArmorHealth',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
						Regen = {
							Add = bp.NewRegenRate,
							Mult = 1.0,
						},
                    },
                }
            end
            Buff.ApplyBuff(self, 'CybranMLRSHealth3')
			
		elseif enh == 'ExperimentalReloadTechRemove' then
			self:SetWeaponEnabledByLabel('MLRS3', false)
       
			if Buff.HasBuff(self, 'CybranMLRSHealth3') then
                Buff.RemoveBuff(self, 'CybranMLRSHealth3')
            end
        -- Torpedoes	   
        elseif enh == 'TorpedoLauncher' then
            if not Buffs['CybranTorpHealth1'] then
                BuffBlueprint {
                    Name = 'CybranTorpHealth1',
                    DisplayName = 'CybranTorpHealth1',
                    BuffType = 'CybranTorpHealth',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'CybranTorpHealth1')
			
            local wep2 = self:GetWeaponByLabel('RightRipper')
			wep2:ChangeMaxRadius(bp.MainGunMaxRadius)
			wep2:ChangeRateOfFire(bp.MainGunDamageMod)
			
            self:SetWeaponEnabledByLabel('TorpedoLauncher', true)
            self:EnableUnitIntel('Enhancement', 'Sonar')
        elseif enh == 'TorpedoLauncherRemove' then
            if Buff.HasBuff(self, 'CybranTorpHealth1') then
                Buff.RemoveBuff(self, 'CybranTorpHealth1')
            end
            
            self:SetWeaponEnabledByLabel('TorpedoLauncher', false)
            self:DisableUnitIntel('Enhancement', 'Sonar')
        elseif enh == 'ImprovedReloader' then
            if not Buffs['CybranTorpHealth2'] then
                BuffBlueprint {
                    Name = 'CybranTorpHealth2',
                    DisplayName = 'CybranTorpHealth2',
                    BuffType = 'CybranTorpHealth',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'CybranTorpHealth2')
            
            local torp = self:GetWeaponByLabel('TorpedoLauncher')
            torp:AddDamageMod(bp.TorpDamageMod)
            torp:ChangeRateOfFire(bp.NewTorpROF)
			
            local wep2 = self:GetWeaponByLabel('RightRipper')
			wep2:ChangeMaxRadius(bp.MainGunMaxRadius)
			wep2:ChangeRateOfFire(bp.MainGunDamageMod)			
			
            
        elseif enh == 'ImprovedReloaderRemove' then
            if Buff.HasBuff(self, 'CybranTorpHealth2') then
                Buff.RemoveBuff(self, 'CybranTorpHealth2')
            end
            
            local torp = self:GetWeaponByLabel('TorpedoLauncher')
            torp:AddDamageMod(bp.TorpDamageMod)
            torp:ChangeRateOfFire(torp:GetBlueprint().RateOfFire)

        elseif enh == 'AdvancedWarheads' then
            if not Buffs['CybranTorpHealth3'] then
                BuffBlueprint {
                    Name = 'CybranTorpHealth3',
                    DisplayName = 'CybranTorpHealth3',
                    BuffType = 'CybranTorpHealth',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'CybranTorpHealth3')
            
            local torp = self:GetWeaponByLabel('TorpedoLauncher')
            torp:AddDamageMod(bp.TorpDamageMod)
            
            local wep2 = self:GetWeaponByLabel('RightRipper')
			wep2:ChangeMaxRadius(bp.MainGunMaxRadius)
			wep2:ChangeRateOfFire(bp.MainGunDamageMod)
			
        elseif enh == 'AdvancedWarheadsRemove' then
            if Buff.HasBuff(self, 'CybranTorpHealth3') then
                Buff.RemoveBuff(self, 'CybranTorpHealth3')
            end

            local torp = self:GetWeaponByLabel('TorpedoLauncher')
            torp:AddDamageMod(bp.TorpDamageMod)

            local wep = self:GetWeaponByLabel('RightRipper')
            wep:AddDamageMod(bp.DamageMod)
			
        elseif enh == 'ShipNanobots' then
            if not Buffs['CybranTorpHealth4'] then
                BuffBlueprint {
                    Name = 'CybranTorpHealth4',
                    DisplayName = 'CybranTorpHealth4',
                    BuffType = 'CybranTorpHealth',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'CybranTorpHealth4')
			
            if not Buffs['ShipNanobotsACUCybranAura'] then
                BuffBlueprint {
                    Name = 'ShipNanobotsACUCybranAura',
                    DisplayName = 'ShipNanobotsACUCybranAura',
                    BuffType = 'COMMANDERAURA_NavalRegenAura',
                    Stacks = 'STACKS',
                    Duration = 5,
                    Affects = {
                        Regen = {
                            Add = bp.ShipAuraRegenAdditive,
                            Mult = 1.0,
                        }
                    },
                }
            end	
			if self.RegenFieldFXBag then
                for k, v in self.RegenFieldFXBag do
                    v:Destroy()
                end
                self.RegenFieldFXBag = {}
            end

            if self.RegenThreadHandler then
                KillThread(self.RegenThreadHandler)
                self.RegenThreadHandler = nil
            end
			
            self.RegenThreadHandler = self:ForkThread(self.NavalRegenBuffThread, enh)
			    table.insert(self.RegenFieldFXBag, CreateAttachedEmitter(self, 'Torso', self:GetArmy(), '/effects/emitters/seraphim_regenerative_aura_01_emit.bp'))
            
        elseif enh == 'ShipNanobotsRemove' then
            if Buff.HasBuff(self, 'CybranTorpHealth4') then
                Buff.RemoveBuff(self, 'CybranTorpHealth4')
            end

		    if self.RegenThreadHandler then
                KillThread(self.RegenThreadHandler)
                self.RegenThreadHandler = nil
            end

            if self.RegenFieldFXBag then
                for k, v in self.RegenFieldFXBag do
                    v:Destroy()
                end
                self.RegenFieldFXBag = {}
            end

            local torp = self:GetWeaponByLabel('TorpedoLauncher')
            torp:AddDamageMod(bp.TorpDamageMod)

            local wep = self:GetWeaponByLabel('RightRipper')
            wep:AddDamageMod(bp.DamageMod)
            
        -- EMP Array

        elseif enh == 'EMPArray' then
            if not Buffs['CybranEMPHealth1'] then
                BuffBlueprint {
                    Name = 'CybranEMPHealth1',
                    DisplayName = 'CybranEMPHealth1',
                    BuffType = 'CybranEMPHealth',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'CybranEMPHealth1')
            
            self:SetWeaponEnabledByLabel('EMPShot01', true)
            local wep = self:GetWeaponByLabel('EMPShot01')
            wep:ChangeMaxRadius(bp.MainGunRange)
			
            local wep2 = self:GetWeaponByLabel('RightRipper')
			wep2:ChangeMaxRadius(bp.MainGunRange)
			wep2:ChangeRateOfFire(bp.MainGunFireRate)
			wep2:AddDamageMod(bp.MainGunDamageMod)
			
            self:SetPainterRange(enh, bp.MainGunRange, false)
        elseif enh == 'EMPArrayRemove' then
            if Buff.HasBuff(self, 'CybranEMPHealth1') then
                Buff.RemoveBuff(self, 'CybranEMPHealth1')
            end

            self:SetWeaponEnabledByLabel('EMPShot01', false)
            local wep = self:GetWeaponByLabel('EMPShot01')
            wep:ChangeMaxRadius(wep:GetBlueprint().MaxRadius)
            
            self:SetPainterRange(enh, 0, true)
        elseif enh == 'AdjustedCrystalMatrix' then
            if not Buffs['CybranEMPHealth2'] then
                BuffBlueprint {
                    Name = 'CybranEMPHealth2',
                    DisplayName = 'CybranEMPHealth2',
                    BuffType = 'CybranEMPHealth',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'CybranEMPHealth2')

            self:SetWeaponEnabledByLabel('EMPShot01', false)
            self:SetWeaponEnabledByLabel('EMPShot02', true)
            
            local wep = self:GetWeaponByLabel('EMPShot02')
            wep:ChangeMaxRadius(bp.MainGunRange)
			
            local wep2 = self:GetWeaponByLabel('RightRipper')
			wep2:ChangeMaxRadius(bp.MainGunRange)
			wep2:ChangeRateOfFire(bp.MainGunFireRate)
			wep2:AddDamageMod(bp.MainGunDamageMod)
			
            self:SetPainterRange(enh, bp.MainGunRange, false)
			

        elseif enh == 'AdjustedCrystalMatrixRemove' then    
            if Buff.HasBuff(self, 'CybranEMPHealth2') then
                Buff.RemoveBuff(self, 'CybranEMPHealth2')
            end
            
            self:SetWeaponEnabledByLabel('EMPShot02', false)
            local wep = self:GetWeaponByLabel('EMPShot02')
            wep:ChangeMaxRadius(wep:GetBlueprint().MaxRadius)

            self:SetPainterRange(enh, 0, true)
            
            self:TogglePrimaryGun(bp.NewRoF)
        elseif enh == 'EnhancedLaserEmitters' then
            if not Buffs['CybranEMPHealth3'] then
                BuffBlueprint {
                    Name = 'CybranEMPHealth3',
                    DisplayName = 'CybranEMPHealth3',
                    BuffType = 'CybranEMPHealth',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'CybranEMPHealth3')
            
            self:SetWeaponEnabledByLabel('EMPShot02', false)
            self:SetWeaponEnabledByLabel('EMPShot03', true)
            
            local wep = self:GetWeaponByLabel('EMPShot03')
            wep:ChangeMaxRadius(bp.MainGunRange)
			
            local wep2 = self:GetWeaponByLabel('RightRipper')
			wep2:ChangeMaxRadius(bp.MainGunRange)
			wep2:ChangeRateOfFire(bp.MainGunFireRate)
			wep2:AddDamageMod(bp.MainGunDamageMod)
            
            self:SetPainterRange(enh, bp.MainGunRange, false)
        elseif enh == 'EnhancedLaserEmittersRemove' then    
            if Buff.HasBuff(self, 'CybranEMPHealth3') then
                Buff.RemoveBuff(self, 'CybranEMPHealth3')
            end
            
            self:SetWeaponEnabledByLabel('EMPShot03', false)
            local wep = self:GetWeaponByLabel('EMPShot03')
            wep:ChangeMaxRadius(wep:GetBlueprint().MaxRadius)

            self:SetPainterRange(enh, 0, true)
        elseif enh == 'ElectroMagneticOverdrive' then
            if not Buffs['CybranEMPHealth4'] then
                BuffBlueprint {
                    Name = 'CybranEMPHealth4',
                    DisplayName = 'CybranEMPHealth4',
                    BuffType = 'CybranEMPHealth',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'CybranEMPHealth4')
          
            local wep = self:GetWeaponByLabel('EMPShot03')
            wep:ChangeMaxRadius(bp.MainGunRange)
			wep:ChangeRateOfFire(bp.EMPFireRate)
			
            local wep2 = self:GetWeaponByLabel('RightRipper')
			wep2:ChangeMaxRadius(bp.MainGunRange)
			wep2:ChangeRateOfFire(bp.MainGunFireRate)
			wep2:AddDamageMod(bp.MainGunDamageMod)
            
            self:SetPainterRange(enh, bp.MainGunRange, false)
        elseif enh == 'ElectroMagneticOverdriveRemove' then    
            if Buff.HasBuff(self, 'CybranEMPHealth4') then
                Buff.RemoveBuff(self, 'CybranEMPHealth4')
            end
            
            self:SetWeaponEnabledByLabel('EMPShot03', false)
            local wep = self:GetWeaponByLabel('EMPShot03')
            wep:ChangeMaxRadius(wep:GetBlueprint().MaxRadius)

            self:SetPainterRange(enh, 0, true)

        -- Mazer

        elseif enh == 'Mazer' then
            if not Buffs['CybranMazerHealth1'] then
                BuffBlueprint {
                    Name = 'CybranMazerHealth1',
                    DisplayName = 'CybranMazerHealth1',
                    BuffType = 'CybranMazerHealth',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'CybranMazerHealth1')

            self:SetWeaponEnabledByLabel('MLG01', true)
        elseif enh == 'MazerRemove' then
            if Buff.HasBuff(self, 'CybranMazerHealth1') then
                Buff.RemoveBuff(self, 'CybranMazerHealth1')
            end

            self:SetWeaponEnabledByLabel('MLG01', false)
        elseif enh == 'AlternatingLaserAssembly' then
            if not Buffs['CybranMazerHealth2'] then
                BuffBlueprint {
                    Name = 'CybranMazerHealth2',
                    DisplayName = 'CybranMazerHealth2',
                    BuffType = 'CybranMazerHealth',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'CybranMazerHealth2')

            self:SetWeaponEnabledByLabel('MLG01', false)
            self:SetWeaponEnabledByLabel('MLG02', true)
            local laser = self:GetWeaponByLabel('MLG02')
            laser:ChangeMaxRadius(bp.LaserRange)

            self:SetPainterRange(enh, bp.LaserRange, false)

            -- Install Jury Rigged Ripper
            self:TogglePrimaryGun(bp.NewRoF, bp.NewMaxRadius)
        elseif enh == 'AlternatingLaserAssemblyRemove' then
            if Buff.HasBuff(self, 'CybranMazerHealth2') then
                Buff.RemoveBuff(self, 'CybranMazerHealth2')
            end

            self:SetWeaponEnabledByLabel('MLG02', false)
            local laser = self:GetWeaponByLabel('MLG02')
            laser:ChangeMaxRadius(laser:GetBlueprint().MaxRadius)

            self:SetPainterRange(enh, 0, true)

            self:TogglePrimaryGun(bp.NewRoF)
        elseif enh == 'SuperconductivePowerConduits' then
            if not Buffs['CybranMazerHealth3'] then
                BuffBlueprint {
                    Name = 'CybranMazerHealth3',
                    DisplayName = 'CybranMazerHealth3',
                    BuffType = 'CybranMazerHealth',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'CybranMazerHealth3')

            self:SetWeaponEnabledByLabel('MLG02', false)
            self:SetWeaponEnabledByLabel('MLG03', true)
            local laser = self:GetWeaponByLabel('MLG03')
            laser:ChangeMaxRadius(bp.LaserRange)

            self:SetPainterRange(enh, bp.LaserRange, false)
        elseif enh == 'SuperconductivePowerConduitsRemove' then

            if Buff.HasBuff(self, 'CybranMazerHealth3') then
                Buff.RemoveBuff(self, 'CybranMazerHealth3')
            end
            
            self:SetWeaponEnabledByLabel('MLG03', false)
            local laser = self:GetWeaponByLabel('MLG03')
            laser:ChangeMaxRadius(laser:GetBlueprint().MaxRadius)

            self:SetPainterRange(enh, 0, true)
			
        -- Anti-Air System    

        elseif enh == 'AntiAirComplex' then
            if not Buffs['CybranAAHealth1'] then
                BuffBlueprint {
                    Name = 'CybranAAHealth1',
                    DisplayName = 'CybranAAHealth1',
                    BuffType = 'CybranAAHealth',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                        Regen = {
                            Add = bp.NewRegenRate,
                            Mult = 1.0,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'CybranAAHealth1')

			
            self:SetWeaponEnabledByLabel('AA01', true)
            self:SetWeaponEnabledByLabel('AA02', true)
            self:SetWeaponEnabledByLabel('AA03', true)
            self:SetWeaponEnabledByLabel('AA04', true)
        elseif enh == 'AntiAirComplexRemove' then
            if Buff.HasBuff(self, 'CybranAAHealth1') then
                Buff.RemoveBuff(self, 'CybranAAHealth1')
            end
            
            self:SetWeaponEnabledByLabel('AA01', false)
            self:SetWeaponEnabledByLabel('AA02', false)
            self:SetWeaponEnabledByLabel('AA03', false)
            self:SetWeaponEnabledByLabel('AA04', false)
       elseif enh == 'IntegratedReconnaissanceSystems' then
            if not Buffs['CybranAAHealth2'] then
                BuffBlueprint {
                    Name = 'CybranAAHealth2',
                    DisplayName = 'CybranAAHealth2',
                    BuffType = 'CybranAAHealth',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                        Regen = {
                            Add = bp.NewRegenRate,
                            Mult = 1.0,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'CybranAAHealth2')
			
            local aa1 = self:GetWeaponByLabel('AA01')
			aa1:AddDamageMod(bp.AADamageMod)
			aa1:ChangeRateOfFire(bp.AAFireRate)
			aa1:ChangeMaxRadius(bp.AAMaxRadius)
			local aa2 = self:GetWeaponByLabel('AA02')
			aa2:AddDamageMod(bp.AADamageMod)
			aa2:ChangeRateOfFire(bp.AAFireRate)
			aa2:ChangeMaxRadius(bp.AAMaxRadius)
            local aa3 = self:GetWeaponByLabel('AA03')
			aa3:AddDamageMod(bp.AADamageMod)
			aa3:ChangeRateOfFire(bp.AAFireRate)
			aa3:ChangeMaxRadius(bp.AAMaxRadius)
			local aa4 = self:GetWeaponByLabel('AA04')
			aa4:AddDamageMod(bp.AADamageMod)
			aa4:ChangeRateOfFire(bp.AAFireRate)
			aa4:ChangeMaxRadius(bp.AAMaxRadius)
			
            self:SetWeaponEnabledByLabel('AA03', true)
            self:SetWeaponEnabledByLabel('AA04', true)
        elseif enh == 'IntegratedReconnaissanceSystemsRemove' then
            if Buff.HasBuff(self, 'CybranAAHealth2') then
                Buff.RemoveBuff(self, 'CybranAAHealth2')
            end
            
            self:SetWeaponEnabledByLabel('AA03', false)
            self:SetWeaponEnabledByLabel('AA04', false)
        elseif enh == 'AirAreaDenialSystem' then
            if not Buffs['CybranAAHealth3'] then
                BuffBlueprint {
                    Name = 'CybranAAHealth3',
                    DisplayName = 'CybranAAHealth3',
                    BuffType = 'CybranAAHealth',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                        Regen = {
                            Add = bp.NewRegenRate,
                            Mult = 1.0,
                        },
                    },
                }
            end
            local aa1 = self:GetWeaponByLabel('AA01')
			aa1:AddDamageMod(bp.AADamageMod)
			aa1:ChangeRateOfFire(bp.AAFireRate)
			aa1:ChangeMaxRadius(bp.AAMaxRadius)
			local aa2 = self:GetWeaponByLabel('AA02')
			aa2:AddDamageMod(bp.AADamageMod)
			aa2:ChangeRateOfFire(bp.AAFireRate)
			aa2:ChangeMaxRadius(bp.AAMaxRadius)
            local aa3 = self:GetWeaponByLabel('AA03')
			aa3:AddDamageMod(bp.AADamageMod)
			aa3:ChangeRateOfFire(bp.AAFireRate)
			aa3:ChangeMaxRadius(bp.AAMaxRadius)
			local aa4 = self:GetWeaponByLabel('AA04')
			aa4:AddDamageMod(bp.AADamageMod)
			aa4:ChangeRateOfFire(bp.AAFireRate)
			aa4:ChangeMaxRadius(bp.AAMaxRadius)
			
            Buff.ApplyBuff(self, 'CybranAAHealth3')
        elseif enh == 'AirAreaDenialSystemRemove' then
            if Buff.HasBuff(self, 'CybranAAHealth3') then
                Buff.RemoveBuff(self, 'CybranAAHealth3')
            end
		elseif enh == 'AircraftRepairField' then
			
            if not Buffs['AirNanobotsACUCybranAura'] then
                BuffBlueprint {
                    Name = 'AirNanobotsACUCybranAura',
                    DisplayName = 'AirNanobotsACUCybranAura',
                    BuffType = 'COMMANDERAURA_NavalRegenAura',
                    Stacks = 'STACKS',
                    Duration = 5,
                    Affects = {
                        Regen = {
                            Add = bp.ShipAuraRegenAdditive,
                            Mult = 1.0,
                        }
                    },
                }
            end	
			if self.RegenFieldFXBag then
                for k, v in self.RegenFieldFXBag do
                    v:Destroy()
                end
                self.RegenFieldFXBag = {}
            end

            if self.RegenThreadHandler then
                KillThread(self.RegenThreadHandler)
                self.RegenThreadHandler = nil
            end
			
            self.RegenThreadHandler = self:ForkThread(self.AirRegenBuffThread, enh)
			    table.insert(self.RegenFieldFXBag, CreateAttachedEmitter(self, 'Torso', self:GetArmy(), '/effects/emitters/seraphim_regenerative_aura_01_emit.bp'))
            
        elseif enh == 'AircraftRepairFieldRemove' then
		    if self.RegenThreadHandler then
                KillThread(self.RegenThreadHandler)
                self.RegenThreadHandler = nil
            end

            if self.RegenFieldFXBag then
                for k, v in self.RegenFieldFXBag do
                    v:Destroy()
                end
                self.RegenFieldFXBag = {}
            end

        -- Armor System
            
        elseif enh == 'ArmorPlating' then
            if not Buffs['CybranArmorHealth1'] then
                BuffBlueprint {
                    Name = 'CybranArmorHealth1',
                    DisplayName = 'CybranArmorHealth1',
                    BuffType = 'CybranArmorHealth',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                        Regen = {
                            Add = bp.NewRegenRate,
                            Mult = 1.0,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'CybranArmorHealth1')

			
            self:SetWeaponEnabledByLabel('AA01', true)
            self:SetWeaponEnabledByLabel('AA02', true)
        elseif enh == 'ArmorPlatingRemove' then
            if Buff.HasBuff(self, 'CybranArmorHealth1') then
                Buff.RemoveBuff(self, 'CybranArmorHealth1')
            end
            
            self:SetWeaponEnabledByLabel('AA01', false)
            self:SetWeaponEnabledByLabel('AA02', false)
        elseif enh == 'StructuralIntegrityFields' then
            if not Buffs['CybranArmorHealth2'] then
                BuffBlueprint {
                    Name = 'CybranArmorHealth2',
                    DisplayName = 'CybranArmorHealth2',
                    BuffType = 'CybranArmorHealth',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                        Regen = {
                            Add = bp.NewRegenRate,
                            Mult = 1.0,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'CybranArmorHealth2')
			
            local aa1 = self:GetWeaponByLabel('AA01')
			aa1:AddDamageMod(bp.AADamageMod)
			aa1:ChangeRateOfFire(bp.AAFireRate)
			aa1:ChangeMaxRadius(bp.AAMaxRadius)
			local aa2 = self:GetWeaponByLabel('AA02')
			aa2:AddDamageMod(bp.AADamageMod)
			aa2:ChangeRateOfFire(bp.AAFireRate)
			aa2:ChangeMaxRadius(bp.AAMaxRadius)
            local aa3 = self:GetWeaponByLabel('AA03')
			aa3:AddDamageMod(bp.AADamageMod)
			aa3:ChangeRateOfFire(bp.AAFireRate)
			aa3:ChangeMaxRadius(bp.AAMaxRadius)
			local aa4 = self:GetWeaponByLabel('AA04')
			aa4:AddDamageMod(bp.AADamageMod)
			aa4:ChangeRateOfFire(bp.AAFireRate)
			aa4:ChangeMaxRadius(bp.AAMaxRadius)
			
            self:SetWeaponEnabledByLabel('AA03', true)
            self:SetWeaponEnabledByLabel('AA04', true)
        elseif enh == 'StructuralIntegrityFieldsRemove' then
            if Buff.HasBuff(self, 'CybranArmorHealth2') then
                Buff.RemoveBuff(self, 'CybranArmorHealth2')
            end
            
            self:SetWeaponEnabledByLabel('AA03', false)
            self:SetWeaponEnabledByLabel('AA04', false)
        elseif enh == 'CompositeMaterials' then
            if not Buffs['CybranArmorHealth3'] then
                BuffBlueprint {
                    Name = 'CybranArmorHealth3',
                    DisplayName = 'CybranArmorHealth3',
                    BuffType = 'CybranArmorHealth',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                        Regen = {
                            Add = bp.NewRegenRate,
                            Mult = 1.0,
                        },
                    },
                }
            end
            local aa1 = self:GetWeaponByLabel('AA01')
			aa1:AddDamageMod(bp.AADamageMod)
			aa1:ChangeRateOfFire(bp.AAFireRate)
			aa1:ChangeMaxRadius(bp.AAMaxRadius)
			local aa2 = self:GetWeaponByLabel('AA02')
			aa2:AddDamageMod(bp.AADamageMod)
			aa2:ChangeRateOfFire(bp.AAFireRate)
			aa2:ChangeMaxRadius(bp.AAMaxRadius)
            local aa3 = self:GetWeaponByLabel('AA03')
			aa3:AddDamageMod(bp.AADamageMod)
			aa3:ChangeRateOfFire(bp.AAFireRate)
			aa3:ChangeMaxRadius(bp.AAMaxRadius)
			local aa4 = self:GetWeaponByLabel('AA04')
			aa4:AddDamageMod(bp.AADamageMod)
			aa4:ChangeRateOfFire(bp.AAFireRate)
			aa4:ChangeMaxRadius(bp.AAMaxRadius)
			
            Buff.ApplyBuff(self, 'CybranArmorHealth3')
        elseif enh == 'CompositeMaterialsRemove' then
            if Buff.HasBuff(self, 'CybranArmorHealth3') then
                Buff.RemoveBuff(self, 'CybranArmorHealth3')
            end
            
        -- Counter-Intel Systems
        
        elseif enh == 'ElectronicsEnhancment' then
            if not Buffs['CybranIntelHealth1'] then
                BuffBlueprint {
                    Name = 'CybranIntelHealth1',
                    DisplayName = 'CybranIntelHealth1',
                    BuffType = 'CybranIntelHealth',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'CybranIntelHealth1')

            if ScenarioInfo.Options.OmniCheat ~= "on" or self:GetAIBrain().BrainType == 'Human' then
                self:SetIntelRadius('Vision', bp.NewVisionRadius)
                self:SetIntelRadius('WaterVision', bp.NewVisionRadius)
                self:SetIntelRadius('Omni', bp.NewOmniRadius)
            end
        elseif enh == 'ElectronicsEnhancmentRemove' then
            if Buff.HasBuff(self, 'CybranIntelHealth1') then
                Buff.RemoveBuff(self, 'CybranIntelHealth1')
            end

            local bpIntel = self:GetBlueprint().Intel
            if ScenarioInfo.Options.OmniCheat ~= "on" or self:GetAIBrain().BrainType == 'Human' then
                self:SetIntelRadius('Vision', bpIntel.VisionRadius)
                self:SetIntelRadius('WaterVision', bpIntel.VisionRadius)
                self:SetIntelRadius('Omni', bpIntel.OmniRadius)
            end
        elseif enh == 'ElectronicCountermeasures' then
            if not Buffs['CybranIntelHealth2'] then
                BuffBlueprint {
                    Name = 'CybranIntelHealth2',
                    DisplayName = 'CybranIntelHealth2',
                    BuffType = 'CybranIntelHealth',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                        Regen = {
                            Add = bp.NewRegenRate,
                            Mult = 1.0,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'CybranIntelHealth2')

            if self.IntelEffectsBag then
                EffectUtil.CleanupEffectBag(self,'IntelEffectsBag')
                self.IntelEffectsBag = nil
            end

            self:AddToggleCap('RULEUTC_StealthToggle')
            self:EnableUnitIntel('Enhancement', 'RadarStealth')
            self:EnableUnitIntel('Enhancement', 'SonarStealth')
        elseif enh == 'ElectronicCountermeasuresRemove' then
            if Buff.HasBuff(self, 'CybranIntelHealth2') then
                Buff.RemoveBuff(self, 'CybranIntelHealth2')
            end

            self:RemoveToggleCap('RULEUTC_StealthToggle')
            self:DisableUnitIntel('Enhancement', 'RadarStealth')
            self:DisableUnitIntel('Enhancement', 'SonarStealth')
        elseif enh == 'CloakingSubsystems' then
            if not Buffs['CybranIntelHealth3'] then
                BuffBlueprint {
                    Name = 'CybranIntelHealth3',
                    DisplayName = 'CybranIntelHealth3',
                    BuffType = 'CybranIntelHealth',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                        Regen = {
                            Add = bp.NewRegenRate,
                            Mult = 1.0,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'CybranIntelHealth3')
            
            self:RemoveToggleCap('RULEUTC_StealthToggle')
            self:AddToggleCap('RULEUTC_CloakToggle')
            self:EnableUnitIntel('Enhancement', 'Cloak')
        elseif enh == 'CloakingSubsystemsRemove' then
            if Buff.HasBuff(self, 'CybranIntelHealth3') then
                Buff.RemoveBuff(self, 'CybranIntelHealth3')
            end

            self:RemoveToggleCap('RULEUTC_CloakToggle')
            self:DisableUnitIntel('Enhancement', 'Cloak')
            
        -- Mobility Systems
            
        elseif enh == 'ActuatorReplacement' then
            if not Buffs['CybranMobilityHealth1'] then
                BuffBlueprint {
                    Name = 'CybranMobilityHealth1',
                    DisplayName = 'CybranMobilityHealth1',
                    BuffType = 'CybranMobilityHealth',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                        Regen = {
                            Add = bp.NewRegenRate,
                            Mult = 1.0,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'CybranMobilityHealth1')

            self:SetSpeedMult(bp.NewSpeed)
        elseif enh == 'ActuatorReplacementRemove' then
            if Buff.HasBuff(self, 'CybranMobilityHealth1') then
                Buff.RemoveBuff(self, 'CybranMobilityHealth1')
            end

            self:SetSpeedMult(1)
        elseif enh == 'AntiAirSubsystem' then
            if not Buffs['CybranMobilityHealth2'] then
                BuffBlueprint {
                    Name = 'CybranMobilityHealth2',
                    DisplayName = 'CybranMobilityHealth2',
                    BuffType = 'CybranMobilityHealth',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                        Regen = {
                            Add = bp.NewRegenRate,
                            Mult = 1.0,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'CybranMobilityHealth2')

            self:AddCommandCap('RULEUCC_Teleport')
            
            self:SetWeaponEnabledByLabel('AA01', true)
            self:SetWeaponEnabledByLabel('AA02', true)
        elseif enh == 'AntiAirSubsystemRemove' then
            if Buff.HasBuff(self, 'CybranMobilityHealth2') then
                Buff.RemoveBuff(self, 'CybranMobilityHealth2')
            end
            
            self:RemoveCommandCap('RULEUCC_Teleport')
            
            self:SetWeaponEnabledByLabel('AA01', false)
            self:SetWeaponEnabledByLabel('AA02', false)
        elseif enh == 'NanoRegenerationSubsystem' then
            if not Buffs['CybranMobilityHealth3'] then
                BuffBlueprint {
                    Name = 'CybranMobilityHealth3',
                    DisplayName = 'CybranMobilityHealth3',
                    BuffType = 'CybranMobilityHealth',
                    Stacks = 'STACKS',
                    Duration = -1,
                    Affects = {
                        MaxHealth = {
                            Add = bp.NewHealth,
                            Mult = 1.0,
                        },
                        Regen = {
                            Add = bp.NewRegenRate,
                            Mult = 1.0,
                        },
                    },
                }
            end
            Buff.ApplyBuff(self, 'CybranMobilityHealth3')
        elseif enh == 'NanoRegenerationSubsystemRemove' then
            if Buff.HasBuff(self, 'CybranMobilityHealth3') then
                Buff.RemoveBuff(self, 'CybranMobilityHealth3')
            end
        end
        
        -- Remove prerequisites
        if not removal then
            if bp.RemoveEnhancements then
                for k, v in bp.RemoveEnhancements do                
                    if string.sub(v, -6) ~= 'Remove' and v ~= string.sub(enh, 0, -7) then
                        self:CreateEnhancement(v .. 'Remove', true)
                    end
                end
            end
        end
    end,

    IntelEffects = {
        Cloak = {
            {
                Bones = {
                    'Head',
                    'Right_Turret',
                    'Left_Turret',
                    'Right_Arm_B01',
                    'Left_Arm_B01',
                    'Left_Leg_B01',
                    'Left_Leg_B02',
                    'Right_Leg_B01',
                    'Right_Leg_B02',
                },
                Scale = 1.0,
                Type = 'Cloak01',
            },
        },
        Field = {
            {
                Bones = {
                    'Head',
                    'Right_Turret',
                    'Left_Turret',
                    'Right_Arm_B01',
                    'Left_Arm_B01',
                    'Left_Leg_B01',
                    'Left_Leg_B02',
                    'Right_Leg_B01',
                    'Right_Leg_B02',
                },
                Scale = 1.6,
                Type = 'Cloak01',
            },    
        },    
    },

    OnIntelEnabled = function(self)
        ACUUnit.OnIntelEnabled(self)
        if self:HasEnhancement('CloakingSubsystems') and self:IsIntelEnabled('Cloak') then
            self:SetEnergyMaintenanceConsumptionOverride(self:GetBlueprint().Enhancements['CloakingSubsystems'].MaintenanceConsumptionPerSecondEnergy)
            self:SetMaintenanceConsumptionActive()
            if not self.IntelEffectsBag then
                self.IntelEffectsBag = {}
                self.CreateTerrainTypeEffects(self, self.IntelEffects.Cloak, 'FXIdle',  self:GetCurrentLayer(), nil, self.IntelEffectsBag)
            end            
        elseif self:HasEnhancement('ElectronicCountermeasures') and self:IsIntelEnabled('RadarStealth') and self:IsIntelEnabled('SonarStealth') then
            self:SetEnergyMaintenanceConsumptionOverride(self:GetBlueprint().Enhancements['ElectronicCountermeasures'].MaintenanceConsumptionPerSecondEnergy)
            self:SetMaintenanceConsumptionActive()  
            if not self.IntelEffectsBag then 
                self.IntelEffectsBag = {}
                self.CreateTerrainTypeEffects(self, self.IntelEffects.Field, 'FXIdle',  self:GetCurrentLayer(), nil, self.IntelEffectsBag)
            end
        end
    end,

    OnIntelDisabled = function(self)
        ACUUnit.OnIntelDisabled(self)
        if self.IntelEffectsBag then
            EffectUtil.CleanupEffectBag(self,'IntelEffectsBag')
            self.IntelEffectsBag = nil
        end
        if self:HasEnhancement('CloakingSubsystems') and not self:IsIntelEnabled('Cloak') then
            self:SetMaintenanceConsumptionInactive()
        elseif self:HasEnhancement('ElectronicCountermeasures') and not self:IsIntelEnabled('RadarStealth') and not self:IsIntelEnabled('SonarStealth') then
            self:SetMaintenanceConsumptionInactive()
        end
    end,
}
    
TypeClass = ERL0001
