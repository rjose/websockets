local Work = require('work')
local func = require('modules/functional')
local json = require('json')

local JsonFormat = {}

-- TODO: Add this to a util file
function format_number(num)
        return string.format("%.1f", num)
end

function JsonFormat.format_work_by_group(work_hash, keys, plan, staff, options)
        local object = {}
        object.groups = keys
        object.work_hash = work_hash
        object.cutline = plan.cutline

        return json.encode(object)
end

function JsonFormat.format_rrt(work_items, plan, staff)
	local feasible_line, _, supply_totals =
                      Work.find_feasible_line(work_items, plan.default_supply)
        local object = {}
        object.work = work_items
        object.feasible_line = feasible_line
        object.cutline = plan.cutline

        -- Compute net totals
        object.net_totals = {}
        for i, t in ipairs(supply_totals) do
                object.net_totals[i] =
                      func.map_table(format_number,
                                     plan:to_num_people(supply_totals[i],
                                                        plan.num_weeks))
        end

        return json.encode(object)
end

function JsonFormat.format_people_hash(people_hash, groups, plan, staff)
        local num_weeks = plan.num_weeks

        local object = {}
        object.groups = groups
        object.people_hash = people_hash

        -- Compute bandwidth
        object.bandwidth = plan:to_num_people(
                              Person.sum_bandwidth(staff, num_weeks), num_weeks)
        
        return json.encode(object)
end

return JsonFormat
