package.path = package.path .. ";app/?.lua;modules/?.lua"

local Data = require('app/data')

-- NOTE: This has to be global so our C request handler can access it
WebUI = require('app/web_ui')
require('app/lua_ui')

-- TODO: Add cls_ui


function qplan_init(version)
        -- NOTE: These are global so we can use the lua_ui functions
        plan, staff = Data.load_data(version)
        WebUI.init(plan, staff)
end
