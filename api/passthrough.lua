-- Proxy Bypass API
--
-- This is intended for use by other mods which depend on the unaltered behavior of `drop_target` or `pickup_target` to
-- implement their own custom logic or other features that is incompatible with the way this mod obscures entity relationships
-- through proxies meant only for internal use. Those mods may implement their functionality equivalently using this API
-- instead if available, allowing them to do so without risk of disruption by or against this mod's own implemented features.
--
-- There may be situations where this mod's intentional behavior, either broadening or narrowing an entity's usual capabilities,
-- leads to a difference in outcome when active. Excluding these, these methods should raise errors wherever the original API
-- would, or will simply allow them to pass uncaught with no intention of guarding against them. On the other hand, these
-- should never raise errors in situations the original API treats as valid (with the exception of errors resulting from other
-- external interference preventing normal operation of this mod.
return {
    -- Returns the "apparent" drop_target or pickup_target of an entity, even when that actual connection is currently mediated
    -- through a proxy entity managed internally by this mod, without requiring specific knowledge of its implementation. The
    -- values provided by this API, as opposed to those obtained from the properties directly, should generally be more useful
    -- to mods more interested in the functional relationships between entities according to typical game mechanics, which may
    -- be obscured by this mod's own implementation when active.
    --
    -- Code substitutions for equivalent usage:
    -- - `local target = entity.drop_target` -> `local target = get_target(entity, "drop")`
    -- - `local target = entity.pickup_target` -> `local target = get_target(entity, "pickup")`
    ---@see LuaEntity.drop_target
    ---@see LuaEntity.pickup_target
    ---@param entity LuaEntity
    ---@param mode action
    ---@return LuaEntity?
    get_target = function (entity, mode)
        return remote.call("inventory-selector-passthrough", "get_target", entity, mode)
    end,

    -- Sets the "apparent" drop_target or pickup_target of an entity, even when that actual connection is currently mediated
    -- through a proxy entity managed internally by this mod, without requiring specific knowledge of its implementation. Use
    -- of this API is strongly encouraged over direct manipulation of the target properties, whose values are critical to the
    -- correct operation of this mod's core features.
    --
    -- Code substitutions for equivalent usage:
    -- - `entity.drop_target = target` -> `set_target(entity, "drop", target)`
    -- - `entity.pickup_target = target` -> `set_target(entity, "pickup", target)`
    ---@see LuaEntity.drop_target
    ---@see LuaEntity.pickup_target
    ---@param entity LuaEntity
    ---@param mode action
    set_target = function (entity, mode, target)
        return remote.call("inventory-selector-passthrough", "set_target", entity, mode, target)
    end,

    -- Returns the drop_position or pickup_position of an entity. The current implementation does not generally disrupt access
    -- to these properties, but it is included for completeness.
    --
    -- Code substitutions for equivalent usage:
    -- - `local position = entity.drop_position` -> `local position = get_position(entity, "drop")`
    -- - `local position = entity.pickup_position` -> `local position = get_position(entity, "pickup")`
    ---@see LuaEntity.drop_position
    ---@see LuaEntity.pickup_position
    ---@param entity LuaEntity
    ---@param mode action
    ---@return MapPosition
    get_position = function (entity, mode)
        return remote.call("inventory-selector-passthrough", "get_position", entity, mode)
    end,

    -- Sets the drop_position or pickup_position of an entity. Use of this API is encouraged over direct manipulation of these
    -- properties, as up-to-date knowledge of their values is necessary to guarantee this mod's functional correctness.
    --
    -- Alternatively, mods designed around tight control over these properties may also simply notify this one afterwards via
    -- its "event" interface, using `notify(entity.unit_number)` to signal potentially relevant changes to that entity. This
    -- method may safely be called even if these properties have not actually changed, but it must be called if they have.
    --
    -- Code substitutions for equivalent usage:
    -- - `entity.drop_position = position` -> `set_position(entity, "drop", position)`
    -- - `entity.pickup_position = position` -> `set_position(entity, "pickup", position)`
    ---@see LuaEntity.drop_position
    ---@see LuaEntity.pickup_position
    ---@param entity LuaEntity
    ---@param mode action
    ---@param position MapPosition
    set_position = function (entity, mode, position)
        return remote.call("inventory-selector-passthrough", "set_position", entity, mode, position)
    end,
}
