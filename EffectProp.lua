Effect = {}
Effect.__index = Effect
function Effect.New(effect, count, source)
    local self = setmetatable({}, Effect)
    local data = ShallowCopy(effect)
    for k, v in pairs(data) do
        if v == "" then
            self[k] = nil
            goto continue
        end
        local asnumber = tonumber(v)
        if asnumber then
            self[k] = asnumber
            goto continue
        end
        local converted = ConfigBuffType[v]
        if converted then
            self[k] = converted
            goto continue
        end
        local converted = ConfigSeekTargetRule[v]
        if converted then
            self[k] = converted
            goto continue
        end
        local converted = SeekSortRule[v]
        if converted then
            self[k] = converted
            goto continue
        end
        local converted = ConfigObjectTriggerConditionType[v]
        if converted then
            self[k] = converted
            goto continue
        end
        local converted = ConfigMeetConditionType[v]
        if converted then
            self[k] = converted
            goto continue
        end
        --[[local converted = ConfigObjectTriggerActionType[v]
        if converted then
            self[k] = converted
            goto continue
        end]]
        --[[local convertval = convertConfig(v) 
        if convertval ~= nil then
            self[k] = convertval
            goto continue
        end]]
        self[k] = v
        ::continue::
    end
    self.effect_time = self.effect_time or 0
    self.source = source
    self.primary_id = tonumber(self.id)
    self.sub_id = count
    self.id = tonumber(self.primary_id .. self.sub_id)
    if self.triggerActionType then
        local str = self.triggerActionType
        if str:find("%[") then -- check if this is actually a table of trigger action types
            local tbl = StringToTable(str)
            for i, v in pairs(tbl) do 
                tbl[i] = ConfigObjectTriggerActionType[v]
            end
            self.triggerActionType = tbl
        else -- if it's just a single trigger action
            self.triggerActionType = {
                ConfigObjectTriggerActionType[str]
            }
        end
    end
    self.effect = StringToTable(self.effect)
    self.immuneDispel = StringToTable(self.immuneDispel)
    self.trigger_type = ParseTriggerType(self.trigger_type)
    if self.effect_type == ConfigBuffType.CHANGE_PP then
        self.effect_type = ConfigBuffType[self.effect[1]]
        self.effect[1] = self.effect[2]
    end
    self.is_triggered_effect = self.triggerActionType ~= nil
    self.to_tempeffects = self.is_triggered_effect
    self.damageType = DamageType.SKILL_PHYSICAL
    return self
end
function Effect.BasicAttack(source)
    local self = setmetatable({}, Effect)
    self.source = source
    self.id = source.id
    self.effect_type = ConfigBuffType.BASE
    self.effect = {}
    return self
end
function Effect:Clone()
    local ef = ShallowCopy(self)
    setmetatable(ef, Effect)
    return ef
end
function Effect:AddEffect()
    local BasicTargets, TriggerTargets, ConditionTargets = self:GetAllTargets()
    local Targets = BasicTargets
    if not self:CheckConditions(ConditionTargets) then
        return
    end
    if math.random() >= self.effect_rate then
        return
    end
    if self.is_triggered_effect and self.to_tempeffects then -- check if this needs to go into the monitored effects
        for _, trg in pairs (Targets) do
            local ef = self:Clone()
            ef.to_tempeffects = false -- remove flag saying to put this in temporary source effects
            if not trg:isImmune(ef.effect_type) then
                ef.source = trg
                ef.damage = ef.source:GetDamage(trg,ef)
                ef.healing = ef.source:GetHeal(trg,ef)
                ef.endtime = getTime() + ef.effect_time
                ef.nexttick = getTime() + 1
                if trg.tempSourceEffects[ef.id] then
                    trg.tempSourceEffects[ef.id].endtime = getTime() + ef.effect_time
                else
                    trg.tempSourceEffects[ef.id] = ef
                end
            end
        end
    elseif self.is_triggered_effect and not self.to_tempeffects then
        Targets = TriggerTargets
        for _, trg in pairs (Targets) do
            local ef = self:Clone()
            if not trg:isImmune(ef.effect_type) then
                ef.damage = ef.source:GetDamage(trg,ef)
                ef.healing = ef.source:GetHeal(trg,ef)
                ef.endtime = getTime() + ef.effect_time
                ef.nexttick = getTime() + 1
                if trg.effects[ef.id] then
                    trg.effects[ef.id].endtime = getTime() + ef.effect_time
                else
                    trg.effects[ef.id] = ef
                end
            end
        end
    else -- if this isn't a triggered effect, apply as normal
        for _, trg in pairs (Targets) do
            local ef = self:Clone()
            if not trg:isImmune(ef.effect_type) then
                ef.damage = ef.source:GetDamage(trg,ef)
                ef.healing = ef.source:GetHeal(trg,ef)
                ef.endtime = getTime() + ef.effect_time
                ef.nexttick = getTime() + 1
                if trg.effects[ef.id] then
                    trg.effects[ef.id].endtime = getTime() + ef.effect_time
                else
                    trg.effects[ef.id] = ef
                end
            end
        end
    end
end
function Effect:CheckConditions(targets)
    -- First, get all the condition targets
    local ConditionTargets = targets
    
    -- If there are no condition targets, then there's no condition
    if #ConditionTargets == 0 then
        return true
    end

    -- Count how many targets meet the condition
    local meetCount = 0
    for _, trg in ipairs(ConditionTargets) do
        if self.triggerCondition == ConfigObjectTriggerConditionType.HP_LESS_THAN and trg:GetCurHpPercent() < self.triggerThreshold then
            meetCount = meetCount + 1
        elseif self.triggerCondition == ConfigObjectTriggerConditionType.HP_MORE_THAN and trg:GetCurHpPercent() > self.triggerThreshold then
            meetCount = meetCount + 1
        end
    end

    -- Decide if the overall condition is met based on triggerMeetType
    if self.triggerMeetType == ConfigMeetConditionType.ONE then
        return meetCount >= 1
    elseif self.triggerMeetType == ConfigMeetConditionType.ALL then
        return meetCount == #ConditionTargets
    else
        -- default fallback if meetType is invalid
        return false
    end
end

function Effect:AddBasicAttack(target, damage, healing)
    local ef = self:Clone()
    ef.damage = damage
    ef.healing = healing
    ef.endtime = getTime()
    target.effects[ef.id] = ef
end
function Effect:GetBasicTargets()
    local targets = {}
    targets = ApplyTargetRule(self.source, Units, self.target_type)
    targets = ApplySortRule(self.source, targets, self.target)
    targets = ApplyTargetNumber(targets, self.target_num)
    --return targets
    return targets
end
function Effect:GetTriggerTargets()
    local targets = {}
    if self.triggerActionType then
        targets = ApplyTargetRule(self.source, Units, self.triggerActionTargetType)
        targets = ApplySortRule(self.source, targets, self.triggerActionTargetSequence)
        targets = ApplyTargetNumber(targets, self.triggerActionTargetNum)
    end
    return targets
end
function Effect:GetConditionTargets()
    local targets = {}
    if self.triggerCondition then
        targets = ApplyTargetRule(self.source, Units, self.triggerConditionTargetType)
        targets = ApplySortRule(self.source, targets, self.triggerConditionTarget)
        targets = ApplyTargetNumber(targets, self.triggerConditionTargetNum)
    end
    return targets
end
function Effect:GetAllTargets()
    local BasicTargets = self:GetBasicTargets() -- used for applying the initial effect weather or not it's triggered
    local TriggerTargets = self:GetTriggerTargets() -- used only by the tracked unit to find who to give the actual effect to
    local ConditionTargets = self:GetConditionTargets()
    return BasicTargets, TriggerTargets, ConditionTargets
end

ConfigConverters = {
    ConfigBuffType,
    ConfigSeekTargetRule,
    SeekSortRule,
    ConfigObjectTriggerConditionType,
    ConfigMeetConditionType
}

function convertConfig (v) 
    for _, tbl in ipairs(ConfigConverters) do
        if tbl[v] then return tbl[v] end
    end
    return nil
end

function ParseTriggerType(str)
    if not str or str == "" then return {} end

    local tbl = {}
    -- remove braces and spaces
    local cleaned = str:gsub("^%{", ""):gsub("%}$", ""):gsub("'", ""):gsub("%s+", "")

    for pair in cleaned:gmatch("([^,]+)") do
        local key, value = pair:match("([^:]+):([^:]+)")
        if key and value then
            local num = tonumber(value)
            if num then value = num end
            tbl[key] = value
        end
    end

    return tbl
end
