-- A hidden proxy container associated with an inserter, allowing it to interact with a specific inventory index in its original target.
-- Because of changes in 2.0.44 affecting use of these flags, this has been split into two entities: this one for pickup and another for drop.
-- See: https://forums.factorio.com/viewtopic.php?t=128081
-- See: https://forums.factorio.com/viewtopic.php?t=128082
---@type data.ProxyContainerPrototype
local proxy_pickup = {
    type = "proxy-container",
    name = "inventory-selector-proxy-pickup",
    flags = { "not-repairable", "not-on-map", "not-deconstructable", "not-blueprintable", "not-selectable-in-game", "not-upgradable", "not-in-kill-statistics", "no-automated-item-insertion" },
    max_health = 1e9,
    picture = util.empty_sprite(),
    draw_inventory_content = false,
    draw_copper_wires = false,
    draw_circuit_wires = false,
    create_ghost_on_death = false,
    created_smoke = nil,
    collision_box = { {-0.0, -0.0}, {0.0, 0.0} },
    selection_box = { {-0.0, -0.0}, {0.0, 0.0} },
    collision_mask = { layers = {}, not_colliding_with_itself=true },
    remove_decoratives = "false",
    selectable_in_game = false,
    tile_height = 1,
    tile_width = 1,
    selection_priority = 0,
    hidden = true,
    hidden_in_factoriopedia = true,
}

-- A hidden proxy container associated with an inserter, allowing it to interact with a specific inventory index in its original target.
-- Because of changes in 2.0.44 affecting use of these flags, this has been split into two entities: this one for drop and another for pickup.
-- See: https://forums.factorio.com/viewtopic.php?t=128081
-- See: https://forums.factorio.com/viewtopic.php?t=128082
---@type data.ProxyContainerPrototype
local proxy_drop = {
    type = "proxy-container",
    name = "inventory-selector-proxy-drop",
    flags = { "not-repairable", "not-on-map", "not-deconstructable", "not-blueprintable", "not-selectable-in-game", "not-upgradable", "not-in-kill-statistics", "no-automated-item-removal" },
    max_health = 1e9,
    picture = util.empty_sprite(),
    draw_inventory_content = false,
    draw_copper_wires = false,
    draw_circuit_wires = false,
    create_ghost_on_death = false,
    created_smoke = nil,
    collision_box = { {-0.0, -0.0}, {0.0, 0.0} },
    selection_box = { {-0.0, -0.0}, {0.0, 0.0} },
    collision_mask = { layers = {}, not_colliding_with_itself=true },
    remove_decoratives = "false",
    selectable_in_game = false,
    tile_height = 1,
    tile_width = 1,
    selection_priority = 0,
    hidden = true,
    hidden_in_factoriopedia = true,
}

-- A hidden chest with zero slots, useful as a placeholder for proxy chests that don't have a better target at the moment.
-- Necessary to work around implementation issues that causes inserters to forget what they were doing.
-- See: https://forums.factorio.com/viewtopic.php?t=127774
-- No longer necessary as of 2.0.44, but still useful to explicitly represent an empty inventory in some cases.
---@type data.ContainerPrototype
local limbo = {
    type = "container",
    name = "inventory-selector-limbo",
    flags = { "not-repairable", "not-on-map", "not-deconstructable", "not-blueprintable", "not-selectable-in-game", "not-upgradable", "not-in-kill-statistics", "no-automated-item-insertion", "no-automated-item-removal" },
    max_health = 1e9,
    picture = util.empty_sprite(),
    draw_inventory_content = false,
    draw_copper_wires = false,
    draw_circuit_wires = false,
    create_ghost_on_death = false,
    created_smoke = nil,
    collision_box = { {-0.0, -0.0}, {0.0, 0.0} },
    selection_box = { {-0.0, -0.0}, {0.0, 0.0} },
    collision_mask = { layers = {}, not_colliding_with_itself=true },
    remove_decoratives = "false",
    selectable_in_game = false,
    tile_height = 1,
    tile_width = 1,
    selection_priority = 0,
    hidden = true,
    hidden_in_factoriopedia = true,
    inventory_size = 0,
    inventory_type = "normal",
    quality_affects_inventory_size = false,
}

return {
    proxy_drop_entity = proxy_drop,
    proxy_pickup_entity = proxy_pickup,
    limbo_entity = limbo,
    all = { proxy_drop, proxy_pickup, limbo }
}
