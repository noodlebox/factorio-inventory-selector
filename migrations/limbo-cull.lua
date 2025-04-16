-- Cull limbo chests that were created due to a bug in inventory-selector <=1.0.0
-- See: https://github.com/noodlebox/factorio-inventory-selector/issues/1

local limbo = require("script.limbo")

-- First, reassign any proxies to properly placed limbo containers, if necessary
for _, selector in pairs(storage.selectors) do
    local proxy = selector.proxy
    if proxy and proxy.valid then
        local target = proxy.proxy_target_entity
        if target and target.valid and target.name == "inventory-selector-limbo" then
            proxy.proxy_target_entity = limbo[proxy.surface_index]
        end
    end
end

-- Then, remove the misplaced limbo containers
for _, surface in pairs(game.surfaces) do
    for _, entity in pairs(surface.find_entities_filtered{ name="inventory-selector-limbo", position={0.5,0.5} }) do
        entity.destroy()
    end
end
