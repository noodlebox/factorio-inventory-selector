local handler = require("__core__.lualib.event_handler")

handler.add_libraries({
    require("script.inventory"),
    require("script.selector"),
    require("gui.gui"),
})
