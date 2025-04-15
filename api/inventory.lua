return {
    ---@param entity { name: string, base: string }
    ---@param remap table<inventory_type, { [1]:inventory_type, [2]:inventory_role? } | inventory_type>
    ---@return inventory_mapping
    register_inventory_remap = function (entity, remap)
        return remote.call("inventory-selector-types", "register_inventory_remap", entity, remap)
    end,

    ---@param entity LuaEntity
    ---@param name inventory_type
    ---@return defines.inventory?, inventory_role?
    get_inventory_info = function (entity, name)
        return remote.call("inventory-selector-types", "get_inventory_info", entity, name)
    end,

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
    get_inventories = function (entity, options)
        return remote.call("inventory-selector-types", "get_inventories", entity, options)
    end,
}
