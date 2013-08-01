local Reader = require('app/reader')
local Writer = require('app/reader')
local Person = require('app/person')

local Data = {}

local data_dir = "./data/"

-- TODO: Get rid of this
-- Used to figure out the next work id
local num_work_items

function Data.load_data(prefix)
	local prefix = prefix or ""

	-- NOTE: Right now, we don't write people out
	local ppl = Reader.read_people(data_dir .. "people" .. prefix .. ".txt")

	-- NOTE: For now, assuming only one plan
	local pl = Reader.read_plans(data_dir .. "plan" .. prefix .. ".txt")[1]

	-- Load work items and put them into a table
	local work_array = Reader.read_work(data_dir .. "work" .. prefix .. ".txt")
	num_work_items = #work_array
	local work_table = {}
	for i = 1,#work_array do
                local w = work_array[i]
                w.rank = i -- Set initial rank
		work_table[work_array[i].id] = w
	end
	pl.work_table = work_table
	pl.default_supply = Person.sum_bandwidth(ppl, 13)

	return pl, ppl
end

-- "write data"
function Data.wrd(prefix)
	if prefix == nil then
		print("Please specify an explicit prefix")
		return
	end

	-- NOTE: Assuming pl, ppl are global
	Writer.write_plans({pl}, data_dir .. "plan" .. prefix .. ".txt")
	Writer.write_work(pl.work_table, data_dir .. "work" .. prefix .. ".txt")
end

-- Export into a form that's suitable for Google Docs
function Data.export()
        local file = assert(io.open("./data/output.txt", "w"))
        file:write("Product Priority\tEngineering Priority\t" ..
                   "Merged Priority\tMobile Track\tProject Name\t" ..
                   "Description\tRequesting Team\tDependencies\t" ..
                   "Tee Shirt Sizes\tNative Wks\tWeb Wks\tApps Wks\t" ..
                   "Notes\n")

        for _, work_id in ipairs(pl.work_items) do
                work = pl.work_table[work_id]
                file:write(string.format("%s\t%s\t%s\t%s\t%s\t" ..
                     "%s\t%s\t%s\t\t%s\t%s\t%s\t%s\n", 
                           tagvalue_to_string(work.triage.ProdTriage),
                           tagvalue_to_string(work.triage.EngTriage),
                           tagvalue_to_string(work.triage.Triage),
                           work.tags.track,
                           work.name,

                           work.tags.Description,
                           work.tags.RequestingTeam,
                           work.tags.Dependencies,
                           work.estimates.Native,
                           work.estimates.Web,
                           work.estimates.Apps,
                           work.tags.Notes
                           ))
        end
        file:close()
end

return Data
