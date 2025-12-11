Unit = {}
Unit.__index = Unit
function Unit.New(fs)
    local self = setmetatable({}, Unit)
    self.op = {
      [ObjP.ATTACK] = fs.attack,
      [ObjP.DEFENCE]= fs.defence,
      [ObjP.HP] = fs.hp,
      [ObjP.CRITRATE] = fs.critRate,
      [ObjP.CRITDAMAGE] = fs.critDamage,
      [ObjP.ATTACKRATE] = fs.attackRate,
      ["level"] = fs.level,
      ["feature"] = fs.feature,
      ["career"] = 0,
      ["camp"] = fs.camp
    }
    self.p = {
      [ObjP.ATTACK] = self.op[ObjP.ATTACK],
      [ObjP.DEFENCE] = self.op[ObjP.DEFENCE],
      [ObjP.HP] = self.op[ObjP.HP],
      [ObjP.CRITRATE] = self.op[ObjP.CRITRATE],
      [ObjP.CRITDAMAGE] = self.op[ObjP.CRITDAMAGE],
      [ObjP.ATTACKRATE] = self.op[ObjP.ATTACKRATE]
    }
    self.id = fs.id
    self.isAlive = true
    self.framesPerBasic = 40
    self.invalid_until = 0
    self.effects = {}
    self.sourceEffects = {}
    self.tempSourceEffects = {}
    return self
end
function Unit:loadSkin(skin)
    self.skin = skin
    self.framesPerBasic = math.ceil(tonumber(self.skin.basic) * 30)
    self.framesPerEnergy = math.ceil(tonumber(self.skin.energy) * 30)
end

--personally added functions
function Unit:takeDamage(damage)
  self.p[ObjP.HP] = math.max(0, self.p[ObjP.HP] - damage)
end

function Unit:takeHeal(healing)
  self.p[ObjP.HP] = math.min(self:GetOriginalHp(), self.p[ObjP.HP] + healing)
end

function Unit:triggerEffect(action)
  for id, effect in pairs (self.tempSourceEffects) do 
    if effect.triggerActionType then
      for _, t in ipairs(effect.triggerActionType) do
        if t == action then effect:AddEffect() end
      end
    end
  end
end

function Unit:isImmune(effect_type)
    for id, effect in pairs(self.effects) do
        if effect.effect_type == ConfigBuffType.IMMUNE_BUFF_TYPE and getTime() < effect.endtime then
            for _, t in pairs (effect.effect) do     
                if t == effect_type then
                return true
                end
            end
        end
    end
    return false
end

function Unit:isInvincible()
    for _, effect in pairs(self.effects) do
        if effect.effect_type == ConfigBuffType.IMMUNE then
            return true
        end
    end
    return false
end

function Unit:isImmuneHeal()
    for _, effect in pairs(self.effects) do
        if effect.effect_type == ConfigBuffType._HEAL then
            return true
        end
    end
    return false
end

function Unit:isImmuneSkill()
    for _, effect in pairs(self.effects) do
        if effect.effect_type == ConfigBuffType.IMMUNE_SKILL_PHYSICAL then
            return true
        end
    end
    return false
end

function Unit:isImmuneSkillHeal()
    for _, effect in pairs(self.effects) do
        if effect.effect_type == ConfigBuffType.IMMUNE_SKILL_HEAL then
            return true
        end
    end
    return false
end

function Unit:isImmuneBasic()
    for _, effect in pairs(self.effects) do
        if effect.effect_type == ConfigBuffType.IMMUNE_ATTACK_PHYSICAL then
            return true
        end
    end
    return false
end

function Unit:isImmuneBasicHeal()
    for _, effect in pairs(self.effects) do
        if effect.effect_type == ConfigBuffType.IMMUNE_ATTACK_HEAL then
            return true
        end
    end
    return false
end

function Unit:GetAggro()
  if self.threat then
    return self.threat
  else
    return self.id
  end
end

function Unit:GetDotDamage(time)
  local damage = 0
  for id, effect in pairs(self.effects) do
    if effect.effect_type == ConfigBuffType.DOT then
      if effect.nexttick and time >= effect.nexttick and not self:isImmune(ConfigBuffType.DOT) then
        damage = damage + effect.damage 
        effect.nexttick = math.min(effect.nexttick + 1, effect.endtime)
      end
    elseif effect.effect_type == ConfigBuffType.DOT_CHP then
      if effect.nexttick and time >= effect.nexttick and not self:isImmune(ConfigBuffType.DOT_CHP) then
        damage = damage + effect.damage
        effect.nexttick = math.min(effect.nexttick + 1, effect.endtime)
      end
    elseif effect.effect_type == ConfigBuffType.DOT_OHP then
      if effect.nexttick and time >= effect.nexttick and not self:isImmune(ConfigBuffType.DOT_OHP) then
        damage = damage + effect.damage
        effect.nexttick = math.min(effect.nexttick + 1, effect.endtime)
      end
    end
  end
  return damage
end

function Unit:GetInstantDamage()
  local damage = 0 
  local to_remove = {}
  for id, effect in pairs(self.effects) do
    if effect.effect_type == ConfigBuffType.ISD or effect.effect_type == ConfigBuffType.ISD_CHP or effect.effect_type == ConfigBuffType.ISD_OHP then
      damage = damage + effect.damage
      table.insert(to_remove, id)
    elseif effect.effect_type == ConfigBuffType.EXECUTE then
      damage = damage + effect.damage
      self:CheckExecute(effect)
      table.insert(to_remove, id)
    end
  end
  for _, id in pairs (to_remove) do 
    self.effects[id] = nil
  end
  return damage
end

function Unit:GetBasicDamage()
  local damage = 0
  local to_remove = {}
  for id, effect in pairs(self.effects) do
    if effect.effect_type == ConfigBuffType.BASE then 
      damage = damage + effect.damage
      table.insert(to_remove, id)
    end
  end
  for _, id in pairs (to_remove) do
    self.effects[id] = nil
  end
  return damage
end

function Unit:GetDamage(Target,Effect)
  local damage = 0
  if Effect.effect_type == ConfigBuffType.ISD or Effect.effect_type == ConfigBuffType.DOT or Effect.effect_type == ConfigBuffType.EXECUTE then 
    damage = self:GetSkillDamage(Target,Effect.effect[1],Effect.effect[2])
  elseif Effect.effect_type == ConfigBuffType.ISD_CHP or Effect.effect_type == ConfigBuffType.DOT_CHP then 
    damage = Target:GetCurrentHp() * Effect.effect[1]
  elseif Effect.effect_type == ConfigBuffType.ISD_OHP or Effect.effect_type == ConfigBuffType.DOT_OHP then
    damage = Target:GetOriginalHp() * Effect.effect[1]
  end
  damage = Target:FixFinalGetDamage(damage, DamageType.SKILL_PHYSICAL)
  return damage
end

function Unit:GetHoTHealing(time)
  local healing = 0
  for id, effect in pairs(self.effects) do
    if effect.effect_type == ConfigBuffType.HOT then
      if effect.nexttick and time >= effect.nexttick and not self:isImmune(ConfigBuffType.HOT) then
        healing = healing + effect.healing 
        effect.nexttick = math.min(effect.nexttick + 1, effect.endtime)
      end
    elseif effect.effect_type == ConfigBuffType.HOT_LHP then
      if effect.nexttick and time >= effect.nexttick and not self:isImmune(ConfigBuffType.HOT_LHP) then
        healing = healing + effect.healing
        effect.nexttick = math.min(effect.nexttick + 1, effect.endtime)
      end
    elseif effect.effect_type == ConfigBuffType.HOT_OHP then
      if effect.nexttick and time >= effect.nexttick and not self:isImmune(ConfigBuffType.HOT_OHP) then
        healing = healing + effect.healing
        effect.nexttick = math.min(effect.nexttick + 1, effect.endtime)
      end
    end
  end
  return healing
end

function Unit:GetInstantHealing()
  local healing = 0 
  local to_remove = {}
  for id, effect in pairs(self.effects) do
    if effect.effect_type == ConfigBuffType.HEAL or effect.effect_type == ConfigBuffType.HEAL_LHP or effect.effect_type == ConfigBuffType.HEAL_OHP then
      healing = healing + effect.healing
      table.insert(to_remove, id)
    end
  end
  for _, id in pairs (to_remove) do 
    self.effects[id] = nil
  end
  return healing
end

function Unit:GetBasicHealing()
  local healing = 0
  local to_remove = {}
  for id, effect in pairs(self.effects) do
    if effect.effect_type == ConfigBuffType.BASE then 
      healing = healing + effect.damage
      table.insert(to_remove, id)
    end
  end
  for _, id in pairs (to_remove) do
    self.effects[id] = nil
  end
  return healing
end

function Unit:GetHeal(Target,Effect)
  local healing = 0
  if Effect.effect_type == ConfigBuffType.HEAL or Effect.effect_type == ConfigBuffType.HOT then 
    healing = self:GetSkillHeal(Effect.effect[1], Target)
  --elseif Effect.effect_type == ConfigBuffType.HEAL_BY_CHP then 
    --healing = Target:GetCurrentHp() * Effect.effect[1]
  elseif Effect.effect_type == ConfigBuffType.HEAL_LHP or Effect.effect_type == ConfigBuffType.HOT_LHP then
    healing = (Target:GetOriginalHp() - Target:GetCurrentHp()) * Effect.effect[1]
  elseif Effect.effect_type == ConfigBuffType.HEAL_OHP or Effect.effect_type == ConfigBuffType.HOT_OHP then
    healing = Target:GetOriginalHp() * Effect.effect[1]
  end
  healing = Target:FixFinalGetHeal(healing, DamageType.SKILL_HEAL)
  return healing
end

function Unit:CheckExecute(effect)
  if self:GetCurHpPercent() < effect.effect[3] then
    self.p[ObjP.HP] = 0
  end
end

function Unit:getBonusFromCharge()
    local bonus = {
        ["atk"] = 0,
        ["energy"] = 0,
        ["heal"] = 0,
        ["ultimateDamage"] = 0,
        ["isCritical"] = false
    }
    for id, effect in pairs(self.effects) do
        if effect.effect_type == ConfigBuffType.ATK_ATTACK_B_CHARGE then
            bonus.atk = bonus.atk + effect.effect[1]
            effect.count = effect.count - 1 
        elseif effect.effect_type == ConfigBuffType.ATK_ENERGY_CHARGE then
            bonus.energy = bonus.energy + effect.effect[1]
            effect.count = effect.count - 1 
        elseif effect.effect_type == ConfigBuffType.ATK_HEAL_CHARGE then
            bonus.heal = bonus.heal + effect.effect[1]
            effect.count = effect.count - 1 
        elseif effect.effect_type == ConfigBuffType.ATK_ISD_CHARGE then
            bonus.ultimateDamage = bonus.ultimateDamage + effect.effect[1]
            effect.count = effect.count - 1 
        elseif effect.effect_type == ConfigBuffType.ATK_CR_RATE_CHARGE then
            bonus.isCritical = true
            effect.count = effect.count - 1
        end
        if effect.count <= 0 then
            self.effects[id] = nil
        end
    end
    return bonus
end

function Unit:RemoveEffect(time)
    for id, effect in pairs(self.effects) do
        if effect.effect_type ~= ConfigBuffType.ATK_ATTACK_B_CHARGE then
            if effect.endtime <= time then
                self.effects[id] = nil
            end
        end
    end
end

function Unit:UpdateEffect()
    local time = getTime()
    local damage = 0
    for _, pp in pairs (ObjPP) do 
      self:Updatepp(pp)
    end
    self:CheckDispel()
    if not self:isInvincible() then
      if not self:isImmuneSkill() then
        damage = self:GetDotDamage(time) + self:GetInstantDamage()
        self:takeDamage(damage)
      end
      if not self:isImmuneBasic() then
        damage = self:GetBasicDamage()
        self:takeDamage(damage)
      end
    end
    if not self:isImmuneHeal() then
      if not self:isImmuneSkillHeal() then
        healing = self:GetHoTHealing(time) + self:GetInstantHealing()
        self:takeHeal(healing)
      end
      if not self:isImmuneBasicHeal() then
        healing = self:GetBasicHealing()
        self:takeHeal(healing)
      end
    end
    self:RemoveEffect(time)
end

function Unit:CheckDispel()
  local buff = 0
  local debuff = 0
  for id, effect in pairs (self.effects) do 
    if effect.effect_type == ConfigBuffType.DISPEL_DEBUFF then
      debuff = debuff + 1
    elseif effect.effect_type == ConfigBuffType.DISPEL_BUFF then
      buff = buff + 1
    end
  end
  for i = 1, debuff do
    self:DispelDebuff()
  end
  for i = 1, buff do 
    self:DispelBuff()
  end
end

function CheckBuffDebuff(effect) -- not a class function, could be moved to a possible effect class
  local val = IsDebuff[effect.effect_type]
  if val == ConfigIsDebuff.VALUE then
    return GetSign(effect.effect[1])
  elseif val == ConfigIsDebuff.INVVALUE then
    return not GetSign(effect.effect[1]) 
  elseif val == ConfigIsDebuff.BUFF then
    return true
  elseif val == ConfigIsDebuff.DEBUFF then
    return false
  else
    return nil
  end
end -- returns FALSE if debuff, TRUE if buff, nil if neither

function Unit:DispelBuff()
  for id, effect in pairs (self.effects) do -- goes through all effects 
    if CheckBuffDebuff(effect) == true and effect.immuneDispel[effect.sub_id] ~= ConfigBuffType.DISPEL_BUFF then
      self.effects[id] = nil
      break
    end
  end
end
--[[NOTE: each "broad" effect only has one immuneDispel table, however thankfully its copied between each effect.
    this does however mean that we need to know which "sub-effect" we're looking at to properly check immuneDispel]]

function Unit:DispelDebuff()
  for id, effect in pairs (self.effects) do 
    if CheckBuffDebuff(effect) == false and effect.immuneDispel[effect.sub_id] ~= ConfigBuffType.DISPEL_DEBUFF then
      self.effects[id] = nil
      break
    end
  end
end

function Unit:BasicAttack()
  target = getBasicAttackTarget(self, Units)
  if target == nil then
    goto stop
  end
  externalDamageParameter = self:getBonusFromCharge()
  if math.random()*100 < self:GetCriticalRate() then
    externalDamageParameter.isCritical = true
  end
  if target.op.camp == ConfigCampType.ENEMY then
    damage = self:GetAttackDamage(self, target, externalDamageParameter)
    damage = round(damage)
    damage = target:FixFinalGetDamage(damage, DamageType.ATTACK_PHYSICAL)
    healing = 0
  else
    healing = self:GetFixedHealing(externalDamageParameter)
    healing = round(healing)
    healing = target:FixFinalGetHeal(healing, DamageType.ATTACK_HEAL)
    damage = 0
  end
  self.sourceEffects[self.id] = Effect.BasicAttack(self)
  self.sourceEffects[self.id]:AddBasicAttack(target, damage, healing)
  self:triggerEffect(ConfigObjectTriggerActionType.ATTACK)
  ::stop::
end

--functions to convert from ObjProperty

function Unit:Getp(p, o) -- as far as I'm aware this just grabs whatever stat is passed in with "p"
  if o then -- the "o" in op seems to mean "orgin" since it's what's used to determine self.p values
    return self.op[p] --self.op/self.p both hold the unit's stats
  else
    return self.p[p]
  end
end

function Unit:InitObjPP() -- set all effects to 0 
  self.pp = {}
  for k, v in pairs(ObjPP) do
    self.pp[v] = 0
  end
end

function Unit:Getpp(pp) -- get the current value of a effect
  return self.pp[pp]
end
    --[[ok so this seems really simple, but self.pp confuses me just a little
    self.pp isn't defined in the same way that self.op and self.p are, instead theres a function ObjProp:InitObjPP() that builds it
    however, that function uses another function, self:GetUltimatePPAddition(), which is another can of worms i don't know how to deal with
    how do i get around this? i don't. I'm avoiding using Getpp()]]

    --[[update: I GET IT. I am a moron. Past me didn't realize that this is dealing with the effects and not the stats which makes the InitObjPP function make a lot mores sense
    as i understand it, it's basically going through all the different effect types and setting them to 0, or if there's some "addition" it adds it 
    I'm ignoring the addition thouhgh, i still don't get how it works]]

function Unit:Setpp(pp, value) -- Setpp just changes the value of an effect type
  self.pp[pp] = value
end

function Unit:Changepp(pp, delta)
  self:Setpp(pp, self:Getpp(pp) + delta)
end

function Unit:Updatepp(pp) -- I added this. updates values of effects using effects table. ONLY WORKS FOR BUFFS NOT CHARGES/IMMUNITIES
  local value = 0
  local effectpp = nil
  for id, effect in pairs (self.effects) do -- goes through all effects 
    effectpp = getFixCGDamage(effect) or TypeToPP[effect.effect_type]
    if effectpp == pp then -- checks if the effect type is the one we want to update
      value = value + effect.effect[1] -- if it is add its value to a running sum
    end
  end
  self:Setpp(pp,value) -- set the unit's pp value to the sum, pretty much just so we can use it in Getpp 
end

function getFixCGDamage(effect)
  local val = effect.effect[1]
  if effect.effect_type == ConfigBuffType.CDAMAGE_A then
    if GetSign(val) then
      return ObjPP.CDAMAGE_UP
    else
      return ObjPP.CDAMAGE_DOWN
    end
  elseif effect.effect_type == ConfigBuffType.GDAMAGE_A then
    if GetSign(val) then
      return ObjPP.GDAMAGE_DOWN
    else
      return ObjPP.GDAMAGE_UP
    end
  end
  return nil
end

function Unit:IsDamageDeadly(delta) -- Pretty easy, checks if the fs is already dead and then if the damage taken would kill them. Returns true/false
  return 0 < self:GetCurrentHp() and 0 >= self:GetCurrentHp() + delta
end

function Unit:GetATK() -- bullshit attack formula my beloved <3
  local threshold = 2000
  local atk = math.max(0, self:Getp(ObjP.ATTACK) * (1 + self:Getpp(ObjPP.ATTACK_A)) + self:Getpp(ObjPP.ATTACK_B))
  if threshold >= atk then
    return atk
  else -- this is what makes attack technically scale exponentially off of attack. Any atk above 2000 gets adjusted
    return threshold + (atk - threshold) ^ 1.5 * 0.01
  end
end

function Unit:GetSkillDamage(target, multiplier, flat) -- i don't like you very much
  deltaLevel = self:GetObjectLevel() - target:GetObjectLevel()
  local damage = (self:GetATK() * multiplier + flat) * (1 + self:Getpp(ObjPP.SKILL_DOWN) + self:Getpp(ObjPP.SKILL_UP))
  local fix = 1
  if BattleObjectFeature.MELEE == target:GetOFeature() then 
    fix = 1.2
  elseif BattleObjectFeature.REMOTE == target:GetOFeature() then
    fix = 0.9
  end
  damage = damage * fix
  damage = damage * (1 + math.max(0, self:Getpp(ObjPP.CAUSE_DAMAGE_SKILL) + self:Getpp(ObjPP.CAUSE_DAMAGE_PHYSICAL)))
  damage = self:GetFixedDamageByLevelRolling(damage, deltaLevel)
  return damage
end

function Unit:GetAttackDamage(attacker, target, externalDamageParameter) -- i like you less </3
  attacker:Changepp(ObjPP.ATTACK_B,externalDamageParameter.atk)
  local deltaLevel = 0
  local deltaLevelReverse = 0
  deltaLevel = attacker:GetObjectLevel() - target:GetObjectLevel()
  deltaLevelReverse = target:GetObjectLevel() - attacker:GetObjectLevel()
  local damage = attacker:GetATK() * (1 + attacker:Getpp(ObjPP.CDAMAGE_DOWN)) * (1 + attacker:Getpp(ObjPP.CDAMAGE_UP)) * (1 - target:GetFixedDamageReduceByLevelRolling(deltaLevelReverse)) * (1 - target:Getpp(ObjPP.GDAMAGE_UP)) * (1 - target:Getpp(ObjPP.GDAMAGE_DOWN))
  local fix = 1
  if BattleObjectFeature.MELEE == attacker:GetOFeature() and BattleObjectFeature.REMOTE == target:GetOFeature() then
    fix = 1.05
  elseif BattleObjectFeature.REMOTE == attacker:GetOFeature() and BattleObjectFeature.MELEE == target:GetOFeature() then
    fix = 0.9
  end
  if externalDamageParameter.isCritical then
    damage = damage * attacker:GetCriticalDamage()
  end
  damage = damage * fix
  damage = damage * (1 + math.max(0, self:Getpp(ObjPP.CAUSE_DAMAGE_ATTACK) + self:Getpp(ObjPP.CAUSE_DAMAGE_PHYSICAL)))
  damage = attacker:GetFixedDamageByLevelRolling(damage, deltaLevel)
  damage = damage + externalDamageParameter.ultimateDamage
  attacker:Changepp(ObjPP.ATTACK_B,-externalDamageParameter.atk)
  return damage
end

function Unit:GetObjectLevel()
  return self.op.level
end

function Unit:GetOFeature()
  return self.op.feature
end

--please triple check you have this right
--[[Comments on External Damage Parameters
    External damage parameters seems to include a few things. however A) I cannot for the life of me find out what 90% of those things are and
    B) they seem to have (virtually) no effect anyways, so I cut them to make the function work
    The exception here is the isCritical variable, which i still need. I figure it'll be helpful to keep etp in for that at least and 
    add things to it later if need be]]

function Unit:GetDFN() -- should already be fine?
  return math.max(0, self:Getp(ObjP.DEFENCE) * (1 + self:Getpp(ObjPP.DEFENCE_A)) + self:Getpp(ObjPP.DEFENCE_B))
end

function Unit:GetFixedDFNByLevelRolling(deltaLevel)
  if deltaLevel < 0 then
    return math.floor(self:GetDFN() * (1 - math.floor(math.abs(deltaLevel) / 10.1) * 0.1) + 0.5)
  elseif deltaLevel > 0 then
    return math.floor(self:GetDFN() * (1.1 + math.sqrt(deltaLevel) / 4.1 * 0.1) + 0.5)
  else
    return self:GetDFN()
  end
end

function Unit:GetDamageReduce()
  return math.floor((self:GetDFN() / (1.7411 * self:GetDFN() + 300) + self:GetDFN() ^ 0.5 * 0.002) * 100) * 0.01
end

function Unit:GetFixedDamageReduceByLevelRolling(deltaLevel)
  local fixedDFN = self:GetFixedDFNByLevelRolling(deltaLevel)
  return fixedDFN / (fixedDFN + 280) -- corrected, this was straight up wrong and caused some issues (¬_¬")
end

function Unit:GetSkillHeal(value, target)
  local heal = value * (1 + self:Getpp(ObjPP.CAUSE_HEAL_SKILL) + self:Getpp(ObjPP.CAUSE_HEAL_ALL))
  return heal
end

function Unit:GetFixedDamageByLevelRolling(damage, deltaLevel)
  if deltaLevel < 0 then
    return math.floor(damage * (1 - math.floor(math.abs(deltaLevel) / 10.1) * 0.1) + 0.5)
  elseif deltaLevel > 0 then
    return math.floor(damage * (1 + deltaLevel * 0.03 + math.sqrt(deltaLevel + 1) / 5.1 * 0.1) + 0.5)
  else
    return damage
  end
end

function Unit:GetDps() -- this is only used for calculating power
  local atk = self:GetATK()
  return atk * (1 + self:GetCriticalRate() * 0.01 * (self:GetCriticalDamage() - 1)) * self:GetAttackRatePerSecond()
end

function Unit:GetTough() -- also only used for calculating power
  return self:GetCurrentHp() / (1 - self:GetDamageReduce())
end

function Unit:GetAttackRatePerSecond()
  return 1 / self:GetATKCounter()
end

function Unit:GetATKCounter()
  return 2.903784 * (1 - (self:GetATKRate() - 255) * 3.515E-5)
end

function Unit:GetCriticalRate()
  local threshold = 17222
  if threshold >= self:GetCRRate() then
    return math.min(100, (round(((self:GetCRRate() - 255) * 0.0233 + 4.6115) * 0.00125 * 10000) * 1.0E-4 + 0.1) * 100)
  else
    return math.min(100, (0.4999 + (self:GetCRRate() - threshold) ^ 0.3333333333333333 * 0.01 + 0.1) * 100)
  end
end
function Unit:GetCriticalDamage()
  return round(((self:GetCRDamage() - 855) * 0.0153 + 754.6965) * 0.002 * 10000) * 1.0E-4
end
function Unit:GetHealCriticalDamage()
  return round(((self:GetCRDamage() - 246) * 0.027 + 751.4534) / 500 * 10000) * 1.0E-4
end
function Unit:GetBattlePoint()
  return math.ceil(round(self:GetDps() * self:GetTough() / 500) * 100) + 0
end
function Unit:GetCRRate()
  return math.max(0, self:Getp(ObjP.CRITRATE) * (1 + self:Getpp(ObjPP.CR_RATE_A)) + self:Getpp(ObjPP.CR_RATE_B))
end
function Unit:GetCRDamage()
  return math.max(0, self:Getp(ObjP.CRITDAMAGE) * (1 + self:Getpp(ObjPP.CR_DAMAGE_A)) + self:Getpp(ObjPP.CR_DAMAGE_B))
end
function Unit:GetATKRate()
  return math.max(0, math.min(25750, self:Getp(ObjP.ATTACKRATE) * (1 + self:Getpp(ObjPP.ATK_RATE_A)) + self:Getpp(ObjPP.ATK_RATE_B)))
end
function Unit:GetCurrentHp()
  return self:Getp(ObjP.HP)
end
function Unit:GetOriginalHp()
  return self:Getp(ObjP.HP, true) * (1 + self:Getpp(ObjPP.OHP_A)) + self:Getpp(ObjPP.OHP_B)
end
function Unit:GetMaxEnergy()
  return self:Getp(ObjP.ENERGY, true)
end

function Unit:FixFinalGetDamage(damage, damageType)
  local result = damage
  if DamageType.ATTACK_PHYSICAL == damageType then
    result = result * math.max(0, 1 + math.min(0, self:Getpp(ObjPP.GET_DAMAGE_ATTACK)))
  elseif DamageType.SKILL_PHYSICAL == damageType then
    result = result * math.max(0, 1 + math.min(0, self:Getpp(ObjPP.GET_DAMAGE_SKILL)))
  end
  result = result * math.max(0, 1 + math.min(0, self:Getpp(ObjPP.GET_DAMAGE_PHYSICAL)))
  return result
end

function Unit:GetHealing()
  local atk = self:GetATK()
  return math.floor((atk ^ 0.5 + (atk + 36) ^ 0.7 + (45 + 0.23 * atk)) * 0.4)
end
function Unit:GetFixedHealing(externalDamageParameter)
  local heal = self:GetHealing()
  heal = heal * (1 + self:Getpp(ObjPP.CAUSE_HEAL_ATTACK) + self:Getpp(ObjPP.CAUSE_HEAL_ALL))
  if externalDamageParameter.isCritical then
    heal = heal * self:GetHealCriticalDamage()
  end
  return heal
end

function Unit:FixFinalGetHeal(heal, damageType)
  local result = heal
  local pp = 0
  if DamageType.ATTACK_HEAL == damageType then
    pp = self:Getpp(ObjPP.GET_HEAL_ATTACK)
  elseif DamageType.SKILL_HEAL == damageType then
    pp = self:Getpp(ObjPP.GET_HEAL_SKILL)
  end
  result = result * math.max(0, 1 + pp + self:Getpp(ObjPP.GET_HEAL_ALL))
  return result
end

function Unit:Setp(p, v, o)
  if o then
    self.op[p] = v
  else
    self.p[p] = v
  end
end

function Unit:UpdateCurHpPercent()
  self.p.hpPercent = math.ceil(self:GetCurrentHp() / self:GetOriginalHp() * 100000) * 1.0E-5
end

function Unit:GetCurHpPercent()
  self:UpdateCurHpPercent()
  return self.p.hpPercent
end

function Unit:SetCurHpPercent(percent)
  self.p.hpPercent = percent
  self:Setp(ObjP.HP, self:GetOriginalHp() * self.p.hpPercent)
end

--[[The Stuff that i don't know enough to use. I honestly just don't know what these ones do (｡ᵕ ◞ _◟)
function ObjProp:GetCurrentP(propertyType)
  if ObjP.ATTACK == propertyType then
    return self:GetATK()
  elseif ObjP.DEFENCE == propertyType then
    return self:GetDFN()
  elseif ObjP.HP == propertyType then
    return self:GetCurrentHp()
  elseif ObjP.CRITRATE == propertyType then
    return self:GetCRRate()
  elseif ObjP.CRITDAMAGE == propertyType then
    return self:GetCRDamage()
  elseif ObjP.ATTACKRATE == propertyType then
    return self:GetATKRate()
  end
  return nil
end
function ObjProp:GetOriginalP(propertyType)
  if ObjP.HP == propertyType then
    return self:GetOriginalHp()
  else
    return self:Getp(true)
  end
end
function ObjProp:GetCurrentAttackRange()
  return self.p.attackRange
end
function ObjProp:GetCurrentMoveSpeed()
  return self.p.walkSpeed
end
function ObjProp:GetAMPByTargetMonsterType(monsterType)
  local ppConfig = {
    [ConfigMonsterType.CARD] = ObjPP.CDP_2_CARD,
    [ConfigMonsterType.NORMAL] = ObjPP.CDP_2_MONSER,
    [ConfigMonsterType.ELITE] = ObjPP.CDP_2_ELITE,
    [ConfigMonsterType.BOSS] = ObjPP.CDP_2_BOSS,
    [ConfigMonsterType.CHEST] = ObjPP.CDP_2_CHEST
  }
  local pp = ppConfig[monsterType]
  if nil ~= pp then
    return self:Getpp(pp) or 0
  else
    return 0
  end
end
function Unit:GetDeltaHp()
  local curHp = self:GetCurrentHp()
  local fixedTotalHp = 0
  if nil ~= self.singleAddition then
    if nil ~= self.singleAddition.pvalue and 0 < self.singleAddition.pvalue[ObjP.HP] then
      fixedTotalHp = self.singleAddition.pvalue[ObjP.HP]
    elseif nil ~= self.singleAddition.pattr and 0 < self.singleAddition.pattr[ObjP.HP] then
      fixedTotalHp = self:Getp(ObjP.HP, true) * self.singleAddition.pattr[ObjP.HP]
    end
  else
    fixedTotalHp = checknumber(self:Getp(ObjP.HP, true))
  end
  return math.ceil(fixedTotalHp - math.max(0, curHp))
end
]]
--end of ObjProperty functions
return Unit
