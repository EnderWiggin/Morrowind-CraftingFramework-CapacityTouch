-- enchant capacity touch: increases enchant capacity of Weapons and Armor based on your Enchant skill. If Artisan's touch enabled - quality mult also affects enchant capacity, but soul gem cost doubles.

if world then return end
if not registerTouch then return end

local ui = require('openmw.ui')
local l10n = core.l10n('TPA_CF_CapacityTouch')
local v2 = util.vector2

local touchID = "capacity"
local touchModId = "touch:" .. touchID

------------------------------ helpers ------------------------------

-- sin ease in-out from x1 to ~x2.5 for skill <95, after that sqrt(x/100) (shifted up to match with end of previous curve) 
-- x1.5 at ~40 skill, x2 at ~60 skill, x3 at 220 skill
local function enchantMultiplier()
    local skill = getModifiedSkill("enchant") or 0
    if skill < 95 then
        return 1.75 - 0.75 * (math.cos(math.pi * skill / 100.0));
    else
        return 1.5165 + math.sqrt(skill / 100.0);
    end
end

local function enchantMultiplierText()
   return "x" .. math.floor(100*enchantMultiplier())/100
end

local function ingredientGem(recipe)
    local level = recipe.level or 0
    if level <= 19 then
        return "Misc_SoulGem_Petty"
    elseif level <= 39 then
        return "Misc_SoulGem_Lesser"
    elseif level <= 59 then
        return "Misc_SoulGem_Common"
    elseif level <= 79 then
        return "Misc_SoulGem_Greater"
    else
        return "Misc_SoulGem_Grand"
    end
end

local function addIngredient(ctx, name, count)
    name = string.lower(name)
    local ingredients = ingredientsMutable(ctx)
    for _, i in ipairs(ingredients) do
        if i.id and string.lower(i.id) == name then
            i.count = i.count + count
            return
        end
    end
    table.insert(ingredients, { type = "Miscellaneous", id = name, count = count })
end

-- wraps text with 2/5 vertical and 4/5 horizontal padding
local function makeTextTooltip(text, description)
    local font_size = ui._getDefaultFontSize()
    return ui.content {
        { props = { size = v2(1, 1) } },
        {
            type = ui.TYPE.Flex,
            props = { horizontal = true },
            content = ui.content {
                { props = { size = v2(5, 2) } },
                {
                    type = ui.TYPE.Text,
                    props = {
                        text = text,
                        textSize = font_size,
                        textColor = TOOLTIP_FONT_COLOR,
                        textAlignH = ui.ALIGNMENT.Center,
                        multiline = true,
                        autoSize = true,
                    },
                },
                { props = { size = v2(5, 2) } },
            },
        },
        { props = { size = v2(2, 5) } },
        {
            type = ui.TYPE.Flex,
            props = { horizontal = true },
            content = ui.content {
                { props = { size = v2(5, 2) } },
                {
                    type = ui.TYPE.Text,
                    props = {
                        text = description,
                        textSize = font_size - 2,
                        textColor = morrowindGold,
                        textAlignH = ui.ALIGNMENT.Center,
                        autoSize = true,
                        multiline = true,
                        wordWrap = true,
                    },
                },
                { props = { size = v2(5, 2) } },
            },
        },
        { props = { size = v2(2, 2) } },
    }
end

------------------------------ touch registration ------------------------------

registerTouch {
    id = touchID,
    label = "Add Capacity",
    priority = -1,
    gate = function(recipe)
        return (recipe.type == "Weapon" or recipe.type == "Armor") and not protectedRecordIds[recipe.id]
    end,
}

registerIngredientsModifier {
    id = touchModId,
    global = true,
    priority = -1,
    func = function(recipe, ctx)
        if not (ctx.touches and ctx.touches[touchID]) then return end
        -- double the cost if artisan enabled
        addIngredient(ctx, ingredientGem(recipe), ctx.touches.artisan and 2 or 1)
    end,
}

registerStatsModifier {
    id = touchModId,
    global = true,
    priority = -1,
    func = function(recipe, ctx)
        if not (ctx.touches and ctx.touches[touchID]) then return end
        if ctx.recordType == "Weapon" or ctx.recordType == "Armor" then
            local m = ctx.modified or {}
            local capacity = m.enchantCapacity or ctx.base.enchantCapacity or ctx.record.enchantCapacity
            if not capacity then return end

            local qualityMult = ctx.touches.artisan and ctx.qualityMult or 1
            local enchantMult = enchantMultiplier()

            m.enchantCapacity = capacity * qualityMult * enchantMult;
            ctx.modified = m;
        end
    end,
}
local supportedInfoTypes = { weapon = true, armor = true }

registerTooltipModifier{
    id = touchModId,
    priority = 100,
    global = true,
    func = function(recipe, ctx)
        if not recipe or not (activeTouches and activeTouches[touchID]) then return end
        if not (ctx.info and supportedInfoTypes[ctx.info.type]) then return end
        if recipe.preserveRecordId then return end
        if ctx.info.enchantment then return end
        
        local row = {
            type = ui.TYPE.Flex,
            props = {
                horizontal = true,
                autoSize = true,
                anchor = v2(0.5, 0),
                relativePosition = v2(0.5, 0),
                size = v2(0, S_FONT_SIZE)
            },
            content = ui.content{
                {
                    type = ui.TYPE.Image,
                    props = {
                        resource = getTexture("textures\\CraftingFramework\\menu_icon_magic.dds"),
                        size = v2(S_FONT_SIZE, S_FONT_SIZE),
                        relativePosition = v2(0, 0.5),
                        anchor = v2(0,0.5),
                        alpha = 0.8,
                    },
                },
                { props = { size = v2(2, 2) } },
                {
                    type = ui.TYPE.Text,
                    props = {
                        text = l10n("EnchantCapacity") .. " " .. enchantMultiplierText(),
                        textSize = S_FONT_SIZE-2,
                        relativePosition = v2(0, 0.52),
                        anchor = v2(0,0.5),
                        textColor = morrowindBlue3,
                        autoSize = true,
                    },
                },
            },
        }
        ctx.flex.content:add(row)
    end,
}

------------------------------ button ------------------------------

local capacityButton

local function applyButtonState()
    if not capacityButton then return end
    if activeTouches[touchID] then
        capacityButton.content.background.props.color = morrowindGold
        capacityButton.content.clickbox.userData.customColor = morrowindGold
    else
        capacityButton.content.background.props.color = util.color.rgb(0, 0, 0)
        capacityButton.content.clickbox.userData.customColor = nil
    end
end

registerWindowBuilder {
    id = touchModId,
    priority = 10,
    func = function(ctx)
        capacityButton = makeIconButton(
                "textures/CraftingFramework/capacity.png",
                v2(S_FONT_SIZE * 1, S_FONT_SIZE * 1),
                function()
                    toggleTouch(touchID)
                end
        )
        applyButtonState()
        ctx.topBarButtonFlex.content:add(capacityButton)
        addTooltip(capacityButton.content.clickbox, makeTextTooltip(l10n("ButtonTipTitle") .. " " .. enchantMultiplierText(), l10n("ButtonTipBody")))
    end,
}

onTouchToggled(function(data)
    if data.id == touchID then applyButtonState() end
end)