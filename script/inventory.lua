-- String keys for "unified" inventory types
---@alias inventory_type
---| '"none"' -- Used to represent none of the inventories of an entity
---| '"ammo"' -- Consumable ammunition used by guns and turrets
---| '"main"' -- Inert generic storage for items
---| '"trash"' -- Inventory for items to be automatically removed by logistic system
---| '"waste"' -- Output for items that are invalid for the entity due to spoilage or other reasons
---| '"fuel"' -- Input for items with energy value to be consumed to power the entity
---| '"byproduct"' -- Output for byproduct of consumed fuel items, aka burnt_result
---| '"ingredient"' -- Input for recipe ingredients
---| '"product"' -- Output for recipe products
---| '"module"' -- Inventory for modules to modify entity performance
---| '"dump"' -- Output for items removed from inputs following change in recipe
---| '"robot"' -- Inventory for robots in a roboport
---| '"material"' -- Inventory for repair packs or other material in a roboport
---| '"rocket"' -- Inventory for a rocket in a rocket silo

---@alias inventory_role
---| '"input"' -- Inventory for items consumed by the entity, expects items to be inserted
---| '"output"' -- Inventory for items produced by the entity, expects items to be removed
---| '"open"' -- Inventory for items that are generally accessible to inserters (== "input" or "output")
---| '"closed"' -- Inventory for items that are not generally accessible to inserters (== not "input" and not "output")

---@alias inventory_access_mode
---| '"input"' -- Inserting items into the inventory (matches "input" and "open")
---| '"output"' -- Removing items from the inventory (matches "output" and "open")
---| '"both"' -- Both inserting and removing items from the inventory (matches "open")
---| '"any"' -- Any access mode (matches "input", "output", "open", and "closed")

---@alias inventory_mapping table<inventory_type, { [1]:defines.inventory, [2]:inventory_role }>
-- unified inventory type names and their most common inventory indices
---@type inventory_mapping
local inventory_defaults = {
    ammo = { defines.inventory.turret_ammo, "open" }, -- 1

    main = { defines.inventory.chest, "open" }, -- 1
    trash = { defines.inventory.logistic_container_trash, "closed" }, -- 2

    waste = { defines.inventory.assembling_machine_trash, "output" }, -- 8
    fuel = { defines.inventory.fuel, "open" }, -- 1
    byproduct = { defines.inventory.burnt_result, "output" }, -- 6

    ingredient = { defines.inventory.assembling_machine_input, "input" }, -- 2
    product = { defines.inventory.assembling_machine_output, "output" }, -- 3
    module = { defines.inventory.assembling_machine_modules, "closed" }, -- 4
    dump = { defines.inventory.assembling_machine_dump, "output" }, -- 7

    robot = { defines.inventory.roboport_robot, "open" }, -- 1
    material = { defines.inventory.roboport_material, "open" }, -- 2

    rocket = { defines.inventory.rocket_silo_rocket, "open" }, -- 9
}

-- Mappings from unified inventory names to inventory indices for each entity type

-- Many entity types may be configured to include a burner power source, adding inventories for consumed fuel, burnt fuel, and a waste slot for spoiled items invalid as fuel
---@type inventory_mapping
local basic_defaults = {
    waste = inventory_defaults.waste, -- 8
    fuel = inventory_defaults.fuel, -- 1
    byproduct = inventory_defaults.byproduct, -- 6
}

-- These entity types have the same inventories as basic_defaults, but add special slots for inputs and outputs, and/or potentially modules and an expandable dump inventory
---@type inventory_mapping
local crafting_defaults = {
    waste = inventory_defaults.waste, -- 8
    fuel = inventory_defaults.fuel, -- 1
    byproduct = inventory_defaults.byproduct, -- 6
    ingredient = inventory_defaults.ingredient, -- 2 -- aka furnace_source, lab_input, rocket_silo_input
    product = inventory_defaults.product, -- 3 -- aka furnace_result, lab_modules, rocket_silo_output
    module = inventory_defaults.module, -- 4 -- aka furnace_modules, rocket_silo_modules
    dump = inventory_defaults.dump, -- 7
}

-- These entities have only a single inert main inventory
---@type inventory_mapping
local container_defaults = {
    main = inventory_defaults.main, -- 1 -- aka cargo_unit, cargo_wagon, proxy_main
}

-- These entities add a logistic trash inventory which will be automatically emptied by logistic bots when inside a network
---@type inventory_mapping
local logistic_container_defaults = {
    main = inventory_defaults.main, -- 1 -- aka cargo_landing_pad_main, hub_main
    trash = inventory_defaults.trash, -- 2 --- aka cargo_landing_pad_trash, hub_trash
}

-- These entities have slots for ammo and a waste inventory for invalid spoilage
---@type inventory_mapping
local turret_defaults = {
    ammo = inventory_defaults.ammo, -- 1 -- aka artillery_turret_ammo, artillery_wagon_ammo
    waste = inventory_defaults.waste, -- 8
}

-- These entities potentially contain inventories to support a burner fuel source, a main inventory (trunk) with optional logistic trash, and slots for ammo
---@type inventory_mapping
local vehicle_defaults = {
    waste = inventory_defaults.waste, -- 8
    fuel = inventory_defaults.fuel, -- 1
    byproduct = inventory_defaults.byproduct, -- 6
    main = { defines.inventory.car_trunk, "open" }, -- 2 -- aka spider_trunk
    trash = { defines.inventory.car_trash, "closed" }, -- 4 -- aka spider_trash
    ammo = { defines.inventory.car_ammo, "open" }, -- 3 -- aka spider_ammo
}

---@type table<defines.prototypes.entity, inventory_mapping>
local inventory_map_by_type = {
    ["agricultural-tower"] = crafting_defaults,
    ["ammo-turret"] = turret_defaults,
    ["artillery-turret"] = turret_defaults,
    ["artillery-wagon"] = turret_defaults,
    ["assembling-machine"] = crafting_defaults,
    ["asteroid-collector"] = container_defaults,
    ["beacon"] = { -- beacons have only module, and in a unique slot
        module = { defines.inventory.beacon_modules, "open" }, -- 1
    },
    ["boiler"] = basic_defaults,
    ["burner-generator"] = basic_defaults,
    ["car"] = vehicle_defaults,
    ["cargo-landing-pad"] = logistic_container_defaults,
    ["cargo-pod"] = container_defaults,
    ["cargo-wagon"] = container_defaults,
    ["container"] = container_defaults,
    ["furnace"] = crafting_defaults,
    ["fusion-reactor"] = basic_defaults,
    ["generator"] = basic_defaults,
    ["infinity-cargo-wagon"] = container_defaults,
    ["infinity-container"] = container_defaults,
    ["inserter"] = basic_defaults,
    ["lab"] = { -- labs may include burner inventories and use a unique slot for modules
        waste = inventory_defaults.waste, -- 8
        fuel = inventory_defaults.fuel, -- 1
        byproduct = inventory_defaults.byproduct, -- 6
        ingredient = { defines.inventory.lab_input, "open" }, -- 2
        module = { defines.inventory.lab_modules, "closed" },-- 3
    },
    ["linked-container"] = container_defaults,
    ["locomotive"] = basic_defaults,
    ["logistic-container"] = logistic_container_defaults,
    ["mining-drill"] = { -- mining drills may include burner inventories and use a unique slot for modules
        waste = inventory_defaults.waste, -- 8
        fuel = inventory_defaults.fuel, -- 1
        byproduct = inventory_defaults.byproduct, -- 6
        module = { defines.inventory.mining_drill_modules, "closed" }, -- 2
    },
    ["offshore-pump"] = basic_defaults,
    ["proxy-container"] = container_defaults,
    ["pump"] = basic_defaults,
    ["radar"] = basic_defaults,
    ["reactor"] = basic_defaults,
    ["roboport"] = { -- roboports have unique slots for robots and repair packs
        robot = inventory_defaults.robot, -- 1
        material = inventory_defaults.material, -- 2
    },
    ["rocket-silo"] = { -- rocket silos have slots similar to crafting_defaults, but add inventories for the rocket and logistic trash
        waste = inventory_defaults.waste, -- 8
        fuel = inventory_defaults.fuel, -- 1
        byproduct = inventory_defaults.byproduct, -- 6
        ingredient = { defines.inventory.rocket_silo_input, "input" }, -- 2
        product = { defines.inventory.rocket_silo_output, "closed" }, -- 3
        module = { defines.inventory.rocket_silo_modules, "closed" }, -- 4
        rocket = inventory_defaults.rocket, -- 9
        trash = { defines.inventory.rocket_silo_trash, "closed" }, -- 11
    },
    ["space-platform-hub"] = logistic_container_defaults, -- technically, its "trash" slots are unique for being sent to another surface (as with rocket inventories), but is limited and emptied similarly
    ["spider-vehicle"] = vehicle_defaults,
    ["temporary-container"] = container_defaults,
}

-- A cache of resolved inventory mappings by entity. Custom mappings are also stored here to circumvent the usual lookup.
-- The optimal way to look up a mapping is using a LuaEntity instance. Though mappings by entity name are cached with use.
-- The full entity name mapping is not guaranteed to be complete, so is not reliable for direct lookup.
---@type table<EntityID, inventory_mapping>
local inventory_map = setmetatable({}, {
    ---@param self table<EntityID, inventory_mapping>
    ---@param entity EntityID?
    ---@return inventory_mapping
    __index = function(self, entity)
        if type(entity) == "string" then
            local map = inventory_map_by_type[entity]
            self[entity] = map
            return map
        end
        if not entity or not entity.valid or not entity.name then return end
        local map = self[entity.name] or self[entity.type]
        self[entity.name] = map
        self[entity] = map
        return map
    end,
    __mode = "k",
})

-- Allows third-party mods to register custom inventory mappings for their custom entities
-- This should ideally be called before any lookups are performed for that entity type
---@param entity { name: string, base: string }
---@param remap table<inventory_type, { [1]:inventory_type, [2]:inventory_role? } | inventory_type>
---@return inventory_mapping
local function register_inventory_remap(entity, remap)
    local base = inventory_map[entity.base]
    local map = {}
    for name, info in pairs(remap) do
        if type(info) == "string" then
            map[name] = base[info]
        else
            map[name] = { base[info[1]][1], info[2] or base[info[1]][2] }
        end
    end
    inventory_map[entity.name] = map
    return map
end

---@param entity? LuaEntity
---@param name inventory_type
---@return defines.inventory?, inventory_role?
local function get_inventory_info(entity, name)
    if not entity or name == "none" then return end
    local info = (inventory_map[entity] or {})[name]
    if not info then return end
    return info[1], info[2]
end

-- Returns a list of inventory type names valid for a specific entity with optional filtering to only context-specific inventories.
-- The access_mode option may be "input" or "output" to show inventories useful for inserter relationship, "both" to show only
-- inventories that normally allow free access in both directions, and "any" to show all inventories, including those that are not
-- generally accessible at all.
--
-- The last fallback string for each inventory type is always the inventory_type itself. This can be used as a parameter for other
-- API calls.
---@param entity? LuaEntity
---@param options? { access_mode: inventory_access_mode?, check_valid: boolean?, hide_zero_size: boolean?, hide_inaccessible: boolean? }
---@return inventory_type[]
local function get_inventories(entity, options)
    -- Default option values
    options = options or {}
    local access_mode = options.access_mode or "any"
    local check_valid = options.check_valid
    if check_valid == nil then check_valid = true end
    local hide_zero_size = options.hide_zero_size
    if hide_zero_size == nil then hide_zero_size = true end
    local hide_inaccessible = options.hide_inaccessible
    if hide_inaccessible == nil then hide_inaccessible = false end

    local map
    local names = { "none" }
    if entity then
        map = inventory_map[entity]
    else
        map = inventory_defaults
    end
    if not map then return names end

    for name, info in pairs(map) do
        -- ensure this inventory is valid for this specific prototype (non-nil and slots > 0)
        local index, role = info[1], info[2]
        -- check if the access mode matches the role
        local inaccessible = not(access_mode == "any" or role == "open" or role == access_mode)
        if not hide_inaccessible or not inaccessible then
            if not check_valid then
                table.insert(names, name)
            elseif entity and entity.valid then
                local inventory = entity.get_inventory(index)
                if inventory and (not hide_zero_size or #inventory > 0) then
                    table.insert(names, name)
                end
            end
        end
    end
    return names
end

local library = {
    register_inventory_remap = register_inventory_remap,
    get_inventory_info = get_inventory_info,
    get_inventories = get_inventories,
}

function library.add_remote_interface()
    remote.add_interface("inventory-selector-types", library)
end

return library
