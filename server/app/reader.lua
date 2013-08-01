--[[

The Reader's job is to read files line-by-line, returning an array of the
specified objects. Because the Reader knows the format of the data, it must also
know how to interpret it. Therefore, the Reader has certain "constructor"
functions like construct_plan for each type of object that needs to be read in.
There's a generic function called construct_objects_from_file which takes a
filename and constructor and applies the constructor to each line of data.

Each object type can have tags associated with it. This is essentially a table
of metadata that can be used by the application to do things like filter data
and group it. The Reader has a generic tag parsing function to handle this. This
means that tag syntax across all objects is the same.

]]--


require('string_utils')
local Plan = require('plan')
local Work = require('work')
local Person = require('person')

local Reader = {}

-- TAG PARSING ----------------------------------------------------------------
--
function Reader.parse_tags(tag_string)
	local result = {}

	if not tag_string then return result end

	-- First split on multiple tags
	tags = tag_string:split(",")
	for _, str in pairs(tags) do
		local tag, value = unpack(str:split(":"))

                -- Try converting value to a number
                local num = tonumber(value)
                if num then value = num end

		result[tag] = value
	end

	return result
end


-- GENERIC OBJECT CONSTRUCTION ------------------------------------------------
--

function construct_objects_from_file(filename, constructor)
	local result = {}
	local file = assert(io.open(filename, "r"))
	local cur_line = 1

	for line in file:lines() do
		-- Skipping first two header lines
		if cur_line > 2 then
			result[#result+1] = constructor(line)
		end
		cur_line = cur_line + 1
	end
	file:close()
	return result
end


-- READING PLAN OBJECTS -------------------------------------------------------
--
function construct_plan(str)
	local id, name, num_weeks, team_id, cutline, work_items_str, tags_str = 
		unpack(str:split("\t"))

        -- Extract work item IDs
	local work_items = {}
	for _, w in pairs(work_items_str:split(",")) do
		work_items[#work_items+1] = w .. ""
	end

        local tags = Reader.parse_tags(tags_str) 

        -- TODO: Calculate default_supply from team info
        local default_supply = {}

	local result = Plan.new{
		id = id,
		name = name,
		num_weeks = num_weeks,
		team_id = team_id,
		work_items = work_items,
                tags = tags,
                default_supply = default_supply,
		cutline = cutline
	}
	return result
end


function Reader.read_plans(filename)
	return construct_objects_from_file(filename, construct_plan)
end


-- READING WORK OBJECTS -------------------------------------------------------
--
function construct_work(str)
	local id, name, estimate_str, triage_str, tags_str =
                                                         unpack(str:split("\t"))

        local estimates = Reader.parse_tags(estimate_str) 
        local triage = Reader.parse_tags(triage_str) 
        local tags = Reader.parse_tags(tags_str)

	local result = Work.new{
		id = id,
		name = name,
                triage = triage,
		estimates = estimates,
                tags = tags
	}
	return result
end

Reader.construct_work = construct_work

function Reader.read_work(filename)
	return construct_objects_from_file(filename, construct_work)
end


-- READING PERSON OBJECTS -----------------------------------------------------
--
function construct_person(str)
	local id, name, skills_str, tags_str = unpack(str:split("\t"))

        local skills = Reader.parse_tags(skills_str) 
        local tags = Reader.parse_tags(tags_str)

	local result = Person.new{
		id = id,
		name = name,
		skills = skills,
                tags = tags
	}
	return result
end

Reader.construct_person = construct_person

function Reader.read_people(filename)
	return construct_objects_from_file(filename, construct_person)
end


return Reader
