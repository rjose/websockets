--[[

The Writer's job is to serialize a set of objects out to disk in a format that
can be read by the Reader. Nothing too fancy here. The only interesting work is
writing out the tags tables and the skills tables. Since they have the same
format, they go through the same code.

]]--


local string_utils = require('string_utils')
local func = require('functional')

local Writer = {}


-- TAG SERIALIZATION ----------------------------------------------------------
--


function tags_to_string(tags, sep)
        if not tags then
                return ""
        end

	sep = sep or ","

	local keys = func.get_table_keys(tags)
	table.sort(keys)


        local result = ""
	for _, key in ipairs(keys) do
                result = result .. string.format("%s:%s" .. sep, key, tags[key])
        end

        -- Strip trailing comma
        return result:sub(1, -(1 + string.len(sep)))
end
Writer.tags_to_string = tags_to_string

-- SERIALIZING PLANS AND WORK -------------------------------------------------
--

function Writer.write_plans(plans, filename)
	local file = assert(io.open(filename, "w"))

	-- Write headers first
	file:write("ID\tName\tNumWeeks\tTeamID\tCutline\tWorkItems\tTags\n")
	file:write("-----\n")

	-- Write plans next
	for _, plan in pairs(plans) do
		file:write(string.format("%s\t%s\t%d\t%s\t%d\t%s\t%s\n", 
			plan.id,
                        plan.name,
                        plan.num_weeks,
                        plan.team_id,
			plan.cutline,
                        string_utils.join(plan.work_items, ","),
                        tags_to_string(plan.tags)
		))
	end
	file:close()
end

function Writer.write_work(work_items, filename)
	local file = assert(io.open(filename, "w"))

	-- Write headers first
	file:write("ID\tName\tTrack\tTags\n")
	file:write("-----\n")

	-- Write work next
	for _, w in pairs(work_items) do
		file:write(string.format("%s\t%s\t%s\t%s\n", 
			w.id,
                        w.name,
                        tags_to_string(w.estimates),
                        tags_to_string(w.tags)
		))
	end
	file:close()
end


return Writer
