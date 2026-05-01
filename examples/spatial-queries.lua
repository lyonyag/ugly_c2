--[[
    Spatial Queries Example - FFI Collision Detection
    Demonstrates point and AABB queries for spatial filtering
]]

local ffi = require("ffi")
local collision = require("collision_ffi")

-- Create collision layer
local layer = collision.new(64.0, 4096, 2048)

-- Create test objects
print("Creating 500 random shapes...")
for i = 1, 500 do
    local x = math.random(50, 750)
    local y = math.random(50, 550)
    
    if i % 3 == 0 then
        -- Circle
        layer:setCircle(i, x, y, math.random(15, 35))
    else
        -- AABB
        local w = math.random(20, 60)
        local h = math.random(20, 60)
        layer:setAABB(i, x, y, x + w, y + h)
    end
end

print("Created 500 shapes")
print()

-- Point query examples
print("=== Point Queries ===")
local test_points = {
    {100, 100, "Top-left area"},
    {400, 300, "Center area"},
    {700, 500, "Bottom-right area"},
    {250, 250, "Middle area"}
}

for _, point in ipairs(test_points) do
    local x, y, description = point[1], point[2], point[3]
    local ids, count = layer:queryPoint(x, y)
    
    print(string.format("Point (%.0f, %.0f) - %s:", x, y, description))
    if ids and count > 0 then
        print(string.format("  Found %d shapes:", count))
        for i = 0, math.min(count - 1, 4) do  -- Show first 5
            print("    Shape " .. ids[i])
        end
        if count > 5 then
            print("    ... and " .. (count - 5) .. " more")
        end
    else
        print("  No shapes found")
    end
    print()
end

-- AABB query examples
print("=== AABB Queries ===")
local test_regions = {
    {0, 0, 200, 200, "Top-left quadrant"},
    {300, 200, 500, 400, "Center region"},
    {600, 400, 800, 600, "Bottom-right region"},
    {0, 0, 800, 600, "Entire area"}
}

for _, region in ipairs(test_regions) do
    local minx, miny, maxx, maxy, description = 
        region[1], region[2], region[3], region[4], region[5]
    
    local ids, count = layer:queryAABB(minx, miny, maxx, maxy)
    
    print(string.format("Region %s (%.0f,%.0f)-(%.0f,%.0f):", 
        description, minx, miny, maxx, maxy))
    print(string.format("  Found %d shapes", count))
    
    if ids and count > 0 and count <= 10 then
        for i = 0, count - 1 do
            print("    Shape " .. ids[i])
        end
    elseif count > 10 then
        for i = 0, 4 do
            print("    Shape " .. ids[i])
        end
        print("    ... and " .. (count - 5) .. " more")
    end
    print()
end

-- Mouse picking simulation
print("=== Mouse Picking Simulation ===")
print("Simulating mouse clicks at various positions...")
local mouse_positions = {
    {150, 150}, {350, 300}, {650, 450}, {100, 500}, {750, 100}
}

for _, pos in ipairs(mouse_positions) do
    local x, y = pos[1], pos[2]
    local ids, count = layer:queryPoint(x, y)
    
    if ids and count > 0 then
        print(string.format("Click at (%.0f, %.0f): Selected %d shape(s)", x, y, count))
        for i = 0, count - 1 do
            print("  - Shape " .. ids[i])
        end
    else
        print(string.format("Click at (%.0f, %.0f): No shape selected", x, y))
    end
end

print()

-- Frustum culling simulation
print("=== Frustum Culling Simulation ===")
print("Simulating camera view frustum queries...")
local viewports = {
    {0, 0, 400, 300, "Top-left view"},
    {400, 0, 800, 300, "Top-right view"},
    {0, 300, 400, 600, "Bottom-left view"},
    {400, 300, 800, 600, "Bottom-right view"}
}

for _, viewport in ipairs(viewports) do
    local x, y, w, h, description = 
        viewport[1], viewport[2], viewport[3] - viewport[1], viewport[4] - viewport[2], viewport[5]
    
    local ids, count = layer:queryAABB(viewport[1], viewport[2], viewport[3], viewport[4])
    
    print(string.format("%s: %d shapes visible", description, count))
end

print()

-- Performance test
print("=== Performance Test ===")
print("Running 10000 point queries...")
local start_time = os.clock()
local total_found = 0

for i = 1, 10000 do
    local x = math.random(0, 800)
    local y = math.random(0, 600)
    local ids, count = layer:queryPoint(x, y)
    if ids then
        total_found = total_found + count
    end
end

local elapsed = os.clock() - start_time
print(string.format("Completed 10000 queries in %.3f seconds", elapsed))
print(string.format("Average: %.3f ms per query", (elapsed / 10000) * 1000))
print(string.format("Throughput: %.0f queries/second", 10000 / elapsed))
print(string.format("Total shapes found: %d", total_found))

-- Clean up
layer:delete()

print("\nDone!")