--[[
    Physics Response Example - FFI Collision Detection
    Demonstrates collision response using manifold data
]]

local ffi = require("ffi")
local collision = require("collision_ffi")

-- Create collision layer
local layer = collision.new(64.0, 4096, 2048)

-- Physics object
local player = {
    id = 1,
    x = 400, y = 300,
    vx = 0, vy = 0,
    radius = 20,
    mass = 1.0
}

-- Create walls (static objects)
local walls = {
    {id = 2, x = 100, y = 100, w = 600, h = 20},   -- Top wall
    {id = 3, x = 100, y = 580, w = 600, h = 20},   -- Bottom wall
    {id = 4, x = 100, y = 100, w = 20, h = 500},   -- Left wall
    {id = 5, x = 680, y = 100, w = 20, h = 500}    -- Right wall
}

-- Create some obstacles
local obstacles = {}
for i = 1, 5 do
    obstacles[i] = {
        id = 10 + i,
        x = 200 + i * 80,
        y = 200 + math.random(-50, 50),
        radius = 30,
        static = true
    }
end

-- Initialize collision layer
layer:setCircle(player.id, player.x, player.y, player.radius)

for _, wall in ipairs(walls) do
    layer:setAABB(wall.id, wall.x, wall.y, wall.x + wall.w, wall.y + wall.h)
end

for _, obstacle in ipairs(obstacles) do
    layer:setCircle(obstacle.id, obstacle.x, obstacle.y, obstacle.radius)
end

-- Physics parameters
local GRAVITY = 500
local DAMPING = 0.8
local RESTITUTION = 0.7
local MAX_SPEED = 400

-- Apply force to player
function applyForce(fx, fy)
    player.vx = player.vx + fx / player.mass
    player.vy = player.vy + fy / player.mass
end

-- Simple physics update
function updatePhysics(dt)
    -- Apply gravity
    applyForce(0, GRAVITY * player.mass)
    
    -- Update position
    player.x = player.x + player.vx * dt
    player.y = player.y + player.vy * dt
    
    -- Update collision layer
    layer:setCircle(player.id, player.x, player.y, player.radius)
    
    -- Check for collisions and resolve
    local manifolds_data, manifold_count = layer:getManifolds(player.id)
    
    if manifolds_data and manifold_count > 0 then
        for i = 0, manifold_count - 1 do
            local offset = i * 5
            local nx = manifolds_data[offset]      -- Normal X
            local ny = manifolds_data[offset + 1]  -- Normal Y
            local cx = manifolds_data[offset + 2]  -- Contact point X
            local cy = manifolds_data[offset + 3]  -- Contact point Y
            local depth = manifolds_data[offset + 4]  -- Penetration depth
            
            -- Resolve collision by moving out along normal
            player.x = player.x + nx * depth
            player.y = player.y + ny * depth
            
            -- Calculate relative velocity
            local rvx = player.vx
            local rvy = player.vy
            
            -- Calculate velocity along normal
            local vel_along_normal = rvx * nx + rvy * ny
            
            -- Don't resolve if velocities are separating
            if vel_along_normal > 0 then
                -- Calculate impulse scalar
                local j = -(1 + RESTITUTION) * vel_along_normal
                j = j / (1 / player.mass)
                
                -- Apply impulse
                local impulse_x = j * nx
                local impulse_y = j * ny
                
                player.vx = player.vx + impulse_x / player.mass
                player.vy = player.vy + impulse_y / player.mass
            end
            
            -- Apply friction
            local tangent_x = -ny
            local tangent_y = nx
            local tangent_vel = player.vx * tangent_x + player.vy * tangent_y
            local friction = 0.3
            
            player.vx = player.vx - friction * tangent_vel * tangent_x
            player.vy = player.vy - friction * tangent_vel * tangent_y
        end
        
        -- Update position after resolution
        layer:setCircle(player.id, player.x, player.y, player.radius)
    end
    
    -- Apply damping
    player.vx = player.vx * DAMPING
    player.vy = player.vy * DAMPING
    
    -- Limit speed
    local speed = math.sqrt(player.vx * player.vx + player.vy * player.vy)
    if speed > MAX_SPEED then
        player.vx = player.vx * MAX_SPEED / speed
        player.vy = player.vy * MAX_SPEED / speed
    end
end

-- Simulation
print("=== Physics Simulation ===")
print("Simulating ball bouncing in a box with obstacles")
print()

local dt = 0.016  -- 60 FPS
local simulation_time = 5.0  -- 5 seconds
local frames = simulation_time / dt

print(string.format("Running %.0f frames (%.1f seconds at 60 FPS)", frames, simulation_time))
print()

-- Give initial push
applyForce(200, -300)

local start_time = os.clock()
local collision_events = 0

for frame = 1, frames do
    updatePhysics(dt)
    
    -- Count collisions
    local ids, count = layer:getCollisions(player.id)
    if ids and count > 0 then
        collision_events = collision_events + 1
    end
    
    -- Print status every second
    if frame % 60 == 0 then
        local time = frame * dt
        print(string.format("t=%.1fs: pos=(%.1f, %.1f) vel=(%.1f, %.1f) collisions=%d", 
            time, player.x, player.y, player.vx, player.vy, collision_events))
    end
end

local elapsed = os.clock() - start_time

print()
print("=== Results ===")
print(string.format("Simulation time: %.3f seconds", elapsed))
print(string.format("Real-time factor: %.1fx", simulation_time / elapsed))
print(string.format("Total collision events: %d", collision_events))
print(string.format("Average collisions per second: %.1f", collision_events / simulation_time))
print()
print("Final state:")
print(string.format("  Position: (%.1f, %.1f)", player.x, player.y))
print(string.format("  Velocity: (%.1f, %.1f)", player.vx, player.vy))
print(string.format("  Speed: %.1f", math.sqrt(player.vx * player.vx + player.vy * player.vy)))

-- Clean up
layer:delete()

print("\nDone!")