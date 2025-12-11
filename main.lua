local love = require "love"
local json = require "json"
local UnitProp = require "UnitProp"
local EffectProp = require "EffectProp"
local Targeting = require "Targeting"
local BattleConstants = require "BattleConstants"
local Battle = require "Battle"

-- extra display functions 
function chainprint(args,x)
    for i = 1, #args do
        love.graphics.print(args[i],x,15*(i-1))
    end
end
function twocolumnchainprint(args,x,y)
    local i = 0
    for name, val in pairs (args) do
        i = i + 1
        love.graphics.print (name .. ": " .. val, x,y + 15*(i-1))
    end
end

-- math functions 
function round(num)
    if num >= 0 then
        return math.floor(num + 0.5)
    else
        return math.ceil(num - 0.5)
    end
end

function GetSign(num)
  return num > 0
end -- return true if positive, false if negative

function ShallowCopy(tbl)
    local copy = {}
    for k, v in pairs(tbl) do
        copy[k] = v
    end
    return copy
end

-- json functions
function loadJSON(filename)
    local content, size = love.filesystem.read(filename)
    if not content then
        error("Could not read file: " .. filename)
    end
    return json.decode(content)
end

function StringToTable(str)
    local tbl = {}
    if not str or str == "" then return tbl end

    -- Remove the surrounding brackets and single quotes
    local cleaned = str:gsub("^%[", ""):gsub("%]$", ""):gsub("'", "")

    -- Split by comma
    for value in cleaned:gmatch("([^,]+)") do
        value = value:gsub("^%s+", ""):gsub("%s+$", "")  -- trim spaces
        local num = tonumber(value)
        if num then
            table.insert(tbl, num)  -- number
        else
            table.insert(tbl, value)  -- string
        end
    end
    return tbl
end


local dn_skills = loadJSON("ff_jsons/dn_skills.json")

function selectEffectByID(file, id, source)
    local count = 1
    local id = tostring(id)
    local ef = {}
    for _, effect in pairs (file) do 
        if effect.id == id then
            ef = Effect.New(effect, count, source)
            source.sourceEffects[ef.id] = ef 
            count = count + 1
        end
    end
end

printstuff = {}
fs1 = {
    ["id"] = 1,
    ["attack"] = 1000,
    ["defence"]= 100,
    ["hp"] = 100,
    ["critRate"] = 1000,
    ["critDamage"] = 10000,
    ["attackRate"] = 10000,
    ["level"] = 80,
    ["feature"] = BattleObjectFeature.MELEE,
    ["camp"] = ConfigCampType.FRIEND
}
fs2 = {
    ["id"] = 2,
    ["attack"] = 100,
    ["defence"]= 100,
    ["hp"] = 100000,
    ["critRate"] = 1000,
    ["critDamage"] = 10000,
    ["attackRate"] = 10000,
    ["level"] = 80,
    ["feature"] = BattleObjectFeature.MELEE,
    ["camp"] = ConfigCampType.ENEMY
}
fs3 = {
    ["id"] = 3,
    ["attack"] = 100,
    ["defence"]= 200,
    ["hp"] = 100000,
    ["critRate"] = 1000,
    ["critDamage"] = 10000,
    ["attackRate"] = 10000,
    ["level"] = 80,
    ["feature"] = BattleObjectFeature.MELEE,
    ["camp"] = ConfigCampType.ENEMY
}
fs4 = {
    ["id"] = 1,
    ["attack"] = 10,
    ["defence"]= 100,
    ["hp"] = 100,
    ["critRate"] = 1000,
    ["critDamage"] = 10000,
    ["attackRate"] = 10000,
    ["level"] = 80,
    ["feature"] = BattleObjectFeature.REMOTE,
    ["camp"] = ConfigCampType.FRIEND
}
Units = {
    Unit.New(fs1),
    Unit.New(fs2),
    Unit.New(fs3),
    Unit.New(fs4)
}

function getTime() 
    return GameTime
end

function love.load()
    GameTime = 0
    for _,unit in pairs (Units) do
        unit:InitObjPP()
    end
    PPs = {{},{},{},{}}
    selectEffectByID(dn_skills, 10779, Units[4])
    selectEffectByID(dn_skills, 2012437, Units[4])
end

function love.update(dt)
    GameTime = GameTime + 1*dt
    for _,unit in pairs (Units) do
        unit:UpdateEffect(getTime())
    end
    for i = 1, 4 do 
        for _, pp in pairs (ObjPP) do 
            if Units[i]:Getpp(pp) ~= 0 then
                PPs[i][ObjPP_Reverse[pp]] = Units[i]:Getpp(pp)
            end
        end
    end
    AddEffect(Units[1],7,1,"Aura",ConfigBuffType.ATTACK_A, {.1},1,1,{Units[1],Units[2],Units[3]},{ConfigBuffType.DISPEL_BUFF,ConfigBuffType.DISPEL_BUFF})
    AddEffect(Units[1],7,2,"Aura",ConfigBuffType.CDAMAGE_A, {.1},1,1,{Units[1],Units[2],Units[3]},{ConfigBuffType.DISPEL_BUFF,ConfigBuffType.DISPEL_BUFF})
    Units[4].sourceEffects[20124372]:AddEffect()
end

function love.keypressed(key)
    if key == "1" then
        Units[1]:BasicAttack(Units[2])
    end
    if key == "2" then 
        AddEffect(Units[1], 1, 1, "Basic", ConfigBuffType.ATK_ISD_CHARGE, {10}, 1, 10, {Units[1]}, {})
    end
    if key == "3" then
        AddEffect(Units[1], 2, 1, "Basic", ConfigBuffType.CDAMAGE_A, {.5}, 1, 3, {Units[1]}, {})
    end
    if key == "4" then
        AddEffect(Units[1], 3, 1, "Basic", ConfigBuffType.ATTACK_A, {.2}, .3, 10, {Units[1]}, {ConfigBuffType.DISPEL_BUFF,})
        AddEffect(Units[1], 3, 2, "Basic", ConfigBuffType.ATTACK_A, {.3}, 1, 10, {Units[1]}, {ConfigBuffType.DISPEL_BUFF,})
    end
    if key == "5" then
        AddEffect(Units[1], 4, 1, "Basic", ConfigBuffType.ISD, {1.5,125}, 1, 3, {Units[2],Units[3]}, {})
    end
    if key == "6" then
        AddEffect(Units[1], 5, 1, "Basic", ConfigBuffType.GET_DAMAGE_SKILL, {.15}, 1, 10, {Units[2]}, {})
    end
    if key == "7" then
        AddEffect(Units[1], 6, 1,"Aura", ConfigBuffType.GET_DAMAGE_SKILL, {-.1}, 1, 10, {Units[3]}, {})
    end
    if key == "8" then
            Units[4].sourceEffects[107792]:AddEffect()
    end
    if key == "r" then 
        for _, unit in pairs (Units) do
            unit.p[ObjP.HP] = unit:GetOriginalHp()
        end
    end
end

function isnil(v)
    if v == nil then
        return "yup"
    else 
        return "nope"
    end
end

function love.draw()
    chainprint({math.floor(getTime()),Units[1]:Getpp(ObjPP.ATTACK_A), Units[1]:GetBattlePoint()},0)
    chainprint({Units[2]:GetOriginalHp(),Units[2]:GetCurrentHp(),Units[2]:GetCurHpPercent(),Units[2]:GetOriginalHp()-Units[2]:GetCurrentHp()},100)
    chainprint({Units[3]:GetOriginalHp(),Units[3]:GetCurrentHp(),Units[3]:GetCurHpPercent(),Units[3]:GetOriginalHp()-Units[3]:GetCurrentHp()},200)
    chainprint({
    "1 - Basic attack", 
    "2 - Unit 1 next 10 basic attacks gain +10 ATK", 
    "3 - Unit 1 ATK +50%; 3 sec", 
    "4 - Unit 1 ATK +30%; 10 sec; 30% chance for +20% ATK", 
    "5 - 150% Unit 1 ATK + 125, 90% execute; Units 2 + 3",
    "6 - Heal Unit 2 15% of lost HP",
    "7 - Unit 3 -10% skill damage taken; 10 sec"},300)
    for i = 1,4 do
        twocolumnchainprint(PPs[i],0 + 200 * (i-1),200)
    end
    if printstuff then 
        chainprint(printstuff,100)
    end
    temp = Units[4].sourceEffects[20124372]:GetTriggerTargets()
    love.graphics.print("first target: " .. Units[4].sourceEffects[20124372].effect[1],400,400)
    if Units[1].tempSourceEffects[20124372] then
        --love.graphics.print(Units[1].tempSourceEffects[20124372].damage,400,415)
    end
end
--20124372
