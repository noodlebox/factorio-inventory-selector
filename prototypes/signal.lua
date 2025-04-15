local namespace = "inventory-selector-inventory"

-- Signals representing each inventory type for use in the selector GUI
-- NOTE: We don't use virtual signals because the signal selection GUI does not support filtering

local inventory_subgroup = {
    name = namespace,
    type = "item-subgroup",
    group = "logistics",
    order = "z[meta]-[inventory-selector]",
    hidden_in_factoriopedia = true,
}

local function sprites_for(inventory_type)
    return --[[{
        name = namespace .. "-" .. inventory_type,
        type = "virtual-signal",
        localised_name = {"inventory-selector-inventory-name." .. inventory_type},
        localised_description = {"inventory-selector-inventory-description." .. inventory_type},
        icons = { {
            icon = "__inventory-selector__/graphics/icons/inventory/tag-base.png",
            icon_size = 128,
            tint = { r = 0.9, g = 0.9, b = 0.9 },
        }, {
            icon = "__inventory-selector__/graphics/icons/inventory/tag-" .. inventory_type .. ".png",
            icon_size = 128,
        } },
        subgroup = namespace,
    },]]{
        name = namespace .. "-" .. inventory_type,
        type = "item",
        localised_name = {"inventory-selector-inventory-name." .. inventory_type},
        localised_description = {"inventory-selector-inventory-description." .. inventory_type},
        icons = { {
            icon = "__inventory-selector__/graphics/icons/inventory/tag-base.png",
            icon_size = 128,
            tint = { r = 0.9, g = 0.9, b = 0.9 },
        }, {
            icon = "__inventory-selector__/graphics/icons/inventory/tag-" .. inventory_type .. ".png",
            icon_size = 128,
        } },
        subgroup = namespace,
        stack_size = 1,
        flags = { "always-show", "not-stackable" }, -- want "only-in-cursor" and "spawnable" as well, but these flags force the filter menu to hide it
        weight = 0,
        send_to_orbit_mode = "not-sendable",
        auto_recycle = false,
    }, {
        type = "sprite",
        name = namespace .. "-" .. inventory_type,
        layers = { {
            filename = "__inventory-selector__/graphics/icons/inventory/tag-base.png",
            size = 128,
            scale = 0.5,
            flags = { "icon" },
            tint = { r = 0.9, g = 0.9, b = 0.9 },
        }, {
            filename = "__inventory-selector__/graphics/icons/inventory/tag-" .. inventory_type .. ".png",
            size = 128,
            scale = 0.5,
            flags = { "icon" },
        } },
    }, {
        type = "sprite",
        name = namespace .. "-" .. inventory_type .. "-hover",
        layers = { {
            filename = "__inventory-selector__/graphics/icons/inventory/tag-base.png",
            size = 128,
            scale = 0.5,
            flags = { "icon" },
            invert_colors = true,
        }, {
            filename = "__inventory-selector__/graphics/icons/inventory/tag-" .. inventory_type .. ".png",
            size = 128,
            scale = 0.5,
            flags = { "icon" },
            invert_colors = true,
        } },
    }, {
        type = "sprite",
        name = namespace .. "-" .. inventory_type .. "-active",
        layers = { {
            filename = "__inventory-selector__/graphics/icons/inventory/tag-base.png",
            size = 128,
            scale = 0.5,
            flags = { "icon" },
            tint = { r = 1.0, g = 1.0, b = 0.0 },
        }, {
            filename = "__inventory-selector__/graphics/icons/inventory/tag-" .. inventory_type .. ".png",
            size = 128,
            scale = 0.5,
            flags = { "icon" },
            tint = { r = 1.0, g = 0.8, b = 0.0 },
        } },
    }, {
        type = "sprite",
        name = namespace .. "-" .. inventory_type .. "-alt-gui",
        filename = "__inventory-selector__/graphics/icons/inventory/tag-" .. inventory_type .. ".png",
        size = 128,
        scale = 0.25,
        flags = { "gui-icon" },
        tint = { r = 1.0, g = 1.0, b = 0.0 },
        shift = { -0.25, -0.125 - 0.5 }, -- Offset north by half a tile
        rotate_shift = true,
    }
end

local none = {
    name = namespace .. "-none",
    type = "item",
    localised_name = {"inventory-selector-inventory-name.none"},
    localised_description = {"inventory-selector-inventory-description.none"},
    icons = { {
        icon = "__inventory-selector__/graphics/icons/inventory/inventory-none.png",
        icon_size = 128,
    } },
    subgroup = namespace,
    stack_size = 1,
    flags = { "always-show", "not-stackable" }, -- want "only-in-cursor" and "spawnable" as well, but these flags force the filter menu to hide it
    weight = 0,
    send_to_orbit_mode = "not-sendable",
    auto_recycle = false,
}

local signals = { none}
local sprites = {}
local all = { inventory_subgroup, none }

for _, inventory_type in ipairs({
    "ammo", "main", "trash", "waste", "fuel", "byproduct",
    "ingredient", "product", "module", "dump", "robot", "material", "rocket",
}) do
    local signal, icon, icon_hover, icon_active, icon_alt_gui = sprites_for(inventory_type)
    table.insert(signals, signal)
    table.insert(sprites, icon)
    table.insert(sprites, icon_hover)
    table.insert(sprites, icon_active)
    table.insert(sprites, icon_alt_gui)
    table.insert(all, signal)
    table.insert(all, icon)
    table.insert(all, icon_hover)
    table.insert(all, icon_active)
    table.insert(all, icon_alt_gui)
end

return {
    inventory_subgroup = inventory_subgroup,
    signals = signals,
    sprites = sprites,
    all = all,
}
