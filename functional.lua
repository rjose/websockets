-- TODO: Document this
local func = {}

function func.filter(items, filter)
	local result = {}
	for _, item in ipairs(items) do
		if filter(item) then
			result[#result+1] = item
		end
	end
	return result
end

-- Returns an array of keys being the union of t1 and t2
function func.key_union(...)
        local result = {}
        local keymap = {}
        for _, t in pairs({...}) do
                for k, _ in pairs(t) do
                        keymap[k] = true
                end
        end

        for k, _ in pairs(keymap) do
                result[#result+1] = k
        end

        return result
end

-- Returns all the keys in a table
function func.get_table_keys(t)
	local result = {}
	for k, _ in pairs(t) do
		result[#result+1] = k .. ""
	end
	return result
end

-- This applies a function of 2 variables key-wise to two tables. The function f
-- should handle nil values in a way that makes sense.
function func.apply_keywise_2(f, t1, t2)
        t1 = t1 or {}
        t2 = t2 or {}

        local keys = func.key_union(t1, t2)

	local result = {}
        for _, key in pairs(keys) do
                result[key] = f(t1[key], t2[key])
        end

        return result
end

function func.add(w1, w2)
        w1 = w1 or 0
        w2 = w2 or 0
	return w1 + w2
end

function func.subtract(w1, w2)
        w1 = w1 or 0
        w2 = w2 or 0
	return w1 - w2
end


function func.concat(...)
        local arrays = {...}
        local result = {}

        for i = 1,#arrays do
                local a = arrays[i]
                for j = 1,#a do
                        result[#result+1] = a[j]
                end
        end

        return result
end

function func.split_at(n, a)
        local result1, result2 = {}, {}
        if n > #a then n = #a end

        for i = 1,n do
                result1[#result1+1] = a[i]
        end
        for i = n+1, #a do
                result2[#result2+1] = a[i]
        end
        return result1, result2
end

-- Groups items into buckets defined by applying "get_bucket" to each one
function func.group_items(items, get_bucket)
	local groupings = {}

        for _, item in ipairs(items) do
		local bucket = get_bucket(item) .. ""
		if not bucket then
			bucket = "??"
		end

                -- Put stuff into the bucket list :-)
		groupings[bucket] = groupings[bucket] or {}
                local bucket_list = groupings[bucket]
		bucket_list[#bucket_list+1] = item
	end

	-- Sort buckets
	local bucket_names = func.get_table_keys(groupings)
	table.sort(bucket_names)

        return groupings, bucket_names
end



return func
