local func = require('functional')

local Select = {}

function Select.all_work(plan)
	return plan:get_work_items()
end

-- Rank can be a single number or an array of numbers
function Select.work_with_rank(plan, rank)
        local result = {}

	if type(rank) == "number" then
		result = {plan:get_work(rank)}
                print("Number", rank, #result)
	elseif type(rank) == "table" then
		result = plan:get_work_array(rank)
	else
		print("Couldn't interpret input")
	end

        return result
end


function Select.apply_filters(work_items, filters)
        if filters == nil then
                return work_items
        end

        local result = {}

        for i, w in ipairs(work_items) do
                local passed_filters = true
                for _, filter in ipairs(filters) do
                        if not filter(w, i) then
                                passed_filters = false
                                break
                        end
                end
                if passed_filters then
                        result[#result+1] = w
                end
        end
        return result
end

function Select.merge_work(work_item_arrays)
        local result = {}
        for _, work_items in ipairs(work_item_arrays) do
                for _, w in ipairs(work_items) do
                        result[#result+1] = w
                end
        end
        return result
end

-- FILTER FUNCTIONS -----------------------------------------------------------
--

function Select.invert_filter(filter)
        local result = function(work_item, index)
                return not filter(work_item, index)
        end
end

function Select.make_above_cutline_filter(plan)
        local result = function(work_item)
                if not work_item.rank then
                        return false
                else
                        return work_item.rank <= plan.cutline
                end
        end
        return result
end


function Select.make_below_cutline_filter(plan)
        return Select.invert_filter(Select.make_above_cutline_filter(plan))
end


-- Filters on one or more track labels
-- TODO: Rename items to make them more generic
function Select.make_track_filter(t)
        local tracks = {}
        if type(t) == "table" then
                tracks = t
        else
                tracks[1] = t
        end

        local result
        result = function(work_item)
                for _, track in pairs(tracks) do
                        local search_term = track:lower():split(" ")[1]
                        if work_item.tags.track:lower():find("^" .. search_term) then
                                return true
                        end
                end
                return false
        end

        return result
end

function Select.make_downto_triage_filter(triage)
        local result = function(work_item)
                return Work.downto_triage_filter(triage, work_item)
        end
        return result
end

function Select.make_triage_filter(triage)
        local result

        -- Check for 1 vs 1.5, e.g.
        fractional_part = triage % 1
        if fractional_part > 0 then
                result = function(work_item)
                        return Work.triage_xx_filter(triage - fractional_part, work_item)
                end
        else
                result = function(work_item)
                        return Work.triage_filter(triage, work_item)
                end
        end
        return result
end

-- "triage" is optional. If "t" is a number, then only return triage filter.
function Select.get_track_and_triage_filters(t, triage)
        local result = {}

        -- Make a track filter, if necessary
        if t then
                if type(t) == "number" then
                        triage = t
                else
                        result[#result+1] = Select.make_track_filter(t)
                end
        end

        -- Make a triage filter, if necessary
        if triage then
                result[#result+1] = Select.make_triage_filter(triage)
        end

        return result
end


-- GROUPING FUNCTIONS ---------------------------------------------------------
--
function Select.group_by_skill(items)
        -- TODO: Handle multiple skills
        local get_skill = function(item)
                for skill, frac in pairs(item.skills) do
                        -- Just return the first one way find
                        return skill
                end
        end

        return func.group_items(items, get_skill)
end

function Select.group_by_track(work_items)
        local get_track = function(w) return w.tags.track end

        return func.group_items(work_items, get_track)
end

function Select.group_by_triage(work_items)
        local get_triage = function(w) return w:merged_triage() end

        return func.group_items(work_items, get_triage)
end

function Select.group_people_by_skill(people)
        local people_by_skill = {}

        for _, person in ipairs(people) do
                local skill_tag = Writer.tags_to_string(person.skills):split(":")[1]
                skill_tag = skill_tag or "_UNSPECIFIED"
                people_list = people_by_skill[skill_tag] or {}
                people_list[#people_list+1] = person
                people_by_skill[skill_tag] = people_list
        end

	local skill_tags = func.get_table_keys(people_by_skill)
	table.sort(skill_tags)

        return people_by_skill, skill_tags
end

-- MISC FUNCTIONS -------------------------------------------------------------
--
function Select.gather_tracks(work_items)
        local track_hash = {}
        for _, w in ipairs(work_items) do
                track_hash[w.tags.track] = 1
        end
        return func.get_table_keys(track_hash)
end

return Select
