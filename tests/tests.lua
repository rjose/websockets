package.path = package.path .. ";../?.lua"

local LuaUnit = require('luaunit')

require('test_person')
require('test_select')
require('test_work')
require('test_plan')
require('test_read')
require('test_write')

-- Shell functions
-- require('test_triage')
-- require('test_reports')

LuaUnit:run()
