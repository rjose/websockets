--[[

A Plan is used to figure out how much work a team can commit to. A Plan has
access to information about relevant Work items and maintains information about
the relative priority of each work item. This is stored in the work_items field,
which is a ranked list of work IDs. A Plan also has a cutline that separates the
list into things that will be committed to and things that won't be.

A Plan provides an array of work items in priority order via get_work_items. We
pass an options table to this function to filter the selected work items. For
instance, by passing in {["ABOVE_CUT" = 1}, we select work that's above the
cutline. This is a convention we follow for all types of selections.

An important feature of Plans is that they enable us to re-rank items. We rank
items by specifying an array of work IDs (not necessarily contiguous) and a
position that the first item should start at. By default, items are placed at
the top of the list. The rest of the list maintains its relative order.

Another feature of Plans is that they can compute running demand totals (by
skill) and net supply totals (also by skill). The demand totals are presented in
the work item ranking order. This information can be used to determine if a plan
is feasible (i.e., the net supply of items above the cutline is >= 0 for all
skills). This can also be used to determine the "feasible line" -- the lowest
feasible cutline.

]]--


local func = require('functional')
local Work = require('work')

local Object = require('object')

local Plan = {}
Plan._new = Object._new

-- A Plan maintains a ranked list of work items in work_items. The
-- work_table field is a pointer to a Work database where info about each item
-- can be looked up.
--
-- The default timespan of a plan is 13 weeks (i.e., a quarter). The number of
-- weeks and the team set the "default supply" of skills. For now, the
-- default_supply is pre-computed, but this could be updated when the team or
-- the number of weeks changed.
function Plan.new(options)
	id = options.id or ""
	name = options.name or ""
	num_weeks = num_weeks or 13 	-- Default to a quarter
	team_id = options.team_id or ""
	work_items = options.work_items or {}
	cutline = options.cutline or 1
        work_table = options.work_table or {}
        default_supply = options.default_supply or {}
        tags = options.tags or {}

	return Plan:_new{
                id = id .. "",
                name = name,
                num_weeks = num_weeks,
	        cutline = cutline + 0,
                work_items = work_items,
                team_id = team_id .. "",
                default_supply = default_supply,
                tags = tags,
                work_table = work_table
        }
end

-- SELECTING WORK ITEMS -------------------------------------------------------
--

function is_any(work_item)
	return true
end

-- By default, this returns _all_ of the work items of a plan. These are actual
-- work item objects. Passing in options enables filtering of the work items.
-- Here are the available options:
--
--      ABOVE_CUT: If set to truthy value, only work above the cutline will be
--      returned
--
function Plan:get_work_items(options)
	local work_ids = self.work_items or {}
	local result = {}
        options = options or {}

        local stop_index = #work_ids
        
        -- If specified, return work items above the cutline
        if options.ABOVE_CUT then
                stop_index = self.cutline
        end

	-- Specify filter
	local filter
	if options.filter then
		filter = options.filter
	else
		filter = is_any
	end

        for i = 1, stop_index do
		local w = self.work_table[work_ids[i]]
		if filter(w) then
			w.rank = i
			result[#result+1] = w
		end
        end

	return result
end

function Plan:get_work(rank)
	if rank > #self.work_items then
		io.stderr:write(string.format("%d out of range 1-%d\n", rank, #pl.work_items))
		return
	end

	local result = self.work_table[self.work_items[rank]]
	return result
end

function Plan:get_work_array(rank_array)
	local result = {}
	for _, rank in ipairs(rank_array) do
		local w = self:get_work(rank)
		if w ~= nil then
			w.rank = rank
			result[#result+1] = w
		end
	end
	return result
end


-- COMPUTE RUNNING TOTALS -----------------------------------------------------
--

-- This returns the demand total (by skill) associated with an array of work
-- items. The options passed into this function will be used as per
-- get_work_items to generate this array.
--
-- The second result is the running demand totals, one per work item.
function Plan:get_demand_totals(options)
        local work_items = self:get_work_items(options)
        return Work.sum_demand(work_items)
end

-- This returns the net supply total (by skill) associated with an array of work
-- items and the default skill supply. The options passed into this function
-- will be used as per get_work_items to generate this array.
--
-- The first result is the total net supply, the second is the running net
-- supply totals, and the third is the running net demand totals. The running
-- totals are per work item.
function Plan:get_supply_totals(options)
        local demand_total, running_demand = self:get_demand_totals(options)

        local running_supply = {}
	for i = 1,#running_demand do
		running_supply[#running_supply+1] = Work.subtract_skill_demand(
                        self.default_supply,
                        running_demand[i]
                )
	end

	return running_supply[#running_supply], running_supply, running_demand
end


-- PRIORITIZING WORK ----------------------------------------------------------
--

-- This is a helper function used to convert an options table into a position
-- in a ranked work list. The following options are supported:
--
--      at: The specified number is the position of interest.
--
function position_from_options(options)
	local result = 1
	if options == nil then
		return result
	end

	if type(options.at) == "number" then
		result = options.at
	end

	return result
end


-- This takes an array of work ids (input_items) and an options hash that is
-- used per position_from_options to determine a position to place input_items.
-- In the resulting work items list, the input items will appear in contiguous
-- order starting at the determined position. Any items in input_items not in
-- the work_items list will be ignored.
function Plan:rank(input_items, options)
        -- Make sure item elements are all strings and then add them to an
        -- input_set so we can look them up.
	local input_set = {}
	for i = 1,#input_items do
		input_items[i] = input_items[i] .. ""
		input_set[input_items[i]] = true
	end

        -- Separate work items into unchanged and changed items.  We're
        -- iterating over the self.work_items and checking against the input_set
        -- so we can filter out garbage.
	local unchanged_array = {}
	local changed_set = {}
	for rank, id in pairs(self.work_items) do
		if input_set[id] then
			changed_set[id] = true
		else
			unchanged_array[#unchanged_array+1] = id
		end
	end

	-- Put changed items back in order they were specified
	local changed_array = {}
        for i = 1,#input_items do
                local id = input_items[i]
		if changed_set[id] then
			changed_array[#changed_array+1] = id
		end
        end

        -- Insert the ranked items into position
	local position = position_from_options(options)
        local front, back = func.split_at(position-1, unchanged_array)
        self.work_items = func.concat(front, changed_array, back)
end


-- PLAN FEASIBILITY -----------------------------------------------------------
--

-- This is a helper function used to check if any skill values are < 0. Such a
-- case implies an infeasible plan.
function is_any_skill_negative(skills)
	local result = false
	for skill, avail in pairs(skills) do
		if avail < 0 then
			result = true
			break
		end
	end
	return result
end

-- Checks if the cutline and the associated skill supply result in a feasible
-- plan.
function Plan:is_feasible()
	local net_supply = self:get_supply_totals({["ABOVE_CUT"] = 1})
	local is_feasible = not is_any_skill_negative(net_supply)
	return is_feasible, net_supply
end


-- Given a default supply and a set of work, this finds the lowest cutline for
-- which the plan is feasible.
function Plan:find_feasible_line()
	local work_items = self:get_work_items()
	local feasible_line = #work_items

	local _, running_supply, running_demand = self:get_supply_totals()

	for i = 1,#running_supply do
		if is_any_skill_negative(running_supply[i]) then
			feasible_line = i - 1
			break
		end
	end

	return feasible_line, running_demand, running_supply
end


return Plan
