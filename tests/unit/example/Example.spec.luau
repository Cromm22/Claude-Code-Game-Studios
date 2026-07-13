--!strict
-- Example TestEZ spec — demonstrates the project's test pattern and satisfies
-- the Technical Setup -> Pre-Production gate's "at least one example test file"
-- requirement. Exercises DisturbanceService's spatial-hash cell-coordinate
-- formula (ADR-0004, Decision -> Spatial data structure), since it's a pure,
-- deterministic formula already fixed in an Accepted ADR, ahead of any
-- service actually being implemented in src/.

return function()
	describe("DisturbanceService spatial hash grid — cellCoordFor (ADR-0004)", function()
		local SPATIAL_GRID_CELL_SIZE = 32

		local function cellCoordFor(position: Vector3): (number, number)
			return math.floor(position.X / SPATIAL_GRID_CELL_SIZE),
				math.floor(position.Z / SPATIAL_GRID_CELL_SIZE)
		end

		it("maps the grid origin to cell (0, 0)", function()
			local cellX, cellZ = cellCoordFor(Vector3.new(0, 0, 0))
			expect(cellX).to.equal(0)
			expect(cellZ).to.equal(0)
		end)

		it("maps a mid-cell position to its containing cell", function()
			local cellX, cellZ = cellCoordFor(Vector3.new(40, 0, 70))
			expect(cellX).to.equal(1)
			expect(cellZ).to.equal(2)
		end)

		it("uses floor division (not truncation) for negative-axis positions", function()
			-- ADR-0004 specifies math.floor, not a truncating int cast — this
			-- distinguishes -1 from 0 for a position just past the origin's
			-- negative edge, which a naive truncation would get wrong.
			local cellX, cellZ = cellCoordFor(Vector3.new(-5, 0, -40))
			expect(cellX).to.equal(-1)
			expect(cellZ).to.equal(-2)
		end)

		it("is stable at exact cell boundaries", function()
			local cellX, cellZ = cellCoordFor(Vector3.new(32, 0, 64))
			expect(cellX).to.equal(1)
			expect(cellZ).to.equal(2)
		end)
	end)
end
