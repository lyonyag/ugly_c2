--[[
    Game Loop Example - FFI Collision Detection
    Demonstrates using collision detection in a game loop
]]

local ffi = require("ffi")
local collision = require("collision_ffi")

-- Create collision layer
local layer = collision.new(64.0, 4096, 2048)

-- Game objects
local objects = {}
local next_id = 1

-- Create game object
function createObject(x, y, radius)
    local id = next_id
    next_id = next_id + 1
    
    layer:setCircle(id, x, y, radius)
    
    objects[id] = {
        id = id,
        x = x,
        y = y,
        radius = radius,
        vx = (math.random() - 0.5) * 200,
        vy = (math.random() - 0.5) * 200
    }
    
    return id
end

-- Initialize objects
for i = 1, 100 do
    createObject(
        math.random(50, 750),
        math.random(50, 550),
        math.random(15, 30)
    )
end

-- Game loop
local frame_count = 0
local total_time = 0
local collision_count = 0

print("Starting game loop simulation...")
print("Simulating 1000 frames with 100 objects")
print()

local start_time = os.clock()

for frame = 1, 1000 do
    local dt = 0.016  -- 60 FPS
    
    -- Update object positions
    for id, obj in pairs(objects) do
        -- Move
        obj.x = obj.x + obj.vx * dt
        obj.y = obj.y + obj.vy * dt
        
        -- Bounce off walls
        if obj.x - obj.radius < 0 or obj.x + obj.radius > 800 then
            obj.vx = -obj.vx
            obj.x = math.max(obj.radius, math.min(800 - obj.radius, obj.x))
        end
        if obj.y - obj.radius < 0 or obj.y + obj.radius > 600 then
            obj.vy = -obj.vy
            obj.y = math.max(obj.radius, math.min(600 - obj.radius, obj.y))
        end
        
        -- Update collision layer
        layer:setCircle(id, obj.x, obj.y, obj.radius)
    end
    
    -- Check collisions
    for id, obj in pairs(objects) do
        local ids, count = layer:getCollisions(id)
        if ids and count > 0 then
            collision_count = collision_count + 1
            
            -- Simple collision response
            for i = 0, count - 1 do
                local other_id = ids[i]
                local other = objects[other_id]
                if other then
                    -- Exchange velocities (simplified)
                    obj.vx, other.vx = other.vx, obj.vx
                    obj.vy, other.vy = other.vy, obj.vy
                end
            end
        end
    end
    
    -- Reset buffers for next frame
    layer:resetBuffers()
    
    frame_count = frame_count + 1
end

local end_time = os.clock()
total_time = end_time - start_time

-- Results
print("=== Results ===")
print(string.format("Frames simulated: %d", frame_count))
print(string.format("Total time: %.3f seconds", total_time))
print(string.format("Time per frame: %.3f ms", (total_time / frame_count) * 1000))
print(string.format("FPS: %.0f", frame_count / total_time))
print(string.format("Total collisions detected: %d", collision_count))
print(string.format("Average collisions per frame: %.1f", collision_count / frame_count))
print()
print("Performance:")
print(string.format("  Object updates: %.0f per second", (frame_count * #objects) / total_time))
print(string.format("  Collision checks: %.0f per second", (frame_count * #objects) / total_time))

-- Clean up
layer:delete()

print("\nDone!")