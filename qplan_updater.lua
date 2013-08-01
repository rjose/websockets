#!/bin/env lua

local http = require "socket.http"

local null_data = {}
local work_data = {}
local staff_data = {}
local cur_data = null_data

-- This is used to skip header lines in the input
local num_to_skip = 0

-- Split the input stream into work data and staff data
for line in io.lines() do
        if line == "=====Work" then
                cur_data = work_data
                num_to_skip = 2
        elseif line == "=====Staff" then
                cur_data = staff_data
                num_to_skip = 2
        elseif num_to_skip > 0 then
                num_to_skip = num_to_skip - 1
        else
                cur_data[#cur_data+1] = line
        end
end


-- TODO: This should take the host and port from the commandline
-- Send data to qplan server
local work_body = table.concat(work_data, "\n")
local staff_body = table.concat(staff_data, "\n")

local url = "http://localhost:8888"

local response, code
response, code = http.request(url .. "/work_items", work_body)
response, code = http.request(url .. "/assignments", staff_body)
response, code = http.request(url .. "/plan", "")

