local string_utils = {}

function string:split(sSeparator, nMax, bRegexp)
	assert(sSeparator ~= '')
	assert(nMax == nil or nMax >= 1)

	local aRecord = {}

	if self:len() > 0 then
		local bPlain = not bRegexp
		nMax = nMax or -1

		local nField=1 nStart=1
		local nFirst,nLast = self:find(sSeparator, nStart, bPlain)
		while nFirst and nMax ~= 0 do
			aRecord[nField] = self:sub(nStart, nFirst-1)
			nField = nField+1
			nStart = nLast+1
			nFirst,nLast = self:find(sSeparator, nStart, bPlain)
			nMax = nMax-1
		end
		aRecord[nField] = self:sub(nStart)
	end

	return aRecord
end

function string_utils.join(items, sep)
	local result = ""

	for _, item in pairs(items) do
		result = result .. item .. sep
	end

	-- Remove trailing sep
	result = result:sub(1, -sep:len()-1)

	return result
end

function string:truncate(l, options)
        if self:len() <= l then
                return self
        end

        options = options or {}
        result = self:sub(1, l)
        
        if options.ellipsis then
                result = result:sub(1, -4) .. "..."
        end


        return result
end

return string_utils
