local Work = require('work')
local Plan = require('plan')

local Reader = require('reader')


TestRead = {}

-- TEST TAG PARSING -----------------------------------------------------------
--
function TestRead:test_parseTags()
	local tag_string = "Apps:1"
	local tag_table = Reader.parse_tags(tag_string)
	assertEquals(tag_table["Apps"], 1)
end

function TestRead:test_parseTags2()
	local tag_string = "Apps:1,Server:0"
	local tag_table = Reader.parse_tags(tag_string)
	assertEquals(tag_table["Apps"], 1)
	assertEquals(tag_table["Server"], 0)
end

function TestRead:test_parseTagsWithSpaces()
	local tag_string = "Track:Team Scrooge,Description:Continuous improvement & testing"
	local tag_table = Reader.parse_tags(tag_string)
	assertEquals(tag_table["Track"], "Team Scrooge")
	assertEquals(tag_table["Description"], "Continuous improvement & testing")
end

function TestRead:test_parseTagsWithBlanks()
	local tag_string = "Apps:1,Server:"
	local tag_table = Reader.parse_tags(tag_string)
	assertEquals(tag_table["Apps"], 1)
	assertEquals(tag_table["Server"], "")
end

-- TEST READING DATA FROM FILE ------------------------------------------------
--
function TestRead:test_readPlan()
	local plans = Reader.read_plans("./data/plan1.txt")
	local expected_work_items = {"2", "1"}

	assertEquals(#plans, 1)
	for i = 1,#expected_work_items do
		assertEquals(plans[1].work_items[i], expected_work_items[i])
	end

        assertEquals(plans[1].tags, {["importance"] = "HIGH"})
end

function TestRead:test_readWork()
	local expected_names = {"Do work item 1", "Do work item 2"}
	local work = Reader.read_work("./data/work1.txt")

	assertEquals(#work, 2)
	for i = 1,#expected_names do
		assertEquals(work[i].name, expected_names[i])
	end

        -- Check tags
        assertEquals(work[1].tags.track, "Track1")
        assertEquals(work[1].tags.priority, 1)

	local estimates = work[1]:get_skill_demand()
	assertEquals(estimates["Web"], 2)
end

function TestRead:test_readPeople()
	local expected_names = {"Aarthi", "Adam", "Adrian N", "Adrian L", "Akhilesh", "Amanda"}
	local people = Reader.read_people("./data/people1.txt")

	assertEquals(#people, 6)
	for i = 1,#expected_names do
		assertEquals(people[i].name, expected_names[i])
	end

	-- Test skills
	assertEquals(people[5].skills["Apps"], 1)
	assertEquals(people[5].skills["Native"], 0)

        -- Test tags
        assertEquals(people[2].tags.node, 1)
end

