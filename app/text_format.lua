Person = require('person')
Plan = require('plan')
Work = require('work')
Reader = require('reader')
Writer = require('writer')
func = require('modules/functional')
Select = require('app/select')

require('string_utils')

-- MODULE INIT ----------------------------------------------------------------
--
local TextFormat = {}


-- REPORTING FUNCTIONS --------------------------------------------------------
--
-- TODO: Add this to a util file
function format_number(num)
        return string.format("%.1f", num)
end

function TextFormat.default_format_work(work_items, plan, staff)
        local tmp = {}
        tmp[#tmp+1] = "Rank\tID\tName\tTags"
	for i = 1,#work_items do
		local w = work_items[i]
		local rank = w.rank or "--"
                tmp[#tmp+1] =
                   string.format("#%-4s\t%3s\t%20s\t%s\t%s", rank, w.id, w.name,
                                 Writer.tags_to_string(w.triage),
                                 Writer.tags_to_string(w.tags))
	end
        return table.concat(tmp, "\n")
end

function TextFormat.default_format_work_hash(work_hash, keys,
                                                      plan, staff, options)
        local options = options or {}
        local total_demand = {}
        local tmp = {}
        local with_detail = not options.without_detail
        local with_net_supply = not options.without_net_supply

        print("Default formatter", options.with_detail, options.with_net_supply)
	for j = 1,#keys do
		local cutline_shown = false
		local key = keys[j]
		local work_items = work_hash[key]

		-- Sum the key items
		local demand = Work.sum_demand(work_items)
		local demand_str = Writer.tags_to_string(
                        func.map_table(format_number,
                                       plan:to_num_people(demand)), ", ")
                total_demand = Work.add_skill_demand(total_demand, demand)

		tmp[#tmp+1] = "== " .. key

                if with_detail then
                        tmp[#tmp+1] =
                 string.format("     %-5s|%-40s|%6s|", "Rank", "Item", "Triage")
                 tmp[#tmp+1] =
                       "     -----|----------------------------------------|" ..
                                                                   "----------|"
                        for i = 1,#work_items do
                                local w = work_items[i]
                                if w.rank > plan.cutline and
                                                     cutline_shown == false then
                                        tmp[#tmp+1] =
                                                "     ----- CUTLINE -----------"
                                        cutline_shown = true
                                end
                                tmp[#tmp+1] =
                                        string.format("     %-5s|%-40s|%-10s|%s",
                                        "#" .. w.rank,
                                        w.name:truncate(40, {["ellipsis"] = true}),
                                        w:merged_triage(),
                                        Writer.tags_to_string(w.estimates, ", "))
                        end
                        tmp[#tmp+1] = "     ---------------------------------"
                end
                tmp[#tmp+1] = string.format("     Required people: %s", demand_str)
                tmp[#tmp+1] = ""
	end

	-- Print overall demand total
        tmp[#tmp+1] = string.format("%-30s %s", "TOTAL Required:",
                             Writer.tags_to_string(
                               func.map_table(format_number, total_demand), ", "
        ))

	
        if with_net_supply then
                -- Print total supply
                local total_bandwidth =
                             Person.sum_bandwidth(staff, plan.num_weeks)
                tmp[#tmp+1] = string.format("%-30s %s", "TOTAL Skill Supply:",
                               Writer.tags_to_string(
                                  func.map_table(format_number,
                                  plan:to_num_people(total_bandwidth)), ", "
                ))

                -- Print net supply
                -- NOTE: This is a hack, but to_num_people has already converted
                -- total_bandwidth and total_demand to num people!
                local net_supply =
                      Work.subtract_skill_demand(total_bandwidth, total_demand);
                tmp[#tmp+1] = string.format("%-30s %s", "TOTAL Net Supply:", 
                        Writer.tags_to_string(
                              func.map_table(format_number, net_supply), ", "))
        end
        return table.concat(tmp, "\n")
end

-- Assuming that work items are in ranked order
function TextFormat.format_rrt(work_items, plan, staff)
        local tmp = {}
        tmp[#tmp+1] = string.format("%-5s|%-15s|%-40s|%-30s|%-30s",
                             "Rank", "Track", "Item", "Estimate", "Supply left")
	tmp[#tmp+1] =
           ("-----|---------------|----------------------------------------|" ..
                    "------------------------------|--------------------------")

	local feasible_line, _, supply_totals =
                      Work.find_feasible_line(work_items, plan.default_supply)
        for k, v in pairs(supply_totals[1]) do
                print(k, v)
        end

	for i = 1,#work_items do
		local w = work_items[i]
                local totals = plan:to_num_people(supply_totals[i])
                totals = func.map_table(format_number, totals)
                tmp[#tmp+1] = string.format("%-5s|%-15s|%-40s|%-30s|%-30s",
                        "#" .. w.rank,
                        w.tags.track:truncate(15),
                        w.name:truncate(40, {["ellipsis"] = true}),
                        Writer.tags_to_string(w.estimates),
                        Writer.tags_to_string(totals)
                        )

		if (w.rank == plan.cutline) and (w.rank == feasible_line) then
			tmp[#tmp+1] = "----- CUTLINE/FEASIBLE LINE -----"
		elseif w.rank == plan.cutline then
			tmp[#tmp+1] = "----- CUTLINE -----------"
		elseif w.rank == feasible_line then
			tmp[#tmp+1] = "----- FEASIBLE LINE -----"
		end
	end

        return table.concat(tmp, "\n")
end

function TextFormat.rde_formatter(demand_hash, triage_tags, plan,
                                                         staff, options)
        local tmp = {}
        options = options or {}
        local skills = options.skills or {"Apps", "Native", "Web"}

        -- Gather all tracks
        local all_tracks = {}
        for _, triage in pairs(triage_tags) do
                all_tracks = func.value_union(all_tracks,
                                func.get_table_keys(demand_hash[triage]))
        end
        all_tracks = func.get_table_keys(all_tracks)

        -- Format data
        for _, tri in ipairs(triage_tags) do
                -- Print track column headings
                local row = {}
                row[#row+1] = string.format("Triage: %s", tri)
                for _, track in ipairs(all_tracks) do
                        row[#row+1] = string.format("%s", track)
                end
                tmp[#tmp+1] = table.concat(row, "\t")

                for _, skill in ipairs(skills) do
                        local row = {}
                        row[#row+1] = string.format("%s", skill)
                        for _, track in ipairs(all_tracks) do
                                local val = 0
                                if demand_hash[tri][track] then
                                        val = demand_hash[tri][track][skill] or 0
                                end
                                
                                row[#row+1] = string.format("%.1f", val)
                        end
                        tmp[#tmp+1] = table.concat(row, "\t")
                end
		tmp[#tmp+1] = ""
        end

        return table.concat(tmp, "\n")
end

function TextFormat.format_people_bandwidth(staff, plan)
        local tmp = {}
        local total_bandwidth = Person.sum_bandwidth(staff, plan.num_weeks)
        tmp[#tmp+1] = string.format("TOTAL Skill Supply: %s",
               Writer.tags_to_string(plan:to_num_people(total_bandwidth), ", "))

        return table.concat(tmp, "\n")
end

function TextFormat.format_people_hash(people_hash, groups, plan, staff)
        local tmp = {}
        for i = 1,#groups do
                local group = groups[i]
                local people_list = people_hash[group]
                tmp[#tmp+1] = string.format("%s ==", group)
                for j = 1,#people_list do
                        tmp[#tmp+1] = string.format("     %3d. %-30s %s",
                                j, people_list[j].name,
                                Writer.tags_to_string(people_list[j].skills))
                end
        end

        local total_bandwidth = Person.sum_bandwidth(staff, plan.num_weeks)
        tmp[#tmp+1] = string.format("TOTAL Skill Supply: %s",
               Writer.tags_to_string(plan:to_num_people(total_bandwidth), ", "))

        return table.concat(tmp, "\n")
end




return TextFormat
