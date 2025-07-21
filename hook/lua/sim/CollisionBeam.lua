--****************************************************************************
--**
--**  File     :  /lua/sim/collisionbeam.lua
--**  Author(s):
--**
--**  Summary  :
--**
--**  Copyright © 2005 Gas Powered Games, Inc.  All rights reserved.
--****************************************************************************
local oldCollisionBeam = CollisionBeam
CollisionBeam = Class(oldCollisionBeam) {

    OnImpact = function(self, impactType, targetEntity)
        self:SetDamageTable()
        oldCollisionBeam.OnImpact(self, impactType, targetEntity)
    end,

-- seems this is necessary, fix by Gilbot-X
    SetDamageTable = function(self)
        self.DamageTable = self.Weapon:GetDamageTable()
        --# Gilbot-X: I added this next line as it look like it was needed.
        self.DamageTable.DamageAmount = self.Weapon:GetBlueprint().Damage

        --# This was the old code that we are replacing.
    end,
    -- destructive override, as it seems the original function had no check if the unit doing beam damage
    -- was still alive, also removed LOG('*ERROR: THERE IS NO INSTIGATOR FOR DAMAGE ON THIS COLLISIONBEAM = ', repr(damageData)) as it appears to have frozen my game on some occasions
    -- that is debugcode which should not be enabled anyway, in a finished product
        DoDamage = function(self, instigator, damageData, targetEntity)
        local damage = damageData.DamageAmount or 0
        local dmgmod = 1
        if self.Weapon.DamageModifiers then
            for k, v in self.Weapon.DamageModifiers do
                dmgmod = v * dmgmod
            end
        end
        damage = damage * dmgmod
        if not instigator:IsDead() and damage > 0 then
            local radius = damageData.DamageRadius
            if radius and radius > 0 then
                if not damageData.DoTTime or damageData.DoTTime <= 0 then
                    DamageArea(instigator, self:GetPosition(1), radius, damage, damageData.DamageType or 'Normal', damageData.DamageFriendly or false)
                else
                    ForkThread(DefaultDamage.AreaDoTThread, instigator, self:GetPosition(1), damageData.DoTPulses or 1, (damageData.DoTTime / (damageData.DoTPulses or 1)), radius, damage, damageData.DamageType, damageData.DamageFriendly)
                end
            elseif targetEntity then
                if not damageData.DoTTime or damageData.DoTTime <= 0 then
                    Damage(instigator, self:GetPosition(), targetEntity, damage, damageData.DamageType)
                else
                    ForkThread(DefaultDamage.UnitDoTThread, instigator, targetEntity, damageData.DoTPulses or 1, (damageData.DoTTime / (damageData.DoTPulses or 1)), damage, damageData.DamageType, damageData.DamageFriendly)
                end
            else
                DamageArea(instigator, self:GetPosition(1), 0.25, damage, damageData.DamageType, damageData.DamageFriendly)
            end
        end
    end,

}
