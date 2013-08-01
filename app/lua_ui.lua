-- Usage: lua -i shell.lua [version]
-- The "version" refers to the save version

package.path = package.path .. ";app/?.lua;modules/?.lua"

TextFormat = require('app/text_format')
Data = require('app/data')
func = require('modules/functional')

-- STARTUP --------------------------------------------------------------------
--
-- If we load this from a lua interpreter, arg will be set and we'll proced to
-- load the qplan data and set things up. Otherwise, this will have been loaded
-- by some other process which should set up the global "plan" and "staff"
-- variables.

arg = arg or {}
version = arg[1]

if version then
        print("Loading version: " .. version)
        plan, staff = Data.load_data(version)
        print("READY")
end


-- ALIASES --------------------------------------------------------------------
--
p = print
export = Data.export
wrd = Data.wrd


-- CANNED REPORTS -------------------------------------------------------------
--
function w()
        -- Select work items
        local work_items = Select.all_work(plan)

        -- Format work items
        local result_string =
                         TextFormat.default_format_work(work_items, plan, staff)

        -- Print result
        print(result_string)
end

function wac()
        -- Select work items
        local work_items = Select.all_work(plan)

        -- Filter work items
        local above_cutline_filter = Select.make_above_cutline_filter(plan)
        work_items = Select.apply_filters(work_items, {above_cutline_filter})

        -- Format work items
        local result_string =
                         TextFormat.default_format_work(work_items, plan, staff)

        -- Print result
        print(result_string)
end

function rrt()
        -- Select work items
        local work_items = Select.all_work(plan)

        -- Format work items
        local result_string = TextFormat.format_rrt(work_items, plan, staff)

        -- Print result
        print(result_string)
end

function rbt(t, triage)
        -- Select work items
        local work_items = Select.all_work(plan)

        -- Filter items
        local filters = Select.get_track_and_triage_filters(t, triage)
        work_items = Select.apply_filters(work_items, filters)

        -- Group items
        local work_hash, tracks = Select.group_by_track(work_items)

        -- Format result items
        local result_string =
             TextFormat.default_format_work_hash(work_hash, tracks, plan, staff)
        
        -- Print result
        print(result_string)
end



function rde()
        -- Get work items
	local work_items = pl:get_work_items()

        -- Group work items by triage then track
        local triage_hash, triage_tags = Select.group_by_triage(work_items)
        for _, triage in ipairs(triage_tags) do
                triage_hash[triage] =
                          table.pack(Select.group_by_track(triage_hash[triage]))
        end

        -- Apply map over work items by triage then track to sum required skills
        local demand_hash = {}
        for _, triage in ipairs(triage_tags) do
                demand_hash[triage] = demand_hash[triage] or {}
                local track_hash, track_tags = unpack(triage_hash[triage])
                for _, track in pairs(track_tags) do
                        demand_hash[triage][track] =
                      plan:to_num_people(Work.sum_demand(track_hash[track]))
                      print(triage, track, #track_hash[track])
                end
        end

        -- Format required demand by triage then track
        local result_string =
                 TextFormat.rde_formatter(demand_hash, triage_tags, plan, staff)
        print(result_string)
end

-- Prints available people by skill
function rs()
        -- "Select" staff
        local staff = staff

        -- Group by skill
        local people_by_skill, skill_tags = Select.group_people_by_skill(staff)

        -- Format results
        local result_str = TextFormat.format_people_hash(
                               people_by_skill, skill_tags, plan, staff)

        print(result_str)
end

function rss()
        -- "Select" staff
        local staff = staff

        -- Format results
        local result_str = TextFormat.format_people_bandwidth(staff, plan)

        print(result_str)
end

-- UTILITY FUNCTIONS ----------------------------------------------------------
--

-- Rank can be a single number or an array of numbers
function r(rank)
        return Select.work_with_rank(plan, rank)
end

-- This is a helper function that essentially maps "get_id" over a set of work
-- items. This is necessary when we need to work with actual work IDs rather
-- than work rankings.
function get_ids(work_items)
	local result = {}
	for i = 1,#work_items do
		result[#result+1] = work_items[i].id
	end
	return result
end

-- Rank work. work_items can be either ids or work objects
function rank(work_items, position)
	if #work_items == 0 then return end

	-- If we have work objects, get the ids
	if type(work_items[1]) == "table" then
		work_items = get_ids(work_items)
	end
	plan:rank(work_items, {["at"] = position})
end


function sc(cutline)
        plan.cutline = cutline
end

-- HELP -----------------------------------------------------------------------
--

function help()
	print(
[[
-- Reading/Writing
wrd(n):		Writes data to file with suffix "n"
export():	Writes data to "data/output.txt" in a form for Google Docs

-- Printing
p():		Alias for print

-- Select work
r(rank):	Selects work item at rank 'rank'. May also take an array of ranks.
wall():		Prints all work in plan
wac():		Prints work above cutline

-- Updating plan
sc(num):	Sets cutline

-- Reports
rrt():		Report running totals
rbt(tra, tri):	Report by track. Takes optional track(s) "t" to filter on and triage.
                Using a triage of 1 selects all 1s. Using 1.5 selects 1s and 1.5s.
rde():		Report data export (demand by triage and track)
rs():		Report available supply
]]
	)
end

