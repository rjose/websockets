--[[

A Person has skills that can be applied to do work. Each person has a certain
amount of bandwidth for work. The bandwidth for a team is the sum of the
bandwidth for individuals. 

A Person can have multiple skills. Their default skill distribution is
specified in the skills table. This distribution may be overridden in a Plan.
The skill distribution may also be optimized to maximize the amount of work
that can be taken on by a team.

]]--

local Object = require('object')

local Person = {}
Person._new = Object._new

function Person.new(options)
	id = options.id or ""
        name = options.name or ""
        skills = options.skills or {}
        tags = options.tags or {}

	return Person:_new{
		id = id .. "", name = name, skills = skills, tags = tags
	}
end

-- Basically takes a person's skill distribution and multiplies it by the
-- number of weeks available.
function Person:get_bandwidth(num_weeks)
	local result = {}
	for skill, frac in pairs(self.skills) do
		result[skill] = frac * num_weeks
	end
	return result
end

-- Takes two bandwidth items and adds them together.
function add_bandwidth(b1, b2)
	local result = {}
	for k, v in pairs(b1) do result[k] = v end

        for skill, avail in pairs(b2) do
                if result[skill] then
			result[skill] = result[skill] + avail
                else
                        result[skill] = avail
                end
        end
        return result
end


-- This takes an array of people and the number of weeks over which we're
-- interested in their bandwidth. This returns a table of skills to weeks
-- available for that skill. E.g., {["Apps"] = 13}
function Person.sum_bandwidth(people, num_weeks)
	local result = {}
	for i = 1,#people do
		result = add_bandwidth(result, people[i]:get_bandwidth(num_weeks))
	end
	return result
end


return Person
