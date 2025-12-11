function AddEffect(Source, PRIMARYID, SUBID, Type_Desc, Effect_Type, Effect, Effect_Rate, Effect_Time, Targets, immuneDispel, damageType)
    for _, trg in ipairs(Targets) do 
        if math.random() <= Effect_Rate and not trg:isImmune(Effect_Type) then
            local ef = {
                ["source"] = Source,
                ["primary_id"] = PRIMARYID,
                ["sub_id"] = SUBID,
                ["id"] = tonumber(PRIMARYID .. SUBID),
                ["type_desc"] = Type_Desc,
                ["effect_type"] = Effect_Type,
                ["effect"] = Effect,
                ["effect_time"] = Effect_Time,
                ["immuneDispel"] = immuneDispel,
                ["endtime"] = getTime() + Effect_Time,
                ["count"] = Effect_Time,
                ["nexttick"] = getTime() + 1,
                ["damageType"] = damageType or DamageType.SKILL_PHYSICAL
            }
            if ef.effect_type == ConfigBuffType.CHANGE_PP then
                ef.effect_type = ConfigBuffType[ef.effect[1]]
                ef.effect[1] = ef.effect[2]
            end
            if ef.source then
                ef.damage = ef.source:GetDamage(trg,ef)
            end
            if ef.source then 
                ef.healing = ef.source:GetHeal(trg,ef)
            end
            if trg.effects[ef.id] then
                trg.effects[ef.id].endtime = getTime() + ef.effect_time
            else
                trg.effects[ef.id] = ef
            end
        end
    end
end
