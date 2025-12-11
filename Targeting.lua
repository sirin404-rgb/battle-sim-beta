function ApplyTargetRule (source, units, target_type)
    local rule = TargetConfig[target_type]
    if not rule then return {} end

    local result = {}
    for _, unit in pairs(units) do -- check alive
        if rule.alive == nil or unit.isAlive == rule.alive then
            local sameCamp = unit.op.camp == source.op.camp -- check camp
            if rule.camp == nil or rule.camp == sameCamp then
                -- check class
                if rule.class == nil or unit.op.career == rule.class then
                    table.insert(result, unit)
                end
            end
        end
    end
    return result
end

function ApplySortRule (source, units, SortRule)
    if SortRule == SeekSortRule.S_NONE then
        local sourceindex = FindIndex(units, source)
        if sourceindex then  
            table.remove(units, sourceindex)
        end
        -- Fisher-Yates shuffle
        for i = #units, 2, -1 do
            local j = math.random(i)
            units[i], units[j] = units[j], units[i]
        end
        return units
    end

    local config = SortConfig[SortRule]
    if not config then return units end

    table.sort(units, function(a, b)
        local valA = config.method(a)
        local valB = config.method(b)
        if config.asc then
            return valA < valB
        else
            return valA > valB
        end
    end)

    return units
end

function ApplyTargetNumber (units, target_number)
    local selected = {}
    local count = math.min (#units, target_number)
    for i = 1, count do 
        selected[i] = units[i]
    end
    return selected
end

function getBasicAttackTarget(source, entities)
    if source:GetOFeature() == BattleObjectFeature.HEALER then
        local options = ApplyTargetRule(source, entities, ConfigSeekTargetRule.T_OBJ_FRIEND)
        if #options == 1 and options[1] == source then
            options = ApplyTargetRule(source, entities, ConfigSeekTargetRule.T_OBJ_ENEMY)
            options = ApplySortRule(source, options, SeekSortRule.S_HATE_MAX)
            return options[1]
        end
        options = ApplySortRule(source, options, SeekSortRule.S_HATE_MAX)
        return options[1]
    else 
        local options = ApplyTargetRule(source, entities, ConfigSeekTargetRule.T_OBJ_ENEMY)
        options = ApplySortRule(source, options, SeekSortRule.S_HATE_MAX)
        return options[1]
    end
end

function FindIndex(t, value)
    for i, v in ipairs(t) do
        if v == value then
            return i
        end
    end
    return nil
end