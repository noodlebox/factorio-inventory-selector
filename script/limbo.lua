local inventory = require("script.inventory")

-- Create a remapping for limbo container entities, which forwards all inventory types to the "storage" chest inventory
local limbo_remap = { "main", "closed" }
inventory.register_inventory_remap({ name = "inventory-selector-limbo", base = "container" }, {
    ammo = limbo_remap,
    main = limbo_remap,
    trash = limbo_remap,
    waste = limbo_remap,
    fuel = limbo_remap,
    byproduct = limbo_remap,
    ingredient = limbo_remap,
    product = limbo_remap,
    module = limbo_remap,
    dump = limbo_remap,
    robot = limbo_remap,
    material = limbo_remap,
    rocket = limbo_remap,
})

local origin = {0, 0}

-- Maintains "limbo" containers that can be used as the target of a proxy container to prevent inserters from losing interest in them
-- See: https://forums.factorio.com/viewtopic.php?t=127774 for relevant discussion
--
-- This is a workaround: limbo containers provide a cheap and easy(?) target with probably no side effects ever. Though a single
-- limbo container could suffice for proxies across all surfaces, creating at least one per surface ensures they are unlikely to be
-- destroyed out of sync with the proxies that depend on them. Ensuring proxies never have an invalid target inventory is essential
-- in order to maintain functional correctness of the features provided by this mod.
--
-- We could watch for surface creation and destruction events, but this seems unnecessary for now. They are created lazily, and if a
-- surface is ever destroyed, everything referring to it should have been destroyed as well.
--
-- The strong need for these has been mostly resolved by changes to inserter behavior in 2.0.44, though this version introduces new
-- issues because of the change to the behavior of entity prototype flags concerning automated interaction.
-- TODO: Open a new bug report for these issues once explored a bit more.
local limbo = setmetatable({}, {
    ---@param surface_index uint
    ---@return LuaEntity?
    __index = function(self, surface_index)
        local surface = game.surfaces[surface_index]
        if not surface then return nil end
        local entity = surface.find_entity("inventory-selector-limbo", origin)
        if not entity then
            -- Any and all flags that can be set to make this entity as invisible and uninteractable as possible
            -- should be present here.
            entity = surface.create_entity{
                name = "inventory-selector-limbo",
                position = origin,
                snap_to_grid = false,
                force = game.forces.neutral,
                create_build_effect_smoke = false,
                preserve_ghosts_and_corpses = true,
            }
            entity.destructible = false
            entity.minable_flag = false
            entity.operable = false
            entity.active = false
        end
        -- Cache the reference for future lookups
        self[surface_index] = entity
        return entity
    end,
})

return limbo
