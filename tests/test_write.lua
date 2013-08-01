local Work = require('work')
local Plan = require('plan')
local Reader = require('reader')

local Writer = require('writer')

TestWrite = {}

-- SETUP ----------------------------------------------------------------------
--

function TestWrite:setUp()
        -- Set up work and a plan
        local work = {}
        for i = 1, 10 do
                local id = i .. ""
                work[id] = Work.new{
                        id = id,
                        name = "Task" .. i,
                        tags = {["track"] = "Saturn", ["pri"] = 1},
                        estimates = {
                                ["Native"] = "L",
                                ["Web"] = "M",
                                ["Server"] = "Q",
                                ["BB"] = "S"
                        }
                }
        end
        work['1'].tags.pri = 2
        work['1'].tags.track = 'Penguin'
        work['4'].tags.pri = 2
        work['4'].tags.track = 'Penguin'

        self.work = work

        -- Create a plan with a set of work items and a default supply
        self.plan = Plan.new{
                id = 1,
                name = "MobileQ3",
                num_weeks = 13,
                team_id = 0,
                work_items = {'1', '2', '3', '4', '5', '6', '7', '8', '9', '10'},
                tags = {["importance"] = "HIGH"},
                work_table = work,
                default_supply = { ["Native"] = 10, ["Web"] = 8, ["BB"] = 3 },
                cutline = 5
        }
end


-- TEST WRITING PLANS OUT -----------------------------------------------------
--

function TestWrite:test_writePlan()
	Writer.write_plans({self.plan}, "./tmp/plan_out.txt")

	-- Use Reader to test
	local plans = Reader.read_plans("./tmp/plan_out.txt")
	local expected_work_items = {"1", "2", "3", "4", "5",
				     "6", "7", "8", "9", "10"
        }

	assertEquals(#plans, 1)
	for i = 1,#expected_work_items do
		assertEquals(plans[1].work_items[i], expected_work_items[i])
	end

        -- Check tags
        assertEquals(plans[1].tags.importance, "HIGH")
end


-- TEST WRITING WORK OUT ------------------------------------------------------
--

function TestWrite:test_writeWork()
	Writer.write_work(self.work, "./tmp/work_out.txt")

	-- Use Reader to test
	local work_items = Reader.read_work("./tmp/work_out.txt")
	assertEquals(#work_items, 10)
end

