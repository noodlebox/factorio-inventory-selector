-- settings.lua

-- Categories for ordering settings
local core = "a" -- Enable or disable support for various types of machines, runtime-global
local tweaks = "b" -- Tweaks to behavior mainly affecting performance or handling of edge cases, runtime-global
local control = "c" -- Enabled control interfaces, runtime-global
local experimental = "z" -- Extra settings not useful to most players

-- Enable or disable functionality for certain types of machines
data:extend{{
    type = "string-setting",
    name = "inventory-selector-support-entities", -- Enable use with specific machines depending on some other capability of the machine.
    setting_type = "runtime-global",
    default_value = "all",
    allowed_values = {
        "filtered",
        "inserters",
        "all",
    },
    order = core .. "a",
},{
    type = "string-setting",
    name = "inventory-selector-deadlock-safety",
    setting_type = "runtime-global",
    default_value = "allow-unsafe",
    allowed_values = {
        "always-immediate", -- Deadlock mitigation disabled, but always change inventory settings immediately. May cause inserters to become stuck during automated control, requiring player intervention to resolve.
        "allow-unsafe", -- Defer risky changes to inventory settings until safe, but allow callers to override this behavior to change a setting immediately. This is the default behavior.
        "always-safe", -- Always defer changes if risky, even if the caller indicates otherwise. May delay requested settings indefinitely when an inserter is waiting for space in its drop target.
    },
    order = tweaks .. "a",
},{
    type = "int-setting",
    name = "inventory-selector-pending-retry-ticks",
    setting_type = "runtime-global",
    default_value = 4,
    minimum_value = 1,
    maximum_value = 60,
    order = tweaks .. "b",
},{
    type = "int-setting",
    name = "inventory-selector-floating-retry-ticks",
    setting_type = "runtime-global",
    default_value = 12,
    minimum_value = 1,
    maximum_value = 60,
    order = tweaks .. "c",
},{
    type = "int-setting",
    name = "inventory-selector-update-circuit-ticks",
    setting_type = "runtime-global",
    default_value = 1,
    minimum_value = 1,
    maximum_value = 60,
    order = tweaks .. "d",
},{
    type = "bool-setting",
    name = "inventory-selector-enable-gui",
    setting_type = "runtime-global",
    default_value = true, -- Enables the standard configuration panel for these entities to the built-in entity GUI of compatible machines. This allows players to directly configure these settings in the standard way. Disable if using this more as a library, if expecting another mod provide its own control interface or logic, using this mod's remote interface.
    order = control .. "a",
},{
    type = "bool-setting",
    name = "inventory-selector-enable-circuit",
    setting_type = "runtime-global",
    default_value = true, -- Enables the circuit control interface for automatic circuit control of these settings.
    order = control .. "b",
},{
    type = "string-setting",
    name = "inventory-selector-enable-inventory",
    setting_type = "runtime-global",
    default_value = "all",
    allowed_values = {
        "base", -- Restricts access only to inventories already accessible to inserters in the base game (though with greater control and workarounds for certain shortcomings)
        "all", -- Allows access to all inventory slots, including those that may not make sense, such as input into output slots or vice versa.
    },
    order = control .. "c",
},{
    type = "bool-setting",
    name = "inventory-selector-show-all",
    setting_type = "runtime-per-user",
    default_value = false,
    order = control .. "d",
},{
    type = "bool-setting",
    name = "inventory-selector-enable-debug",
    setting_type = "runtime-global",
    default_value = false, -- Enable to skip certain safety checks when not strictly necessary based on current assumptions. Useful for testing those assumptions. Disabled by default for more graceful handling of less-than-perfect interaction with other systems during normal gameplay.
    order = experimental .. "a",
}}
