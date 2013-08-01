local Person = require('person')
local Select = require('select')

TestSelect = {}

-- SETUP ----------------------------------------------------------------------
--
function TestSelect:setUp()
	-- Create some people
	self.people = {}

	-- Create some NCGs
	for i = 1,2 do
		self.people[#self.people+1] = Person.new{
			name = "P" .. i,
			skills = {["Native"] = 0.8, ["Apps"] = 0.2},
			tags = {["NCG"] = 1}
		}
	end

	-- Create some non NCGs
	for i = 3,5 do
		self.people[#self.people+1] = Person.new{
			name = "P" .. i,
			skills = {["Native"] = 0.8, ["Apps"] = 0.2},
			tags = {}
		}
	end
end

-- HELPERS --------------------------------------------------------------------
--

function is_ncg(person)
	if person.tags["NCG"] == 1 then
		return true
	else
		return false
	end
end

-- TAGS TESTS -----------------------------------------------------------------
--

function TestSelect:test_selectByTags()
	local ncg_people = Select.select_items(self.people, is_ncg)
	assertEquals(#ncg_people, 2)
	assertEquals(ncg_people[1].name, "P1")
end

-- SELECT N TESTS -------------------------------------------------------------
--
function TestSelect:test_selectNItems()
	local people = Select.select_n_items(self.people, 4)
	assertEquals(#people, 4)
end

function TestSelect:test_selectNItems_withFilter()
	local not_ncg = function(item) return not is_ncg(item) end

	local people = Select.select_n_items(self.people, 3, not_ncg)

	-- NOTE that this is 1 and not 3 since we're filtering on the first 3
	-- items first.
	assertEquals(#people, 1)
end
