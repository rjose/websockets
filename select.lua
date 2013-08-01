local Select = {}

-- This takes an array of items and a filter function that can be called on
-- each element. This returns only the items for which the filter is true
function Select.select_items(items, filter)
	local result = {}
	for i = 1,#items do
		if filter(items[i]) then
			result[#result+1] = items[i]
		end
	end
	return result
end

-- Selects the first *num_items* things (at most) from an array of items. If
-- the optional *filter* is specified, it is applied before returning the
-- results.
function Select.select_n_items(items, num_items, filter)
	local result = {}

	if num_items <= 0 then
		return result
	end

	-- Get the first *num_items* items
	for i = 1,#items do
		result[#result+1] = items[i]
		if i == num_items then
			break
		end
	end

	-- Filter if needed
	if filter then
		result = Select.select_items(result, filter)
	end

	return result
end

return Select
