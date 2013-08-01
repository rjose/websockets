local Work = require("work")
local Plan = require("plan")

TestPlan = {}

-- SETUP ----------------------------------------------------------------------
--
function TestPlan:setUp()
        -- Set up some work to add to the plan
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

        -- Create a plan with a set of work items and a default supply
        self.plan = Plan.new{
                id = 1,
                name = "MobileQ3",
                num_weeks = 13,
                team_id = 0,
                work_items = {'1', '2', '3', '4', '5', '6', '7', '8', '9', '10'},
                tags = {},
                work_table = work,
                default_supply = { ["Native"] = 10, ["Web"] = 8, ["BB"] = 3 },
                cutline = 5
        }
end


-- HELPER FUNCTIONS -----------------------------------------------------------
--

-- This lets us check expected vs actual rankings. We only compare by IDs. We
-- do string comparisons so we can compare the complete ranking mismatches all
-- at once.
function TestPlan.check_rankings(ranked_items, expected_rankings)
        local ranked_string = ""
        for i = 1,#ranked_items do
                ranked_string = ranked_string .. ranked_items[i].id
        end

        local expected_string = ""
        for i = 1,#expected_rankings do
                expected_string = expected_string .. expected_rankings[i]
        end

        assertEquals(ranked_string, expected_string)
end



-- TESTING WORK ABOVE CUTLINE -------------------------------------------------
--

function TestPlan:test_workAboveCutline()
	local expected_rankings = {1, 2, 3, 4, 5}
	local ranked_items = self.plan:get_work_items({["ABOVE_CUT"] = 1})
        TestPlan.check_rankings(ranked_items, expected_rankings)
end

function TestPlan:test_demandAboveCutline()
        self.plan.cutline = 3
	local expected = { ["Native"] = 9, ["Web"] = 6, ["BB"] = 3 }
	local demand = self.plan:get_demand_totals({["ABOVE_CUT"] = 1})

	for skill, weeks in pairs(expected) do
		assertEquals(demand[skill], expected[skill])
	end
end



-- TESTING RUNNING TOTALS -----------------------------------------------------
--

function TestPlan:test_runningSupply()
        self.plan.cutline = 3
	local expected = {
		{ ["Native"] = 7, ["Web"] = 6, ["BB"] = 2 },
		{ ["Native"] = 4, ["Web"] = 4, ["BB"] = 1 },
		{ ["Native"] = 1, ["Web"] = 2, ["BB"] = 0 }
	}
	local _, actual = self.plan:get_supply_totals({["ABOVE_CUT"] = 1})
	for i = 1,#expected do
		local expected_total = expected[i]
		for skill, avail in pairs(expected_total) do
			assertEquals(actual[i][skill], avail)
		end
	end
end



-- TEST RANKING ---------------------------------------------------------------
--

function TestPlan:test_initialRankings()
        local expected_rankings = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
        local ranked_items = self.plan:get_work_items()
        TestPlan.check_rankings(ranked_items, expected_rankings)
end

function TestPlan:test_applyRanking1()
        local expected_rankings = {7, 8, 9, 1, 2, 3, 4, 5, 6, 10}
        self.plan:rank({7, 8, 9})
        local ranked_items = self.plan:get_work_items()
        TestPlan.check_rankings(ranked_items, expected_rankings)
end

-- Edge case: rank items already ranked
function TestPlan:test_applyRanking2()
        local expected_rankings = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
        self.plan:rank({1, 2, 3})
        local ranked_items = self.plan:get_work_items()
        TestPlan.check_rankings(ranked_items, expected_rankings)
end

-- Edge case: idempotency of ranking
function TestPlan:test_applyRanking3()
        local expected_rankings = {7, 8, 9, 1, 2, 3, 4, 5, 6, 10}
        self.plan:rank({7, 8, 9})
        self.plan:rank({7, 8, 9})
        local ranked_items = self.plan:get_work_items()
        TestPlan.check_rankings(ranked_items, expected_rankings)
end

-- Set rank of a set of items at a position
function TestPlan:test_applyRanking4()
        local expected_rankings = {1, 2, 3, 7, 8, 9, 4, 5, 6, 10}
        self.plan:rank({7, 8, 9}, {at = 4})
        local ranked_items = self.plan:get_work_items()
        TestPlan.check_rankings(ranked_items, expected_rankings)
end

-- Ranking at one position and then at another
function TestPlan:test_applyRanking5()
        local expected_rankings = {1, 3, 2, 7, 8, 9, 4, 5, 6, 10}
        self.plan:rank({7, 8, 9}, {at = 4})
        self.plan:rank({3, 2}, {at = 2})
        local ranked_items = self.plan:get_work_items()
        TestPlan.check_rankings(ranked_items, expected_rankings)
end

-- Edge case: Ranking items at end of unchanged items
function TestPlan:test_applyRanking6()
        local expected_rankings = {4, 5, 6, 7, 8, 9, 10, 2, 1, 3}
        self.plan:rank({2, 1, 3}, {at = 8})
        local ranked_items = self.plan:get_work_items()
        TestPlan.check_rankings(ranked_items, expected_rankings)
end

-- Edge case: Rank non-contiguous items
function TestPlan:test_applyRanking7()
        local expected_rankings = {1, 3, 5, 2, 4, 10, 6, 7, 8, 9}
        self.plan:rank({2, 4, 10, 6}, {at = 4})
        local ranked_items = self.plan:get_work_items()
        TestPlan.check_rankings(ranked_items, expected_rankings)
end



-- TEST PLAN FEASIBILITY ------------------------------------------------------
--

function TestPlan:test_isFeasible()
        self.plan.cutline = 3
	local is_feasible, avail_skills
	is_feasible, avail_skills = self.plan:is_feasible()
	assertEquals(is_feasible, false)
	assertEquals(avail_skills, { ["Native"] = 1, ["Web"] = 2,
                                     ["BB"] = 0, ["Server"] = -39 })
end


function TestPlan:test_findFeasibleLine()
        self.plan.default_supply["Server"] = 30
	local feas_line, demand_totals, supply_totals = self.plan:find_feasible_line()

	assertEquals(feas_line, 2)
	assertEquals(#demand_totals, 10)
	assertEquals(#supply_totals, 10)
end

-- Edge case: not enough resources to even start work items
function TestPlan:test_findFeasibleLine2()
	local feas_line = self.plan:find_feasible_line()
	assertEquals(feas_line, 0)
end

-- Edge case: over-resourced
function TestPlan:test_findFeasibleLine3()
        self.plan.default_supply = {
                ["Native"] = 500,
                ["Web"] = 500,
                ["BB"] = 500,
                ["Server"] = 500
        }
	local feas_line = self.plan:find_feasible_line()
	assertEquals(feas_line, 10)
end

