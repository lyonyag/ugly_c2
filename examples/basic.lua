--[[
    Basic Example - FFI Collision Detection
    Simple demonstration of collision detection usage
]]

local ffi = require("ffi")
local collision = require("collision_ffi")

-- Create a collision layer
-- Parameters: cell_size, max_collisions, max_manifolds
local layer = collision.new(64.0, 4096, 2048)

-- Add some shapes
layer:setCircle(1, 100.0, 100.0, 25.0)  -- Circle at (100,100) with radius 25
layer:setAABB(2, 150.0, 150.0, 200.0, 200.0)  -- Rectangle from (150,150) to (200,200)
layer:setCircle(3, 300.0, 300.0, 30.0)  -- Another circle

-- Check for collisions with shape 1
local ids, count = layer:getCollisions(1)
if ids and count > 0 then
    print("Shape 1 collides with:")
    for i = 0, count - 1 do
        print("  Shape " .. ids[i])
    end
else
    print("Shape 1 has no collisions")
end

-- Get collision manifolds (contact information)
local data, manifold_count = layer:getManifolds(1)
if data and manifold_count > 0 then
    print("\nCollision details for shape 1:")
    for i = 0, manifold_count - 1 do
        local offset = i * 5
        local nx = data[offset]      -- Normal X
        local ny = data[offset + 1]  -- Normal Y
        local cx = data[offset + 2]  -- Contact point X
        local cy = data[offset + 3]  -- Contact point Y
        local depth = data[offset + 4]  -- Penetration depth
        
        print(string.format(
            "  Manifold %d: normal=(%.2f,%.2f) contact=(%.2f,%.2f) depth=%.2f",
            i + 1, nx, ny, cx, cy, depth
        ))
    end
end

-- Point query - find all shapes at a point
print("\nShapes at point (160, 160):")
local point_ids, point_count = layer:queryPoint(160.0, 160.0)
if point_ids and point_count > 0 then
    for i = 0, point_count - 1 do
        print("  Shape " .. point_ids[i])
    end
else
    print("  None")
end

-- AABB query - find all shapes in a region
print("\nShapes in region (0,0) to (250,250):")
local aabb_ids, aabb_count = layer:queryAABB(0.0, 0.0, 250.0, 250.0)
if aabb_ids and aabb_count > 0 then
    for i = 0, aabb_count - 1 do
        print("  Shape " .. aabb_ids[i])
    end
else
    print("  None")
end

-- Batch collision query
print("\nBatch collision check for shapes 1, 2, 3:")
local batch_ids = ffi.new("uint32_t[3]", {1, 2, 3})
local batch_result, batch_count = layer:getCollisionsBatch(batch_ids, 3)
if batch_result and batch_count > 0 then
    for i = 0, batch_count - 1 do
        print("  Collision with shape " .. batch_result[i])
    end
else
    print("  No collisions")
end

-- Clean up
layer:delete()
print("\nDone!")