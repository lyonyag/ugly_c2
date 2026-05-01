--[[
    Love2D Example - FFI Collision Detection
    Interactive demonstration of the optimized collision detection system
]]

local ffi = require("ffi")
local collision = require("collision_ffi")

-- Create collision layer
local layer = collision.new(64.0, 4096, 2048)

-- Game state
local shapes = {}
local next_id = 1
local selected_shape = nil
local show_debug = true
local paused = false
local show_help = false

-- Colors
local colors = {
    circle = {0.2, 0.6, 1.0, 0.8},
    aabb = {1.0, 0.4, 0.4, 0.8},
    capsule = {0.4, 1.0, 0.4, 0.8},
    collision = {1.0, 0.8, 0.0, 1.0},
    manifold = {1.0, 0.0, 0.0, 1.0},
    grid = {0.2, 0.2, 0.2, 0.5},
    ui_bg = {0.0, 0.0, 0.0, 0.7},
    text = {1.0, 1.0, 1.0, 1.0}
}

function love.load()
    love.window.setTitle("FFI Collision Detection - Love2D Example")
    love.window.setMode(1000, 700)
    
    -- Create initial shapes
    for i = 1, 30 do
        addRandomShape()
    end
end

function addRandomShape()
    local x = math.random(100, 900)
    local y = math.random(100, 600)
    local shape_type = math.random(1, 3)
    local id = next_id
    next_id = next_id + 1
    
    if shape_type == 1 then
        -- Circle
        local r = math.random(20, 40)
        layer:setCircle(id, x, y, r)
        shapes[id] = {type = "circle", x = x, y = y, r = r, vx = 0, vy = 0}
    elseif shape_type == 2 then
        -- AABB
        local w = math.random(40, 80)
        local h = math.random(40, 80)
        layer:setAABB(id, x, y, x + w, y + h)
        shapes[id] = {type = "aabb", x = x, y = y, w = w, h = h, vx = 0, vy = 0}
    else
        -- Capsule
        local ax = x - 30
        local ay = y
        local bx = x + 30
        local by = y
        local r = math.random(15, 25)
        layer:setCapsule(id, ax, ay, bx, by, r)
        shapes[id] = {type = "capsule", ax = ax, ay = ay, bx = bx, by = by, r = r, vx = 0, vy = 0}
    end
    
    return id
end

function removeShape(id)
    if shapes[id] then
        layer:remove(id)
        shapes[id] = nil
    end
end

function love.update(dt)
    if paused then return end
    
    -- Animate shapes
    for id, shape in pairs(shapes) do
        -- Apply velocity
        shape.x = shape.x + (shape.vx or 0) * dt
        shape.y = shape.y + (shape.vy or 0) * dt
        
        -- Bounce off walls
        if shape.type == "circle" then
            if shape.x - shape.r < 0 or shape.x + shape.r > 1000 then
                shape.vx = -(shape.vx or 0)
            end
            if shape.y - shape.r < 0 or shape.y + shape.r > 700 then
                shape.vy = -(shape.vy or 0)
            end
            layer:setCircle(id, shape.x, shape.y, shape.r)
        elseif shape.type == "aabb" then
            if shape.x < 0 or shape.x + shape.w > 1000 then
                shape.vx = -(shape.vx or 0)
            end
            if shape.y < 0 or shape.y + shape.h > 700 then
                shape.vy = -(shape.vy or 0)
            end
            layer:setAABB(id, shape.x, shape.y, shape.x + shape.w, shape.y + shape.h)
        end
    end
    
    -- Apply gentle forces
    for id, shape in pairs(shapes) do
        if not shape.vx then shape.vx = 0 end
        if not shape.vy then shape.vy = 0 end
        
        shape.vx = shape.vx + (math.random() - 0.5) * 10 * dt
        shape.vy = shape.vy + (math.random() - 0.5) * 10 * dt
        
        -- Damping
        shape.vx = shape.vx * 0.99
        shape.vy = shape.vy * 0.99
        
        -- Limit velocity
        local max_vel = 200
        local vel = math.sqrt(shape.vx * shape.vx + shape.vy * shape.vy)
        if vel > max_vel then
            shape.vx = shape.vx * max_vel / vel
            shape.vy = shape.vy * max_vel / vel
        end
    end
    
    -- Reset buffers for new frame
    layer:resetBuffers()
end

function love.draw()
    -- Draw grid
    love.graphics.setColor(colors.grid)
    for x = 0, 1000, 64 do
        love.graphics.line(x, 0, x, 700)
    end
    for y = 0, 700, 64 do
        love.graphics.line(0, y, 1000, y)
    end
    
    -- Draw shapes
    for id, shape in pairs(shapes) do
        local has_collision = false
        local ids, count = layer:getCollisions(id)
        if ids and count > 0 then
            has_collision = true
        end
        
        if has_collision then
            love.graphics.setColor(colors.collision)
        else
            love.graphics.setColor(colors[shape.type])
        end
        
        if shape.type == "circle" then
            love.graphics.circle("fill", shape.x, shape.y, shape.r)
            love.graphics.setColor(1, 1, 1)
            love.graphics.circle("line", shape.x, shape.y, shape.r)
        elseif shape.type == "aabb" then
            love.graphics.rectangle("fill", shape.x, shape.y, shape.w, shape.h)
            love.graphics.setColor(1, 1, 1)
            love.graphics.rectangle("line", shape.x, shape.y, shape.w, shape.h)
        elseif shape.type == "capsule" then
            drawCapsule(shape.ax, shape.ay, shape.bx, shape.by, shape.r)
        end
        
        -- Draw ID
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(tostring(id), shape.x or shape.ax or 0, (shape.y or shape.ay or 0) - 20)
    end
    
    -- Draw collision manifolds
    if show_debug then
        for id, shape in pairs(shapes) do
            local data, count = layer:getManifolds(id)
            if data and count > 0 then
                love.graphics.setColor(colors.manifold)
                for i = 0, count - 1 do
                    local offset = i * 5
                    local nx = data[offset]
                    local ny = data[offset + 1]
                    local cx = data[offset + 2]
                    local cy = data[offset + 3]
                    local depth = data[offset + 4]
                    
                    -- Draw contact point
                    love.graphics.circle("fill", cx, cy, 5)
                    
                    -- Draw normal
                    love.graphics.line(cx, cy, cx + nx * depth * 20, cy + ny * depth * 20)
                end
            end
        end
    end
    
    -- Draw UI
    love.graphics.setColor(colors.ui_bg)
    love.graphics.rectangle("fill", 10, 10, 280, 180)
    
    love.graphics.setColor(colors.text)
    love.graphics.print("FFI Collision Detection - Love2D", 20, 20)
    love.graphics.print(string.format("Shapes: %d", countShapes()), 20, 45)
    love.graphics.print(string.format("Paused: %s", paused and "Yes" or "No"), 20, 65)
    love.graphics.print(string.format("FPS: %d", love.timer.getFPS()), 20, 85)
    
    love.graphics.print("Controls:", 20, 110)
    love.graphics.print("  Click: Add shape", 20, 130)
    love.graphics.print("  Right-click: Remove shape", 20, 150)
    love.graphics.print("  Space: Pause/Resume", 20, 170)
    
    if show_help then
        love.graphics.setColor(colors.ui_bg)
        love.graphics.rectangle("fill", 300, 10, 400, 200)
        
        love.graphics.setColor(colors.text)
        love.graphics.print("Additional Controls:", 310, 20)
        love.graphics.print("  D: Toggle debug", 310, 45)
        love.graphics.print("  C: Clear all", 310, 70)
        love.graphics.print("  A: Add 10 shapes", 310, 95)
        love.graphics.print("  H: Toggle help", 310, 120)
        love.graphics.print("  R: Reset velocities", 310, 145)
    end
end

function drawCapsule(ax, ay, bx, by, r)
    local cx = (ax + bx) / 2
    local cy = (ay + by) / 2
    local angle = math.atan2(by - ay, bx - ax)
    local length = math.sqrt((bx - ax)^2 + (by - ay)^2)
    
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(angle)
    love.graphics.rectangle("fill", -length/2, -r, length, r * 2)
    love.graphics.circle("fill", -length/2, 0, r)
    love.graphics.circle("fill", length/2, 0, r)
    love.graphics.setColor(1, 1, 1)
    love.graphics.rectangle("line", -length/2, -r, length, r * 2)
    love.graphics.circle("line", -length/2, 0, r)
    love.graphics.circle("line", length/2, 0, r)
    love.graphics.pop()
end

function love.mousepressed(x, y, button)
    if button == 1 then
        -- Add random shape
        addRandomShape()
    elseif button == 2 then
        -- Remove shape at position
        for id, shape in pairs(shapes) do
            if shape.type == "circle" then
                local dx = x - shape.x
                local dy = y - shape.y
                if dx * dx + dy * dy <= shape.r * shape.r then
                    removeShape(id)
                    break
                end
            elseif shape.type == "aabb" then
                if x >= shape.x and x <= shape.x + shape.w and
                   y >= shape.y and y <= shape.y + shape.h then
                    removeShape(id)
                    break
                end
            end
        end
    end
end

function love.keypressed(key)
    if key == "space" then
        paused = not paused
    elseif key == "d" then
        show_debug = not show_debug
    elseif key == "c" then
        -- Clear all
        for id, _ in pairs(shapes) do
            layer:remove(id)
        end
        shapes = {}
    elseif key == "a" then
        -- Add 10 shapes
        for i = 1, 10 do
            addRandomShape()
        end
    elseif key == "h" then
        show_help = not show_help
    elseif key == "r" then
        -- Reset velocities
        for id, shape in pairs(shapes) do
            shape.vx = 0
            shape.vy = 0
        end
    end
end

function countShapes()
    local count = 0
    for _, _ in pairs(shapes) do
        count = count + 1
    end
    return count
end

function love.quit()
    layer:delete()
end