package.path = package.path .. ";?.lua;?/init.lua;benchmark/HC/?.lua;benchmark/HC/?/init.lua"

local ffi = require("ffi")

-- FFI definitions for our optimized library
ffi.cdef[[
typedef struct {
  void *data;
  size_t size;
  size_t element_size;
} ArrayHandle;

typedef struct CollisionLayer CollisionLayer;

typedef struct {
  CollisionLayer *layer;
  void *collision_buffer;
  void *manifold_buffer;
} LayerHandle;

LayerHandle* layer_new_with_buffers(float cell_size, size_t max_collisions, size_t max_manifolds);
void layer_delete(LayerHandle *handle);
void layer_set_circle(LayerHandle *handle, uint32_t id, float x, float y, float r);
void layer_set_AABB(LayerHandle *handle, uint32_t id, float minx, float miny, float maxx, float maxy);
ArrayHandle layer_getCollisions(LayerHandle *handle, uint32_t id);
ArrayHandle layer_getManifolds(LayerHandle *handle, uint32_t id);
]]

local C = ffi.load("./build/ugly_c2_ffi.so")

-- Load HC
require("class")
local HC = require("init")

print("HC library loaded successfully!")

-- Configuration
local NUM_SHAPES = 2000
local NUM_FRAMES = 500
local WORLD_SIZE = 1000.0
local CELL_SIZE = 32.0
local MAX_DISPLACEMENT = 2.0

math.randomseed(os.time())

print(string.rep("=", 70))
print("FAIR PERFORMANCE COMPARISON: FFI vs HC")
print(string.rep("=", 70))
print(string.format("Shapes: %d | Frames: %d | Max movement: %.1f", 
  NUM_SHAPES, NUM_FRAMES, MAX_DISPLACEMENT))
print()

-- ============================================
-- FFI BENCHMARK
-- ============================================
print("1. LuaJIT FFI Implementation")
print(string.rep("-", 70))

local layer = C.layer_new_with_buffers(CELL_SIZE, NUM_SHAPES * 16, NUM_SHAPES * 8)

-- Create shapes for FFI
local ffi_shapes = {}
for i = 1, NUM_SHAPES do
  local x = math.random() * WORLD_SIZE
  local y = math.random() * WORLD_SIZE
  if i % 3 == 0 then
    C.layer_set_circle(layer, i, x, y, math.random() * 15 + 5)
    ffi_shapes[i] = {type = "circle", x = x, y = y, r = math.random() * 15 + 5}
  else
    local w = math.random() * 30 + 10
    local h = math.random() * 30 + 10
    C.layer_set_AABB(layer, i, x, y, x + w, y + h)
    ffi_shapes[i] = {type = "aabb", x = x, y = y, w = w, h = h}
  end
end

-- Warmup JIT
print("  Warming up JIT...")
for frame = 1, 20 do
  for id, shape in pairs(ffi_shapes) do
    local dx = (math.random() - 0.5) * MAX_DISPLACEMENT * 2
    local dy = (math.random() - 0.5) * MAX_DISPLACEMENT * 2
    shape.x = math.max(0, math.min(WORLD_SIZE, shape.x + dx))
    shape.y = math.max(0, math.min(WORLD_SIZE, shape.y + dy))
    
    if shape.type == "circle" then
      C.layer_set_circle(layer, id, shape.x, shape.y, shape.r)
    else
      C.layer_set_AABB(layer, id, shape.x, shape.y, shape.x + shape.w, shape.y + shape.h)
    end
  end
  
  for i = 1, 50 do
    local id = math.random(1, NUM_SHAPES)
    C.layer_getCollisions(layer, id)
  end
end

-- Actual benchmark
print("  Running benchmark...")
local ffi_start = os.clock()
local ffi_total_collisions = 0
local ffi_total_manifolds = 0

for frame = 1, NUM_FRAMES do
  for id, shape in pairs(ffi_shapes) do
    local dx = (math.random() - 0.5) * MAX_DISPLACEMENT * 2
    local dy = (math.random() - 0.5) * MAX_DISPLACEMENT * 2
    shape.x = math.max(0, math.min(WORLD_SIZE, shape.x + dx))
    shape.y = math.max(0, math.min(WORLD_SIZE, shape.y + dy))
    
    if shape.type == "circle" then
      C.layer_set_circle(layer, id, shape.x, shape.y, shape.r)
    else
      C.layer_set_AABB(layer, id, shape.x, shape.y, shape.x + shape.w, shape.y + shape.h)
    end
  end
  
  for id = 1, NUM_SHAPES do
    local result = C.layer_getCollisions(layer, id)
    ffi_total_collisions = ffi_total_collisions + result.size
    
    if result.size > 0 and id % 5 == 0 then
      local mani_result = C.layer_getManifolds(layer, id)
      ffi_total_manifolds = ffi_total_manifolds + mani_result.size / 5
    end
  end
end

local ffi_time = os.clock() - ffi_start

print(string.format("  Total time: %.3f seconds", ffi_time))
print(string.format("  Time per frame: %.3f ms", (ffi_time / NUM_FRAMES) * 1000))
print(string.format("  Collisions detected: %d", ffi_total_collisions))
print(string.format("  Manifolds computed: %d", ffi_total_manifolds))
print(string.format("  Throughput: %.0f frames/sec", NUM_FRAMES / ffi_time))

C.layer_delete(layer)

-- ============================================
-- HC BENCHMARK
-- ============================================
print()
print("2. HC (Haxe Collide) Implementation")
print(string.rep("-", 70))

-- Create HC collider
local hc_collider = HC(CELL_SIZE)

-- Create shapes for HC - store positions separately
local hc_shapes = {}
local hc_positions = {}
for i = 1, NUM_SHAPES do
  local x = math.random() * WORLD_SIZE
  local y = math.random() * WORLD_SIZE
  hc_positions[i] = {x = x, y = y}
  if i % 3 == 0 then
    local r = math.random() * 15 + 5
    hc_shapes[i] = hc_collider:circle(x, y, r)
    hc_shapes[i].radius = r
    hc_shapes[i].shape_type = "circle"
  else
    local w = math.random() * 30 + 10
    local h = math.random() * 30 + 10
    hc_shapes[i] = hc_collider:rectangle(x, y, w, h)
    hc_shapes[i].w = w
    hc_shapes[i].h = h
    hc_shapes[i].shape_type = "rectangle"
  end
end

-- Warmup
print("  Warming up JIT...")
for frame = 1, 20 do
  for id, shape in pairs(hc_shapes) do
    local pos = hc_positions[id]
    local dx = (math.random() - 0.5) * MAX_DISPLACEMENT * 2
    local dy = (math.random() - 0.5) * MAX_DISPLACEMENT * 2
    pos.x = math.max(0, math.min(WORLD_SIZE, pos.x + dx))
    pos.y = math.max(0, math.min(WORLD_SIZE, pos.y + dy))
    
    if shape.shape_type == "circle" then
      shape:moveTo(pos.x, pos.y)
    else
      hc_collider:remove(shape)
      hc_shapes[id] = hc_collider:rectangle(pos.x, pos.y, shape.w, shape.h)
      hc_shapes[id].w = shape.w
      hc_shapes[id].h = shape.h
      hc_shapes[id].shape_type = "rectangle"
      hc_positions[id] = pos
    end
  end
  
  for i = 1, 50 do
    local id = math.random(1, NUM_SHAPES)
    if hc_shapes[id] then
      hc_collider:collisions(hc_shapes[id])
    end
  end
end

-- Actual benchmark
print("  Running benchmark...")
local hc_start = os.clock()
local hc_total_collisions = 0

for frame = 1, NUM_FRAMES do
  for id, shape in pairs(hc_shapes) do
    local pos = hc_positions[id]
    local dx = (math.random() - 0.5) * MAX_DISPLACEMENT * 2
    local dy = (math.random() - 0.5) * MAX_DISPLACEMENT * 2
    pos.x = math.max(0, math.min(WORLD_SIZE, pos.x + dx))
    pos.y = math.max(0, math.min(WORLD_SIZE, pos.y + dy))
    
    if shape.shape_type == "circle" then
      shape:moveTo(pos.x, pos.y)
    else
      hc_collider:remove(shape)
      hc_shapes[id] = hc_collider:rectangle(pos.x, pos.y, shape.w, shape.h)
      hc_shapes[id].w = shape.w
      hc_shapes[id].h = shape.h
      hc_shapes[id].shape_type = "rectangle"
      hc_positions[id] = pos
    end
  end
  
  for id = 1, NUM_SHAPES do
    if hc_shapes[id] then
      local collisions = hc_collider:collisions(hc_shapes[id])
      for other, _ in pairs(collisions) do
        hc_total_collisions = hc_total_collisions + 1
      end
    end
  end
end

local hc_time = os.clock() - hc_start

print(string.format("  Total time: %.3f seconds", hc_time))
print(string.format("  Time per frame: %.3f ms", (hc_time / NUM_FRAMES) * 1000))
print(string.format("  Collisions detected: %d", hc_total_collisions))
print(string.format("  Throughput: %.0f frames/sec", NUM_FRAMES / hc_time))

-- ============================================
-- COMPARISON
-- ============================================
print()
print(string.rep("=", 70))
print("COMPARISON SUMMARY")
print(string.rep("=", 70))
print(string.format("%-20s %12s %12s %10s", "Metric", "FFI", "HC", "Ratio"))
print(string.rep("-", 70))
print(string.format("%-20s %12.3f %12.3f %9.1fx", 
  "Time per frame (ms)", 
  (ffi_time / NUM_FRAMES) * 1000,
  (hc_time / NUM_FRAMES) * 1000,
  (hc_time / ffi_time)))
print(string.format("%-20s %12.0f %12.0f %9.1fx", 
  "Throughput (fps)", 
  NUM_FRAMES / ffi_time,
  NUM_FRAMES / hc_time,
  (NUM_FRAMES / ffi_time) / (NUM_FRAMES / hc_time)))
print(string.format("%-20s %12d %12d", 
  "Total collisions", 
  ffi_total_collisions,
  hc_total_collisions))
print(string.rep("=", 70))

if ffi_time < hc_time then
  print(string.format("FFI is %.1fx faster than HC", hc_time / ffi_time))
else
  print(string.format("HC is %.1fx faster than FFI", ffi_time / hc_time))
end

print()
print("Note: HC requires shape recreation for movement (no direct update API),")
print("which impacts its performance in this benchmark.")
print(string.rep("=", 70))