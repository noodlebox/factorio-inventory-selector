local inventory = require("script.inventory")
local limbo = require("script.limbo")

local DEADLOCK_SAFETY = settings.global["inventory-selector-deadlock-safety"].value --[[@as "always-immediate" | "allow-unsafe" | "always-safe"]]
local ENABLE_CIRCUIT = settings.global["inventory-selector-enable-circuit"].value --[[@as boolean]]
local PENDING_RETRY_TICKS = settings.global["inventory-selector-pending-retry-ticks"].value --[[@as integer]]
local FLOATING_RETRY_TICKS = settings.global["inventory-selector-floating-retry-ticks"].value --[[@as integer]]
local UPDATE_CIRCUIT_TICKS = settings.global["inventory-selector-update-circuit-ticks"].value --[[@as integer]]
local DEBUG = settings.global["inventory-selector-enable-debug"].value --[[@as boolean]]

---@alias id integer
---@alias action "drop" | "pickup"

-------------------------------------------------------------------------------
-- Utility functions
-------------------------------------------------------------------------------

---@param entity LuaEntity
---@param mode action
---@return LuaEntity?, MapPosition
local function read_target(entity, mode)
    if mode == "drop" then
        return entity.drop_target, entity.drop_position
    elseif mode == "pickup" then
        return entity.pickup_target, entity.pickup_position
    else
        error("Invalid mode: " .. mode .. " for entity: " .. entity.name)
    end
end

---@param entity LuaEntity
---@param mode action
---@param new_target? LuaEntity
local function write_target(entity, mode, new_target)
    if mode == "drop" then
        entity.drop_target = new_target
    elseif mode == "pickup" then
        entity.pickup_target = new_target
    else
        error("Invalid mode: " .. mode .. " for entity: " .. entity.name)
    end
end

---@param position MapPosition
---@return BoundingBox
local function get_tile(position)
    return {
        left_top = { x = math.ceil(position.x) - 1, y = math.ceil(position.y) - 1 },
        right_bottom = { x = math.floor(position.x) + 1, y = math.floor(position.y) + 1 },
    }
end

---@param position MapPosition
---@param region BoundingBox
---@return boolean
local function is_inside(position, region)
    local a0 = region.left_top
    local a1 = region.right_bottom
    return position.x >= a0.x and position.x <= a1.x and position.y >= a0.y and position.y <= a1.y
end

-- Keep track of important entity relationships so their loss can be handled gracefully.
local registry = {}

-- Dispatch notifications for the loss of an entity
---@param victim id
registry.lose = function (victim)
    local mourners = storage.mourners[victim]
    storage.mourners[victim] = nil
    if not mourners then return end

    if not registry.mourn then return end
    for mourner in pairs(mourners) do
        registry.mourn(mourner, victim)
    end
end

---@param id id
---@param target LuaEntity
registry.remember = function (id, target)
    if not target or not target.valid then return end
    local _, target_id = script.register_on_object_destroyed(target)
    --local target_id = target.unit_number --[[@as id]]
    local mourners = storage.mourners[target_id]
    if not mourners then
        storage.mourners[target_id] = { [id] = true }
    else
        mourners[id] = true
    end
end

---@class selector
-- A constant unique key among selectors, the index used as the key for various dictionaries tracking their state.
-- It is derived from the unit number of the entity it controls and its mode of action:
-- - `entity.unit_number`:  drop action of `entity`
-- - `-entity.unit_number`: pickup action of `entity`
---@field id id
-- The primary entity whose behavior is managed by this selector. May be of any type supporting drop and/or pickup targets.
-- This assignment is constant over the lifetime of the selector. If killed, even if revivable, its configuration data is copied into tags on the associated ghost entity, to be reassigned on a new selector once revived.
---@field entity LuaEntity
--- The interaction mode managed by this selector. Either "drop" or "pickup". This setting is constant over the lifetime of the selector.
--- Technically, derivable from the id alone, but included for convenience, as entity/mode pairs are the most common way external interfaces will refer to managed entities, with its id mostly used internally.
---@field mode action
-- The configured inventory restriction, if any. Uses a "unified" inventory type name, which may map to distinct inventory indices across different entity types.
-- This is the only meaningful way to refer to a selected inventory across this mod's API.
-- Some special values are possible:
-- - "circuit" indicates that this selector's configuration should be determined by the connected circuit network. Behaves as "none" if no circuit network is connected.
-- - nil indicates that the entity should use its built-in default behavior if possible, as if this selector did not exist.
---@field inventory_type? inventory_type | "circuit"
-- The actual inventory restriction, if any. This may differ from `inventory_type` if a change is pending (to avoid deadlock) or if a nil setting would leave no targets for the default behavior to use.
---@field actual_inventory_type? inventory_type
-- An instance of the hidden proxy entity, through which all interaction between `entity` and `target` is mediated.
-- This only supports interaction through this mod's provided APIs. Any external interaction otherwise may cause undefined behavior.
---@field proxy LuaEntity
-- The "apparent" target of this entity, which would be assumed to be the true target of interaction for this entity. When this selector is active, all interaction with this target is managed through the proxy entity.
-- A direct reference to this entity is maintained to allow for convenient assignment to the proxy entity as needed, as well as shared through the APIs to permit other mods to read a entity's apparent target, even when this connection is simulated by mediated interaction with the proxy here.
---@field target? LuaEntity
-- The cached unit_number of `target`, used when necessary to identify its revived replacement. A matching target_id is preferred when a new target must be found and assigned.
-- This is also used to confirm the identity of `target` after it may have been destroyed.
---@field target_id? id
-- The cached unit_number of a secondary target, if any. This is only used when the primary target is a proxy container itself (implemented by another mod, for example).
-- As proxy containers are not valid targets for other proxies, the access which would otherwise be supported by an unmodified inserter must be replicated here manually.
-- The settings of the targeted proxy container are duplicated by the proxy here in order to simulate this "chained" relaying of access.
-- This id also allows the destruction of a chained target to be confirmed if necessary.
---@field chained_id? id
local selector = {}

-- Minimal "class" implementation
selector = setmetatable(selector, { __call = function (cls, obj) return setmetatable(obj or {}, cls):init() end })
selector.__index = selector

script.register_metatable("inventory-selector", selector)

---@return selector
function selector:init()
    local entity = self.entity
    local mode = self.mode
    local target, position = read_target(entity, mode)
    if not self.proxy or not self.proxy.valid then
        local proxy = entity.surface.create_entity{
            name = mode == "drop" and "inventory-selector-proxy-drop" or "inventory-selector-proxy-pickup",
            position = position,
            force = entity.force,
            create_build_effect_smoke = false,
            preserve_ghosts_and_corpses = true,
        } or error("Failed to create proxy for entity: " .. serpent.line(self))
        proxy.destructible = false
        proxy.minable_flag = false
        proxy.operable = false
        self.proxy = proxy
    end

    return self:update_proxy_target(target)
end

-- Remove a proxy and its associated data
---@return nil
function selector:destroy()
    local id = self.id

    storage.selectors[id] = nil
    storage.floating[id] = nil
    storage.pending[id] = nil
    storage.circuit[id] = nil

    -- Restore direct connection to the target entity, if appropriate
    if self.entity then
        if self.entity.valid then
            self:connect_proxy(false)
        end
        self.entity = nil
    end
    self.target = nil
    self.target_id = nil
    self.chained_id = nil

    local proxy = self.proxy
    if proxy and proxy.valid then proxy.destroy() end
end

-- Connect an entity with its proxy or bypass it to connect with its target.
-- If DEBUG is enabled, this will not attempt to reassign the target if assumed not necessary.
-- It will confirm whether the connection ends in the intended state in either case, raising an error if not.
---@param state? boolean # Defaults to true, which will connect the entity to its proxy. If false, disconnects the entity from its proxy (and connects it to its target directly).
---@param expect? boolean # If given, checks assumptions for debugging, to potentially expose faults in implementation that could otherwise go unnoticed in most normal use.
---@return selector
function selector:connect_proxy(state, expect)
    if state == nil then state = true end
    if not DEBUG then expect = nil end

    local entity = self.entity
    local mode = self.mode
    local proxy = self.proxy
    local target = self.target

    local pre_target, position = read_target(entity, mode)
    ---@type boolean|nil
    local pre_state = pre_target == proxy
    if not pre_state and pre_target ~= target then pre_state = nil end

    if expect == state and state ~= pre_state then
        error("Entity and proxy unexpectedly " .. (pre_state and "" or "dis") .. "connected: " .. serpent.line(self))
    end

    proxy.force = entity.force
    proxy.teleport(position)
    if state then
        write_target(entity, mode, proxy)
    else
        write_target(entity, mode, target)
    end

    if expect == nil then return self end

    local post_target = read_target(entity, mode)
    ---@type boolean|nil
    local post_state = post_target == proxy
    if not post_state and post_target ~= target then post_state = nil end

    if state ~= post_state then
        error("Entity failed to " .. (state and "" or "dis") .. "connect with proxy: " .. serpent.line(self))
    end

    return self
end

-- Ensure configuration of proxy is correct
-- Call directly when:
-- - actual_inventory_type has changed
-- - target is a proxy-container whose own target may have changed
---@return selector
function selector:update_proxy_inventory()
    local target = self.target
    if target and not target.valid then return self:update_proxy_target() end
    local index = nil
    local inventory_type = self.actual_inventory_type
    local proxy = self.proxy

    self.chained_id = nil -- Clear this in case it was set by a prior call

    if not target or not inventory_type or inventory_type == "none" then goto limbo end

    if target.type ~= "proxy-container" then
        -- Just try a simple mapping
        index = inventory.get_inventory_info(target, inventory_type)
    else
        -- We cannot assign a proxy container as an actual proxy target
        -- However, we can forward the "main" inventory along to the proxy's own target
        local chained = target.proxy_target_entity
        local chained_index = target.proxy_target_inventory
        if self.actual_inventory_type ~= "main" or not chained or not chained_index then goto limbo end

        target = chained
        index = chained_index

        -- Track the secondary target as well
        registry.remember(self.id, chained)
        self.chained_id = chained.unit_number--[[@as id]]
    end

    -- One final check for inventory validity, falling back onto limbo container if necessary
    if index and target.get_inventory(index) then
        goto assign
    end

    ::limbo::
    -- The target wasn't valid for some reason, so just prepare a limbo container
    target = limbo[proxy.surface_index]
    index = inventory.get_inventory_info(target, "main") or defines.inventory.chest -- 1

    ::assign::
    proxy.proxy_target_entity = target
    proxy.proxy_target_inventory = index

    self:connect_proxy(inventory_type ~= nil)

    -- Force entity to wake up if sleeping
    self.entity.active = false
    self.entity.active = true
    return self
end

-- Ensure the target is valid, replacing it with the given target if not nil.
-- Call when:
-- - preparing a new selector
-- - target may have gone away
-- - entity was moved, rotated, or flipped
-- - entity's drop_position or pickup_position has changed
---@param target? LuaEntity
---@return selector
function selector:update_proxy_target(target)
    local id = self.id
    local entity = self.entity
    local mode = self.mode

    registry.remember(id, entity)

    target = target or self.target

    if target and not target.valid then
        target = nil
    end

    local _, position = read_target(entity, mode)

    -- Validate this target, or find a better one
    local hint = target and target.unit_number
    target = nil

    for _, candidate in ipairs(entity.surface.find_entities_filtered{
        area = get_tile(position),
        collision_mask = { "item", "car" },
        force = entity.force,
    }) do
        target = candidate
        -- Found exactly what we were looking for, so use it
        if hint and candidate.unit_number == hint then break end
    end

    if target and (target.type == "straight-rail" or target.type == "half-diagonal-rail" or target.type == "curved-rail-a" or target.type == "curved-rail-b") then
        for _, candidate in ipairs(entity.surface.find_entities_filtered{
            area = get_tile(position),
            collision_mask = { "train" },
            force = entity.force,
        }) do
            local train = candidate.train
            if train and (train.state == defines.train_state.manual_control or train.state == defines.train_state.wait_station) then
                target = candidate
                break
            end
        end
    end

    if not target or target.unit_number ~= self.target_id then
        -- If the entity has a pending change to inventory type of drop target, just apply it now because entity is changing anyway
        local pending = storage.pending[id]
        if pending then
            self.actual_inventory_type = pending ~= "clear" and pending or nil --[[@as inventory_type?]]
            storage.pending[id] = nil
        end
    end

    -- If the new target is nil or a car type, it should be in the floating list.
    -- These could become invalid without warning (no useful events), so they must be polled regularly for changes.
    if self.actual_inventory_type ~= "none" and (not target or target.type == "car" or target.train and target.train.state == defines.train_state.manual_control) then
        storage.floating[id] = true
    else
        storage.floating[id] = nil
    end

    self.target = target
    self.target_id = target and target.unit_number
    if target then registry.remember(id, target) end

    return self:update_proxy_inventory()
end

-------------------------------------------------------------------------------
-- Methods acting on *entities* rather than selectors directly
-------------------------------------------------------------------------------

-- Returns true if the given entity supports an inventory selection for the given interaction mode.
---@param entity? LuaEntity
---@param mode action
---@return boolean
local function supports_mode(entity, mode)
    if not entity or not entity.valid then return false end
    -- Only Inserter entities support reading the pickup_position property. Any others will raise an error rather than returning nil.
    if mode == "pickup" then return entity.type == "inserter" or entity.type == "entity-ghost" and entity.ghost_type == "inserter" end
    -- A much wider variety of entity types support a drop target, some of optionally. These include inserters, mining drills, and any
    -- crafting machine subtype. Whether supported or not by an entity's base class, reading drop_position will safely return nil if
    -- not supported by the entity.
    if mode == "drop" then return entity.drop_position ~= nil end
    return false
end

-- Get existing state data or possibly create it if it doesn't exist.
---@param entity LuaEntity
---@param mode action
---@param please? any # Ensure a non-nil result or die trying.
---@return selector?
local function get_data(entity, mode, please)
    if not entity or not entity.valid then
        error("Entity is nil or invalid: " .. serpent.line(entity))
    elseif not supports_mode(entity, mode) then
        error("Entity does not support this mode of interaction: " .. entity.name .. ", " .. mode)
    end
    -- unit_number is non-nil for all the entities supported by this mod
    local id = entity.unit_number --[[@as id]]
    if mode == "pickup" then id = -id end
    local data = storage.selectors[id]
    if not data and please then
        data = selector{ id=id, entity=entity, mode=mode }
        storage.selectors[id] = data
    end
    return data
end

-- Return true if a call to set() right now with the same parameters would either be deferred or risk deadlocking.
-- Should never raise an error unless given entity is nil or not valid.
---@param entity LuaEntity
---@param mode action
---@param inventory_type? inventory_type
---@return boolean
local function _can_safely_set(entity, mode, inventory_type)
    -- Risk only exists for the drop action of inserters when an item is being held
    if mode ~= "drop" or entity.type ~= "inserter" or not entity.held_stack.valid_for_read then return true end
    local data = storage.selectors[entity.unit_number]
    -- If no need to set anything, no risk of deadlock
    return (data and data.actual_inventory_type) == inventory_type
end

---@param entity LuaEntity
---@param mode action
---@return inventory_type?
local function _get_unsafe(entity, mode)
    local id = entity.unit_number --[[@as id]]
    if mode == "pickup" then id = -id end
    local data = storage.selectors[id]
    return data and data.actual_inventory_type
end

---@param entity LuaEntity
---@param mode action
---@return inventory_type?
local function _get_safe(entity, mode)
    if mode == "drop" then
        local pending = storage.pending[entity.unit_number --[[@as id]]]
        if pending then
            if pending == "clear" then return nil end
            return pending --[[@as inventory_type]]
        end
    end
    return _get_unsafe(entity, mode)
end

---@param entity LuaEntity
---@param mode action
---@param immediate? boolean # Reveal the truth to those that can handle it.
---@return inventory_type?
local function _get_allow_unsafe(entity, mode, immediate)
    if immediate then
        return _get_unsafe(entity, mode)
    end
    return _get_safe(entity, mode)
end

---@param entity LuaEntity
---@param mode action
---@param inventory_type? inventory_type
---@return true
local function _set_unsafe(entity, mode, inventory_type)
    local id = entity.unit_number --[[@as id]]
    if mode == "pickup" then
        id = -id
    else
        -- Clear any pending changes to the drop inventory
        storage.pending[id] = nil
    end
    local data = storage.selectors[id]
    if not inventory_type then
        if data then data:destroy() end
        return true
    end

    if not data then
        -- Create a new selector
        storage.selectors[id] = selector{
            id=id,
            entity=entity,
            mode=mode,
            inventory_type=inventory_type,
            actual_inventory_type=inventory_type,
        }
        return true
    end

    if data.inventory_type ~= "circuit" then
        data.inventory_type = inventory_type
    end

    local prev_inventory_type = data.actual_inventory_type
    if inventory_type == prev_inventory_type then return true end

    data.actual_inventory_type = inventory_type
    if prev_inventory_type == "none" then
        -- If previously "none", then our target may be stale
        data:update_proxy_target()
    else
        -- Otherwise, skip the more expensive target check and just remap the proxy inventory
        data:update_proxy_inventory()
    end

    return true
end

---@param entity LuaEntity
---@param mode action
---@param inventory_type? inventory_type
---@return boolean # true if the desired setting has been successfully applied (not deferred)
local function _set_safe(entity, mode, inventory_type)
    if not _can_safely_set(entity, mode, inventory_type) then
        storage.pending[entity.unit_number --[[@as id]]] = inventory_type or "clear" -- An intended change to nil is represented with a value of "clear"
        return false -- Signal a deferred change
    end
    return _set_unsafe(entity, mode, inventory_type)
end

---@param entity LuaEntity
---@param mode action
---@param inventory_type? inventory_type
---@param immediate? boolean # Throw caution to the wind. Deadlocks build character.
---@return boolean # true if the desired setting has been successfully applied (not deferred)
local function _set_allow_unsafe(entity, mode, inventory_type, immediate)
    if immediate then
        return _set_unsafe(entity, mode, inventory_type)
    end
    return _set_safe(entity, mode, inventory_type)
end

local _get, _set = _get_allow_unsafe, _set_allow_unsafe

---@param deadlock_safety "always-immediate" | "allow-unsafe" | "always-safe"
local function rebind_get_set(deadlock_safety)
    if deadlock_safety == "always-immediate" then
        _get, _set = _get_unsafe, _set_unsafe
    elseif deadlock_safety == "always-safe" then
        _get, _set = _get_safe, _set_safe
    else
        _get, _set = _get_allow_unsafe, _set_allow_unsafe
    end
end
rebind_get_set(DEADLOCK_SAFETY)

-- Return true if a call to set() right now with the same parameters would either be deferred or risk deadlocking.
-- Should never raise an error unless given entity is nil or not valid.
---@param entity LuaEntity
---@param mode action
---@param inventory_type? inventory_type
---@return boolean
local function can_safely_set(entity, mode, inventory_type)
    if not entity or not entity.valid then
        error("Entity is nil or invalid: " .. serpent.line(entity))
    elseif not supports_mode(entity, mode) then
        error("Entity does not support this mode of interaction: " .. entity.name .. ", " .. mode)
    end
    return _can_safely_set(entity, mode, inventory_type)
end

-- Get currently assigned inventory type. Specifically, this returns the currently desired inventory assignment, even if it has
-- been deferred. If the "immediate" setting is given, return the actual configuration, leaking some implementation details that
-- are likely not relevant outside of debugging. In most cases, the default behavior is both sufficient and preferable.
---@param entity LuaEntity
---@param mode action
---@param immediate? boolean # Reveal the truth to those that can handle it.
---@return inventory_type?
local function get(entity, mode, immediate)
    if not entity or not entity.valid then
        error("Entity is nil or invalid: " .. serpent.line(entity))
    elseif not supports_mode(entity, mode) then
        error("Entity does not support this mode of interaction: " .. entity.name .. ", " .. mode)
    elseif entity.type == "entity-ghost" then
        local tag = ((entity.tags or {})["inventory-selector"] --[[@as selector_tag?]] or {})[mode]
        if tag == "circuit" then return "none" end
        return tag --[[@as inventory_type?]]
    end
    return _get(entity, mode, immediate)
end

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
local function set(entity, mode, inventory_type, immediate)
    if not entity or not entity.valid then
        error("Entity is nil or invalid: " .. serpent.line(entity))
    elseif not supports_mode(entity, mode) then
        error("Entity does not support this mode of interaction: " .. entity.name .. ", " .. mode)
    elseif entity.type == "entity-ghost" then
        local tags = entity.tags or {}
        tags["inventory-selector"] = tags["inventory-selector"] or {}
        tags["inventory-selector"][mode] = inventory_type
        entity.tags = tags
        return true
    end
    return _set(entity, mode, inventory_type, immediate)
end

---@param entity LuaEntity
---@param mode action
---@return boolean
local function get_circuit_mode(entity, mode)
    if not entity or not entity.valid then
        error("Entity is nil or invalid: " .. serpent.line(entity))
    elseif not supports_mode(entity, mode) then
        error("Entity does not support this mode of interaction: " .. entity.name .. ", " .. mode)
    elseif entity.type == "entity-ghost" then
        return ((entity.tags or {})["inventory-selector"] --[[@as selector_tag?]] or {})[mode] == "circuit"
    end
    local data = get_data(entity, mode)
    return data and data.inventory_type == "circuit" or false
end

-- Set the circuit mode for this selector. This will override any existing inventory type setting.
---@param entity LuaEntity
---@param mode action
---@param enable? boolean # Defaults to true
---@return nil
local function set_circuit_mode(entity, mode, enable)
    if not entity or not entity.valid then
        error("Entity is nil or invalid: " .. serpent.line(entity))
    elseif not supports_mode(entity, mode) then
        error("Entity does not support this mode of interaction: " .. entity.name .. ", " .. mode)
    elseif entity.type == "entity-ghost" then
        local tags = entity.tags or {}
        tags["inventory-selector"] = tags["inventory-selector"] or {}
        tags["inventory-selector"][mode] = enable and "circuit" or "none"
        entity.tags = tags
        return
    end
    if enable == nil then enable = true end
    local data = get_data(entity, mode, "please") --[[@as selector]]
    if enable == (data.inventory_type == "circuit") then return end
    local id = data.id
    if enable then
        storage.circuit[id] = true
        data.inventory_type = "circuit"
    else
        storage.circuit[id] = nil
        data.inventory_type = get(entity, mode)
    end
end

---@alias selector_tag table<action, inventory_type | "circuit">

---@param entity id | LuaEntity?
---@return selector_tag?
local function to_tag(entity)
    local id = entity
    local tag
    if type(entity) ~= "number" then
        if not entity or not entity.valid then return end
        tag = entity.tags and entity.tags["inventory-selector"] --[[@as selector_tag?]]
        if tag then return tag end
        id = entity.unit_number --[[@as id]]
    end
    tag = {}
    local drop = storage.selectors[id] --[[@as selector?]]
    if drop then tag.drop = drop.inventory_type end
    local pickup = storage.selectors[-id] --[[@as selector?]]
    if pickup then tag.pickup = pickup.inventory_type end
    if drop or pickup then return tag end
end

---@param entity LuaEntity?
---@param tag selector_tag?
---@return nil
local function from_tag(entity, tag)
    if not entity or not entity.valid then return end
    if entity.type == "entity-ghost" then
        local tags = entity.tags or {}
        tags["inventory-selector"] = tag
        entity.tags = tags
        return
    end

    local prev_tag = to_tag(entity)
    local prev_drop = prev_tag and prev_tag.drop
    local drop = tag and tag.drop
    if supports_mode(entity, "drop") and prev_drop ~= drop then
        set_circuit_mode(entity, "drop", drop == "circuit")
        if drop ~= "circuit" then
            _set(entity, "drop", drop --[[@as inventory_type?]], true)
        end
    end
    local prev_pickup = prev_tag and prev_tag.pickup
    local pickup = tag and tag.pickup
    if supports_mode(entity, "pickup") and prev_pickup ~= pickup then
        set_circuit_mode(entity, "pickup", pickup == "circuit")
        if pickup ~= "circuit" then
            _set(entity, "pickup", pickup --[[@as inventory_type?]], true)
        end
    end
end

-- Handle unexpected loss of an entity
-- This will be triggered by on_object_destroyed, notifying any selectors that may depend on an entity. If a selector no longer depends on the entity, it simply ignores it.
registry.mourn = function (id, victim)
    local data = storage.selectors[id]
    if not data then return end
    if not data.entity or not data.entity.valid then
        return data:destroy()
    end
    -- Determine the relationship
    if victim == id or victim == -id or victim == data.target_id or victim == data.chained_id then
        -- Victim was the entity controlled by this selector, but is still valid; or
        -- Victim was the selector's direct target, so try to find a new one; or
        -- Victim was the selector's chained target, so try to reconnect to an inventory through the proxy
        return data:update_proxy_target()
    end
    -- No longer relevant, so just ignore it
end

-- Handle relevant events

local notify = registry.lose

---@param from LuaEntity
---@param to LuaEntity
local function copy_settings(from, to)
    return from_tag(to, to_tag(from))
end

local function on_object_destroyed(event)
    if event.type ~= defines.target_type.entity then return end
    return notify(event.useful_id)
end

---@param event EventData.on_player_rotated_entity | EventData.on_player_flipped_entity | EventData.on_entity_settings_pasted
local function on_entity_modified(event)
    local entity = event.entity or event.destination --[[@as LuaEntity]]
    if not entity or not entity.valid then return end
    return notify(entity.unit_number)
end

local function on_entity_settings_pasted(event)
    copy_settings(event.source, event.destination)
    return on_entity_modified(event)
end

---@param event EventData.on_post_entity_died
local function on_post_entity_died(event)
    local ghost = event.ghost --[[@as LuaEntity?]]
    if ghost and ghost.valid then
        local tags = ghost.tags or {}
        tags["inventory-selector"] = to_tag(ghost.ghost_unit_number)
        ghost.tags = tags
    end
    return notify(event.unit_number)
end

---@param event EventData.on_player_mined_entity | EventData.on_robot_mined_entity | EventData.on_space_platform_mined_entity
local function on_mined_entity(event)
    local entity = event.entity
    local tag = entity and entity.valid and to_tag(entity)
    if not tag then return end
    if not storage.replacing then storage.replacing = {} end
    storage.replacing[entity.gps_tag] = { tag = tag, tick = event.tick }
end

---@param event EventData.on_player_setup_blueprint
local function on_player_setup_blueprint(event)
    local record = event.record or event.stack
    if not record or not record.valid then return end
    local mapping = event.mapping.get()
    for _, bpe in ipairs(record.get_blueprint_entities() or {}) do
        local id = bpe.entity_number
        local entity = mapping[id]
        local tag = entity and entity.valid and to_tag(entity)
        if tag then
            record.set_blueprint_entity_tag(id, "inventory-selector", tag)
        end
    end
end

---@param event EventData.on_built_entity | EventData.on_robot_built_entity | EventData.on_space_platform_built_entity | EventData.script_raised_revive
local function on_built_entity(event)
    local entity = event.entity
    if not entity or not entity.valid then return end
    local tag = event.tags and event.tags["inventory-selector"] --[[@as selector_tag?]]
    if not tag then
        -- No event tags, maybe fast replace?
        local replace = storage.replacing and storage.replacing[entity.gps_tag]
        if replace and replace.tick == event.tick then tag = replace.tag end
    end
    if not tag then return end
    return from_tag(entity, tag)
end

local function tick_pending()
    local pending = storage.pending
    storage.pending = {}
    for id, inventory_type in pairs(pending) do
        -- Just try again
        local data = storage.selectors[id]
        local entity = data.entity
        if entity and entity.valid then
            set(entity, data.mode, inventory_type ~= "clear" and inventory_type or nil --[[@as inventory_type?]])
        end
    end
end

local function tick_floating()
    local floating = storage.floating
    storage.floating = {}
    for id, _ in pairs(floating) do
        local data = storage.selectors[id]
        local entity = data.entity
        if entity and entity.valid then
            data:update_proxy_target()
        end
    end
    storage.replacing = {}
end

local function tick_circuit()
    -- This is a fairly naive implementation, leaving plenty room for future optimization
    for id, _ in pairs(storage.circuit) do
        local data = storage.selectors[id]
        local entity = data and data.entity
        local circuit_red, circuit_green, signals
        if not entity or not entity.valid then goto continue end

        circuit_red = entity.get_circuit_network(defines.wire_connector_id.circuit_red) --[[@as LuaCircuitNetwork]]
        circuit_green = entity.get_circuit_network(defines.wire_connector_id.circuit_green) --[[@as LuaCircuitNetwork]]
        if not circuit_red and not circuit_green then goto continue end

        if not ENABLE_CIRCUIT then goto no_signal end

        if not circuit_green then
            signals = circuit_red.signals or {}
        elseif not circuit_red then
            signals = circuit_green.signals or {}
        else
            signals = entity.get_signals(defines.wire_connector_id.circuit_red, defines.wire_connector_id.circuit_green) or {}
        end

        for _, signal in ipairs(signals) do
            local _, _, name = string.find(signal.signal.name, "^inventory%-selector%-inventory%-([_%a]+)$")
            if name and signal.count > 0 then
                set(entity, data.mode, name)
                goto continue
            end
        end
        ::no_signal::
        set(entity, data.mode, "none")
        ::continue::
    end
end

-- No-op until replaced by register_tick_handlers
local function unregister_tick_handlers() end

-- Prepare conditional tick handlers
local function register_tick_handlers()
    unregister_tick_handlers()

    local circuit_rate = ENABLE_CIRCUIT and UPDATE_CIRCUIT_TICKS or nil
    local pending_rate = DEADLOCK_SAFETY ~= "always-immediate" and PENDING_RETRY_TICKS or nil
    local floating_rate = FLOATING_RETRY_TICKS

    local handlers_by_rate = {}
    if circuit_rate then
        local handler = handlers_by_rate[circuit_rate] or {}
        table.insert(handler, tick_circuit)
        handlers_by_rate[circuit_rate] = handler
    end

    if pending_rate then
        local handler = handlers_by_rate[pending_rate] or {}
        table.insert(handler, tick_pending)
        handlers_by_rate[pending_rate] = handler
    end

    if floating_rate then
        local handler = handlers_by_rate[floating_rate] or {}
        table.insert(handler, tick_floating)
        handlers_by_rate[floating_rate] = handler
    end

    for rate, handlers in pairs(handlers_by_rate) do
        if #handlers == 1 then
            script.on_nth_tick(rate, handlers[1])
        else
            script.on_nth_tick(rate, function (event)
                for _, handler in pairs(handlers) do
                    handler(event)
                end
            end)
        end
    end

    -- Set up teardown behavior for next call
    unregister_tick_handlers = function()
        script.on_nth_tick(nil) -- Unregister all handlers

        if not not circuit_rate ~= ENABLE_CIRCUIT then
            -- Circuit mode is changing, so call this immediately to ensure circuit-controlled selectors are in a consistent state
            tick_circuit()
        end

        if pending_rate and DEADLOCK_SAFETY == "always-immediate" then
            -- Run one final time to flush any pending changes
            tick_pending()
        end
    end
end

local register_custom_handlers = function()
    -- Register handlers for custom events raised by other mods when inserter drop or pickup positions are changed

    -- Smart_Inserters 2.0.0+
    if remote.interfaces["Smart_Inserters"] and remote.interfaces["Smart_Inserters"]["on_inserter_arm_changed"] then
        script.on_event(remote.call("Smart_Inserters", "on_inserter_arm_changed"), function (event)
            if not event.entity or not event.entity.valid then return end
            notify(event.entity.unit_number)
        end)
    end

    -- Bob's Adjustable Inserters 0.18.0+
    if remote.interfaces["bobinserters"] and remote.interfaces["bobinserters"]["get_changed_position_event_id"] then
        script.on_event(remote.call("bobinserters", "get_changed_position_event_id"), function (event)
            if not event.entity or not event.entity.valid then return end
            notify(event.entity.unit_number)
        end)
    end
end

local library = {
    -- Event Handling
    on_init = function ()
        -- Maps selector ids to their state data. A selector id is the unit_number of the inserter or other entity for drop targets
        -- or its negative unit_number for pickup targets.
        ---@type table<id, selector>
        storage.selectors = {}

        -- A list of selectors that are currently being controlled by a circuit network. Future versions of this mod may use the
        -- value here to permit certain optimizations (such as grouping by network), but for now it is simply assigned a value of
        -- `true`.
        ---@type table<id, any>
        storage.circuit = {}

        -- A list of selectors that are currently without a stable target entity. Future versions of this mod may use the value
        -- here to permit certain optimizations (such as grouping checks by chunk), but for now it is simply assigned a value of
        -- `true`.
        --
        -- If it has no target, this allows us to watch for one in case it shows up, at which point we it would be assigned and
        -- removed from this list.
        --
        -- If its target is a player-controlled vehicle (such as a car), this allows us to check that the target is still here.
        --
        -- These don't necessarily need to be handled *every* tick, but should be frequent enough to at least appear responsive.
        ---@type table<id, any>
        storage.floating = {}

        -- A list of deferred changes to inventory types to be attempted on a later tick.
        --
        -- This avoids potentially deadlocking script-controlled inserters which have their drop target changed after they've already
        -- picked up items to move into their previous target. These don't need to be retried *every* tick, but should be checked
        -- frequently enough to catch the inserter on its next backswing, whenever that may happen (in case it's ends up needing to
        -- wait at the drop target). If still blocked at the drop target, it will simply get reinserted into this list.
        --
        -- For changes in setting that would only increase the availability of drop targets, this shouldn't be necessary, for example,
        -- clearing the drop target when it is currently set to one that is already normally accessible. But this can still get tricky
        -- as in the case of something like the Rocket Silo, which allows inserters to insert most items into a rocket by default, but
        -- rocket part ingredients will only go into the ingredient inventory.
        --
        -- A potential alternative solution, if possible, would be to make use of something like the dump inventory found in some
        -- targets, but not all of them support this. And for those that do, I'm not sure it we can squeeze items into it, since it's
        -- dynamically resized on demand for its existing specific use by the base game (during recipe changes), and this functionality
        -- does not seem to be exposed to mods.
        --
        -- A value of "clear" indicates that the intended setting is nil.
        ---@type table<id, inventory_type | "clear">
        storage.pending = {}

        -- Maps GPS tags to selector tags and event tick to use when upgrading or fast replacing entities.
        ---@type table<string, { tag: selector_tag, tick: MapTick }>
        storage.replacing = {}

        -- Maps unit numbers (or useful_ids in general) of entities to the set of selectors that would care if that entity went
        -- away. We generally don't expect selectors to remove their entries here if they become no longer relevant, as that could
        -- lead to messy edge cases such as when a selector depends on the same entity for multiple reasons and only one of those
        -- reasons goes away. Reference counting could help here, but probably makes this more complicated than it needs to be.
        --
        -- If a selector happens to be notified about an entity having gone away that it no longer cares about, it should simply ignore it.
        --
        -- Most notifications like this should be "final" (such as destruction), but for others that might not be, a selector which
        -- still needs to watch the entity will re-register itself as part of its handling of the event.
        --
        -- Selectors themselves may also become invalidated while waiting, and since we'd rather not also track a list of these
        -- relationships in the opposite direction, we can just silently ignore them when handling a list of mourners.
        ---@type table<integer, table<id, any>>
        storage.mourners = {}

        register_tick_handlers()
        register_custom_handlers()
    end,
    on_load = function ()
        register_tick_handlers()
        register_custom_handlers()
    end,
    ---@type table<defines.events, function>
    events = {
        [defines.events.on_surface_cleared] = function (event)
            limbo[event.surface_index] = nil
        end,
        [defines.events.on_surface_deleted] = function (event)
            limbo[event.surface_index] = nil
        end,
        [defines.events.on_object_destroyed] = on_object_destroyed,
        [defines.events.on_player_rotated_entity] = on_entity_modified,
        [defines.events.on_player_flipped_entity] = on_entity_modified,
        [defines.events.script_raised_teleported] = on_entity_modified,
        [defines.events.on_entity_cloned] = on_entity_settings_pasted,
        [defines.events.on_entity_settings_pasted] = on_entity_settings_pasted,
        [defines.events.on_post_entity_died] = on_post_entity_died,
        [defines.events.on_player_mined_entity] = on_mined_entity,
        [defines.events.on_robot_mined_entity] = on_mined_entity,
        [defines.events.on_space_platform_mined_entity] = on_mined_entity,
        [defines.events.on_built_entity] = on_built_entity,
        [defines.events.on_robot_built_entity] = on_built_entity,
        [defines.events.on_space_platform_built_entity] = on_built_entity,
        [defines.events.script_raised_revive] = on_built_entity,
        [defines.events.on_player_setup_blueprint] = on_player_setup_blueprint,
        [defines.events.on_train_created] = function (event)
            local train = event.train --[[@as LuaTrain?]]
            if not train or not train.valid then return end
            for _, stock in ipairs(train.carriages) do
                notify(stock.unit_number)
            end
            for _, rail in ipairs(train.get_rails()) do
                notify(rail.unit_number)
            end
        end,
        [defines.events.on_train_changed_state] = function (event)
            local train = event.train --[[@as LuaTrain?]]
            if not train or not train.valid then return end
            if train.state == defines.train_state.manual_control or train.state == defines.train_state.wait_station then
                for _, rail in ipairs(train.get_rails()) do
                    notify(rail.unit_number)
                end
            elseif event.old_state == defines.train_state.manual_control or event.old_state == defines.train_state.wait_station then
                for _, stock in ipairs(train.carriages) do
                    notify(stock.unit_number)
                end
            end
        end,
        ---@param event EventData.on_runtime_mod_setting_changed
        [defines.events.on_runtime_mod_setting_changed] = function (event)
            if event.setting_type ~= "runtime-global" then return end

            if event.setting == "inventory-selector-enable-debug" then
                DEBUG = settings.global["inventory-selector-enable-debug"].value --[[@as boolean]]
                return
            end

            if event.setting == "inventory-selector-deadlock-safety" then
                DEADLOCK_SAFETY = settings.global["inventory-selector-deadlock-safety"].value --[[@as "always-immediate" | "allow-unsafe" | "always-safe"]]
                rebind_get_set(DEADLOCK_SAFETY)
            elseif event.setting == "inventory-selector-enable-circuit" then
                ENABLE_CIRCUIT = settings.global["inventory-selector-enable-circuit"].value --[[@as boolean]]
            elseif event.setting == "inventory-selector-pending-retry-ticks" then
                PENDING_RETRY_TICKS = settings.global["inventory-selector-pending-retry-ticks"].value --[[@as integer]]
            elseif event.setting == "inventory-selector-floating-retry-ticks" then
                FLOATING_RETRY_TICKS = settings.global["inventory-selector-floating-retry-ticks"].value --[[@as integer]]
            elseif event.setting == "inventory-selector-update-circuit-ticks" then
                UPDATE_CIRCUIT_TICKS = settings.global["inventory-selector-update-circuit-ticks"].value --[[@as integer]]
            else
                return
            end
            return register_tick_handlers()
        end,
    },

    -- Inventory Selection Control API
    control = {
        get = get,
        set = set,
        get_circuit_mode = get_circuit_mode,
        set_circuit_mode = set_circuit_mode,
        supports_mode = supports_mode,
        can_safely_set = can_safely_set,
        notify = notify,
        debug_get_data = get_data,
    },

    passthrough = {
        ---@see LuaEntity.drop_target
        ---@see LuaEntity.pickup_target
        ---@param entity LuaEntity
        ---@param mode action
        ---@return LuaEntity?
        get_target = function (entity, mode)
            if not supports_mode(entity, mode) then return end
            local data = get_data(entity, mode)
            if not data or not data.actual_inventory_type then return (read_target(entity, mode)) end
            return data.target
        end,

        ---@see LuaEntity.drop_target
        ---@see LuaEntity.pickup_target
        ---@param entity LuaEntity
        ---@param mode action
        set_target = function (entity, mode, target)
            if not supports_mode(entity, mode) then return end
            local data = get_data(entity, mode)
            if not data then return write_target(entity, mode, target) end
            data:update_proxy_target(target)
        end,

        ---@see LuaEntity.drop_position
        ---@see LuaEntity.pickup_position
        ---@param entity LuaEntity
        ---@param mode action
        ---@return MapPosition
        get_position = function (entity, mode)
            local _, position = read_target(entity, mode)
            return position
        end,

        ---@see LuaEntity.drop_position
        ---@see LuaEntity.pickup_position
        ---@param entity LuaEntity
        ---@param mode action
        ---@param position MapPosition
        set_position = function (entity, mode, position)
            if mode == "pickup" then
                entity.pickup_position = position
            elseif mode == "drop" then
                entity.drop_position = position
            else
                error("Invalid mode: " .. mode .. " for entity: " .. entity.name)
            end

            -- Guard against raising our own errors if the original API raised none
            if not supports_mode(entity, mode) then return end

            local data = get_data(entity, mode)
            if data then data:update_proxy_target() end
        end,
    }
}

function library.add_remote_interface()
    remote.add_interface("inventory-selector", library.control)
    remote.add_interface("inventory-selector-passthrough", library.passthrough)
end

return library
