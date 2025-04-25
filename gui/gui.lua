local inventory = require("__inventory-selector__/api/inventory")
local selector = require("__inventory-selector__/api/selector")
local passthrough = require("__inventory-selector__/api/passthrough")

local ENABLE_GUI = settings.global["inventory-selector-enable-gui"].value --[[@as boolean]]
local ENABLE_CIRCUIT = settings.global["inventory-selector-enable-circuit"].value --[[@as boolean]]
local ENABLE_ENTITIES = settings.global["inventory-selector-support-entities"].value --[[@as "filtered" | "inserters" | "all"]]
local ENABLE_INVENTORIES = settings.global["inventory-selector-enable-inventory"].value --[[@as "base" | "all"]]

-- A mapping of entity types (supporting drop_position and/or pickup_position) to the relative GUI type used for the inventory selector anchor.
-- Inserters are obvious here, though entities supporting `vector_to_place_result` are also supported.
---@type table<string, defines.relative_gui_type>
local relative_gui_for_entity_type = {
    ["inserter"] = defines.relative_gui_type.inserter_gui,
    ["assembling-machine"] = defines.relative_gui_type.assembling_machine_gui,
    ["furnace"] = defines.relative_gui_type.furnace_gui,
    ["mining-drill"] = defines.relative_gui_type.mining_drill_gui,
}

local function destroy_on(parent)
    -- If any of these GUIs are already open, destroy them so they can be recreated
    if parent["inventory-selector"] then
        parent["inventory-selector"].destroy()
    end
    if parent["inventory-selector-circuit"] then
        parent["inventory-selector-circuit"].destroy()
    end
end

---@param parent LuaGuiElement
---@param anchor? GuiAnchor
local function render_on(parent, anchor)
    destroy_on(parent)
    if not ENABLE_GUI then return end

    local player = game.get_player(parent.player_index)
    if not player or not player.valid then return end
    local entity = player.opened --[[@as LuaEntity]]

    if ENABLE_ENTITIES ~= "all" and entity.type ~= "inserter" then return end
    if ENABLE_ENTITIES == "filtered" and entity.prototype.filter_count == 0 then return end

    local drop_supported = selector.supports_mode(entity, "drop")
    local pickup_supported = selector.supports_mode(entity, "pickup")
    if not drop_supported and not pickup_supported then return end

    -- Load existing inventory selections for this entity, if any
    local drop_inventory = drop_supported and selector.get(entity, "drop", true) or nil
    local pickup_inventory = pickup_supported and selector.get(entity, "pickup", true) or nil

    -- Get the apparent targets of the entity
    local drop_target = drop_supported and passthrough.get_target(entity, "drop") or nil
    local pickup_target = pickup_supported and passthrough.get_target(entity, "pickup") or nil

    local circuit_red = entity.get_circuit_network(defines.wire_connector_id.circuit_red)
    local circuit_green = entity.get_circuit_network(defines.wire_connector_id.circuit_green)
    local circuit_connected = not not (circuit_red or circuit_green) and ENABLE_CIRCUIT

    local circuit_set_drop = drop_supported and ENABLE_CIRCUIT and selector.get_circuit_mode(entity, "drop")
    local circuit_set_pickup = pickup_supported and ENABLE_CIRCUIT and selector.get_circuit_mode(entity, "pickup")

    local check_valid = not player.mod_settings["inventory-selector-show-all"].value --[[@as boolean]]

    local content = parent.add{
        anchor = anchor,
        type = "frame",
        name = "inventory-selector",
        caption = {"inventory-selector-gui.title"},
        direction = "vertical",
    }.add{
        type = "frame",
        name = "content",
        style = "inside_shallow_frame_with_padding_and_vertical_spacing",
        direction = "vertical",
    }

    if pickup_supported then
        local circuit_override = circuit_connected and circuit_set_pickup

        content.add{
            type = "checkbox",
            name = "inventory-selector-pickup-enabled",
            style = "caption_checkbox",
            caption = {"inventory-selector-gui.pickup-enabled"},
            tooltip = {"inventory-selector-gui.pickup-enabled-tooltip"},
            state = circuit_override or not not pickup_inventory,
            enabled = not circuit_override,
        }.tags = { mode = "pickup", action = "enable" }

        local items = inventory.get_inventories(pickup_target, { access_mode="output", check_valid=pickup_target and check_valid or false, hide_zero_size=false, hide_inaccessible=ENABLE_INVENTORIES~="all" })
        for i, item in ipairs(items) do
            items[i] = "inventory-selector-inventory-" .. item
        end
        content.add{
            type = "choose-elem-button",
            name = "inventory-selector-pickup-inventory",
            elem_type = "item", -- Using "item" instead of "signal", as "signal" does not support filtering here
            elem_filters = { { filter="name", name=items }, { filter="subgroup", subgroup="inventory-selector-inventory", mode="and" } },
            item = pickup_inventory and "inventory-selector-inventory-" .. pickup_inventory,
            elem_tooltip = pickup_inventory and { type="item", name="inventory-selector-inventory-" .. pickup_inventory },
            locked = circuit_override or pickup_inventory == nil,
            enabled = not circuit_override and pickup_inventory ~= nil,
        }.tags = { mode = "pickup", action = "inventory" }
    end

    if pickup_supported and drop_supported then
        content.add{
            type = "line",
            direction = "horizontal",
            style = "inside_shallow_frame_with_padding_line",
        }
    end

    if drop_supported then
        local circuit_override = circuit_connected and circuit_set_drop

        content.add{
            type = "checkbox",
            name = "inventory-selector-drop-enabled",
            style = "caption_checkbox",
            caption = {"inventory-selector-gui.drop-enabled"},
            tooltip = {"inventory-selector-gui.drop-enabled-tooltip"},
            state = circuit_override or not not drop_inventory,
            enabled = not circuit_override,
        }.tags = { mode = "drop", action = "enable" }

        local items = inventory.get_inventories(drop_target, { access_mode="input", check_valid=drop_target and check_valid or false, hide_zero_size=check_valid, hide_inaccessible=ENABLE_INVENTORIES~="all" })
        for i, item in ipairs(items) do
            items[i] = "inventory-selector-inventory-" .. item
        end
        content.add{
            type = "choose-elem-button",
            name = "inventory-selector-drop-inventory",
            elem_type = "item", -- Using "item" instead of "signal", as "signal" does not support filtering here
            elem_filters = { { filter="name", name=items }, { filter="subgroup", subgroup="inventory-selector-inventory", mode="and" } },
            item = drop_inventory and "inventory-selector-inventory-" .. drop_inventory,
            elem_tooltip = drop_inventory and { type="item", name="inventory-selector-inventory-" .. drop_inventory },
            locked = circuit_override or drop_inventory == nil,
            enabled = not circuit_override and drop_inventory ~= nil,
        }.tags = { mode = "drop", action = "inventory" }
    end

    if ENABLE_CIRCUIT then
        local circuit_content = parent.add{
            anchor = anchor,
            type = "frame",
            name = "inventory-selector-circuit",
            caption = {"gui-control-behavior.circuit-connection"},
            direction = "vertical",
        }.add{
            type = "frame",
            name = "content",
            style = "inside_shallow_frame",
            direction = "vertical",
        }

        local header = circuit_content.add{
            type = "frame",
            name = "header",
            style = "subheader_frame",
            direction = "horizontal",
        }.add{
            type = "flow",
            name = "header-flow",
            style = "frame_header_flow", -- FIXME: Adds some unwanted bottom padding, but ensures contents stretch to width. Should implement a custom style.
            direction = "horizontal",
        }

        local body = circuit_content.add{
            type = "frame",
            name = "body",
            style = "inside_shallow_frame_with_padding_and_vertical_spacing",
            direction = "vertical",
        }

        local caption = circuit_connected and { "", {"gui-control-behavior.connected-to-network"} } or {"gui-control-behavior.not-connected"}
        if circuit_red then
            table.insert(caption, " ")
            table.insert(caption, { "gui-control-behavior.red-network-id", circuit_red.network_id })
        end
        if circuit_green then
            table.insert(caption, " ")
            table.insert(caption, { "gui-control-behavior.green-network-id", circuit_green.network_id })
        end
        header.add{
            type = "label",
            name = "inventory-selector-circuit-status",
            style = "subheader_label",
            caption = caption,
        }

        if pickup_supported then
            body.add{
                type = "checkbox",
                name = "inventory-selector-circuit-set-pickup",
                style = "caption_checkbox",
                caption = {"inventory-selector-gui.circuit-set-pickup"},
                tooltip = {"inventory-selector-gui.circuit-set-pickup-tooltip"},
                state = circuit_set_pickup,
                enabled = circuit_connected,
            }.tags = { mode = "pickup", action = "circuit_set" }
        end
        if pickup_supported and drop_supported then
            body.add{
                type = "line",
                direction = "horizontal",
                style = "inside_shallow_frame_with_padding_line",
            }
        end
        if drop_supported then
            body.add{
                type = "checkbox",
                name = "inventory-selector-circuit-set-drop",
                style = "caption_checkbox",
                caption = {"inventory-selector-gui.circuit-set-drop"},
                tooltip = {"inventory-selector-gui.circuit-set-drop-tooltip"},
                state = circuit_set_drop,
                enabled = circuit_connected,
            }.tags = { mode = "drop", action = "circuit_set" }
        end
    end
end

---@param event EventData.on_gui_opened
local function on_gui_opened(event)
    ---@type LuaPlayer?
    local player = game.get_player(event.player_index)
    if not player then return end

    if event.gui_type == defines.gui_type.entity then
        local parent = player.gui.relative
        local entity = event.entity
        if not entity or not entity.valid then return destroy_on(parent) end

        local entity_type = entity.type
        if entity_type == "entity-ghost" then entity_type = entity.ghost_type end
        local gui = relative_gui_for_entity_type[entity_type]
        if not gui then return destroy_on(parent) end
        return render_on(parent, { gui = gui, position = defines.relative_gui_position.right })
    elseif event.gui_type == defines.gui_type.custom then
        -- TODO: Handle custom inserter GUIs
        return -- For now, do nothing
    else
        return
    end
end

---@param event EventData.on_gui_checked_state_changed
local function on_gui_checked_state_changed(event)
    local element = event.element
    local tags = element.tags --[[@as { mode: action, action: string }?]]
    if element.get_mod() ~= "inventory-selector" or not tags then return end
    local player = game.get_player(event.player_index) --[[@as LuaPlayer]]
    if not player or not player.valid then return end
    local entity = player.opened --[[@as LuaEntity]]
    if not entity or not entity.valid then return end

    if tags.action == "enable" then
        selector.set(entity, tags.mode, event.element.state and "none" or nil, true)
    elseif tags.action == "circuit_set" then
        selector.set_circuit_mode(entity, tags.mode, event.element.state)
    end

    local entity_type = entity.type
    if entity_type == "entity-ghost" then entity_type = entity.ghost_type end
    local gui = relative_gui_for_entity_type[entity_type]

    return render_on(player.gui.relative, { gui = gui, position = defines.relative_gui_position.right })
end

---@param event EventData.on_gui_elem_changed
local function on_gui_elem_changed(event)
    local element = event.element
    local tags = element.tags --[[@as { mode: action }?]]
    if element.get_mod() ~= "inventory-selector" or not tags then return end
    local player = game.get_player(event.player_index) --[[@as LuaPlayer]]
    if not player or not player.valid then return end
    local entity = player.opened --[[@as LuaEntity]]
    if not entity or not entity.valid then return end

    -- Get the selected inventory name
    local elem = event.element.elem_value --[[@as string?]]
    local name = select(3, string.find(elem or "", "^inventory%-selector%-inventory%-([_%a]+)$")) or "none"

    selector.set(entity, tags.mode, name, true)

    local entity_type = entity.type
    if entity_type == "entity-ghost" then entity_type = entity.ghost_type end
    local gui = relative_gui_for_entity_type[entity_type]

    return render_on(player.gui.relative, { gui = gui, position = defines.relative_gui_position.right })
end

-- TODO: Need to watch for externally triggered changes to the entity shown in the open GUI

return {
    events = {
        [defines.events.on_gui_opened] = on_gui_opened,
        [defines.events.on_gui_checked_state_changed] = on_gui_checked_state_changed,
        [defines.events.on_gui_elem_changed] = on_gui_elem_changed,
        [defines.events.on_runtime_mod_setting_changed] = function (event)
            if event.setting_type ~= "runtime-global" then return end

            if event.setting == "inventory-selector-enable-gui" then
                ENABLE_GUI = settings.global["inventory-selector-enable-gui"].value --[[@as boolean]]
            elseif event.setting == "inventory-selector-enable-circuit" then
                ENABLE_CIRCUIT = settings.global["inventory-selector-enable-circuit"].value --[[@as boolean]]
            elseif event.setting == "inventory-selector-support-entities" then
                ENABLE_ENTITIES = settings.global["inventory-selector-support-entities"].value --[[@as "filtered" | "inserters" | "all"]]
            elseif event.setting == "inventory-selector-enable-inventory" then
                ENABLE_INVENTORIES = settings.global["inventory-selector-enable-inventory"].value --[[@as "base" | "all"]]
            end
            for _, player in pairs(game.players) do
                if player.valid and player.opened_gui_type == defines.gui_type.entity then
                    local entity = player.opened --[[@as LuaEntity]]
                    local entity_type = entity and entity.valid and entity.type
                    if entity_type == "entity-ghost" then entity_type = entity.ghost_type end
                    local gui = relative_gui_for_entity_type[entity_type]
                    if gui then
                        render_on(player.gui.relative, { gui = gui, position = defines.relative_gui_position.right })
                    end
                end
            end
        end,
    },
}
