-- Inventory Selection Control API
return {
    -- Get currently assigned inventory type. Specifically, this returns the currently desired inventory assignment, even if it has
    -- been deferred. If the "immediate" setting is given, return the actual configuration, leaking some implementation details that
    -- are likely not relevant outside of debugging. In most cases, the default behavior is both sufficient and preferable.
    ---@param entity LuaEntity
    ---@param mode action
    ---@param immediate? boolean # Reveal the truth to those that can handle it.
    ---@return inventory_type?
    get = function (entity, mode, immediate)
        return remote.call("inventory-selector", "get", entity, mode, immediate)
    end,

    -- Assign a new inventory type to a selector (or restore its default behavior if nil).
    --
    -- Its default behavior avoids potential deadlock that may be caused by removing access to the intended drop target of the items
    -- held by an inserter, in these cases, delaying application of the new configuration until the risk has passed. This behavior is
    -- applied transparently to the user to avoid exposing additional complexity that would not be helpful with typical usage.
    --
    -- Any pending changes will be flushed immediately if the entity being targeted is changed, with obsolete settings never persisting
    -- beyond their original target.
    --
    -- The immediate flag overrides this logic and clears any pending changes, appropriate for player-initiated changes via a GUI.
    ---@param entity LuaEntity
    ---@param mode action
    ---@param inventory_type? inventory_type
    ---@param immediate? boolean # Throw caution to the wind. Deadlocks build character.
    ---@return boolean # true if the desired setting has been successfully applied (not deferred)
    set = function (entity, mode, inventory_type, immediate)
        return remote.call("inventory-selector", "set", entity, mode, inventory_type, immediate)
    end,

    ---@param entity LuaEntity
    ---@param mode action
    ---@return boolean
    get_circuit_mode = function (entity, mode)
        return remote.call("inventory-selector", "get_circuit_mode", entity, mode)
    end,

    -- Set the circuit mode for this selector. This will override any existing inventory type setting.
    ---@param entity LuaEntity
    ---@param mode action
    ---@param enable? boolean # Defaults to true
    set_circuit_mode = function (entity, mode, enable)
        return remote.call("inventory-selector", "set_circuit_mode", entity, mode, enable)
    end,

    -- Returns true if the given entity supports an inventory selection for the given interaction mode.
    ---@param entity? LuaEntity
    ---@param mode action
    ---@return boolean
    supports_mode = function (entity, mode)
        return remote.call("inventory-selector", "supports_mode", entity, mode)
    end,

    -- Return true if a call to set() right now with the same parameters would either be deferred or risk deadlocking.
    -- Should never raise an error unless given entity is nil or not valid.
    ---@param entity LuaEntity
    ---@param mode action
    ---@param inventory_type? inventory_type
    ---@return boolean
    can_safely_set = function (entity, mode, inventory_type)
        return remote.call("inventory-selector", "can_safely_set", entity, mode, inventory_type)
    end,

    ---@param victim id
    notify = function (victim)
        return remote.call("inventory-selector", "notify", victim)
    end,
}
