--[[

Work is something that needs to be done as part of a project or plan. Work is
not a specific task for one person; it's a higher level estimate of a feature
that may require multiple skills. Likewise, there is no assignment to any
person. That will be done as part of dev cycle planning.

Estimates for work items are specified using T-shirt sizing: S, M, L, Q.  These
correspond to 1w, 2w, 3w, and 13w tasks, respectively. An optional scaling
integer may precede these estimates. For instance, "4S" would mean a 4 week
effort. The presence of a scale factor sometimes implies multiple people's
effort (e.g., 3S might mean 1 week each of Android, iOS, and mobile web). There
is no space between the factor and the estimate label. Each estimate is
specified as part of a skills table. For example: {["Native"] = "L", ["Apps"] =
"2S"}.

Estimates can be converted to weeks of effort using *get_skill_demand*. The
total demand for an array of work items can be computd using *sum_demand*.  To
get running demand totals for an array of work items, use *running_demand*.

Work often needs to be categorized into different groups. This is handled
through our "tag" mechanism. For instance, to set the track for a work item w1,
we'd do 'w1.tags.track = "money"'. To set the triage group, we'd do
'w1.tags.priority = 1'.

]]--

local Object = require('object')
local func = require('functional')

local Work = {}
Work._new = Object._new

function Work.new(options)
	id = options.id or ""
        triage = options.triage or {}
	estimates = options.estimates or {}
        name = options.name or ""
	tags = options.tags or {}

	return Work:_new{id = id .. "",
                         name = name,
	                 estimates = estimates,
	                 triage = triage,
                         tags = tags}
end


function Work:set_estimate(skill_name, estimate_string)
	-- Validate estimate string
	if Work.translate_estimate(estimate_string) == 0 then
		return
	end

 	self.estimates[skill_name] = estimate_string
end

-- HELPER FUNCTIONS -----------------------------------------------------------
-- 

-- This is a helper function that essentially maps "get_id" over a set of work
-- items. This is necessary when we need to work with actual work IDs rather
-- than work rankings.
function Work.get_ids(work_items)
	local result = {}
	for i = 1,#work_items do
		result[#result+1] = work_items[i].id
	end
	return result
end



-- TRIAGING FUNCTIONS ---------------------------------------------------------
--

function Work.triage_filter(triage_value, work_item)
        return work_item:merged_triage() == triage_value
end

-- This is used to select select items that are 1-1.5, 2-2.5, etc.
function Work.triage_xx_filter(triage_value, work_item)
        local triage = work_item:merged_triage()

        if type(triage) ~= "number" then
                return false
        end

        return triage >= triage_value and triage < triage_value + 1
end


-- If triage_tag is not specified, this sets the "Triage" field in triage
function Work:set_triage(val, triage_tag)
        triage_tag = triage_tag or "Triage"
        self.triage[triage_tag] = val
end

-- Returns the merged triage across all fields. We take the highest priority
-- across all of the triage fields. Setting "Triage" overrides all other
-- values.
function Work:merged_triage()
        if self.triage.Triage then
                return self.triage.Triage
        end

        local min = 100

        for k, val in pairs(self.triage) do
                print(k, val)
                if val < min then
                        min = val
                end
        end
        print("merged_triage", min)
        if min == 100 then min = nil end

        return min
end


-- PARSE ESTIMATES ------------------------------------------------------------
--

-- This converts a T-shirt estimate label into a number of weeks
function Work.translate_estimate(est_string)
        local scalar = 1
        local unit
        local units = {["S"] = 1, ["M"] = 2, ["L"] = 3, ["Q"] = 13}

        -- Look for something like "4L"
        for u, _ in pairs(units) do
                scalar, unit = string.match(est_string, "^(%d*)(" .. u .. ")")
                if unit then break end
        end

        -- If couldn't find a unit, then return 0
        if unit == nil then
                -- io.stderr:write(string.format("Unable to parse: %s\n", est_string))
                return 0
        end

        -- If couldn't find a scalar, it's 1
        if scalar == "" then scalar = 1 end

        return scalar * units[unit]
end

-- This converts the estimat table for a work item into a table with week
-- estimates as values.
function Work:get_skill_demand()
        local result = {}
        for skill, est_str in pairs(self.estimates) do
                result[skill] = Work.translate_estimate(est_str)
        end
        return result
end


-- SUMMING SKILL DEMAND -------------------------------------------------------
--

-- Adds two skill demand tables together
function Work.add_skill_demand(skill_demand1, skill_demand2)
	return func.apply_keywise_2(func.add, skill_demand1, skill_demand2)
end

-- Subtracts skill_demand2 from skill_demand1
function Work.subtract_skill_demand(skill_demand1, skill_demand2)
	return func.apply_keywise_2(func.subtract, skill_demand1, skill_demand2)
end


-- Sums the skill demand for an array of work items. Returns the running
-- totals as a second result.
function Work.sum_demand(work_items)
	local running_demand = Work.running_demand(work_items)
	return running_demand[#running_demand], running_demand
end

-- Computes the running demand totals for an array of work items.
function Work.running_demand(work_items)

        -- "map" get_skill_demand over work_items
        local skill_demand = {}
	for i = 1,#work_items do
                skill_demand[#skill_demand+1] = work_items[i]:get_skill_demand()
	end

        -- Compute running totals
        local result = {}
        local cur_total = {}

	for i = 1,#skill_demand do
                cur_total = Work.add_skill_demand(cur_total, skill_demand[i])
                result[#result+1] = cur_total
	end

        return result
end


return Work
