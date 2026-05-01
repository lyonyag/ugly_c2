package.path = package.path .. ";?.lua;?/init.lua"

local ffi = require("ffi")

ffi.cdef[[
typedef struct {
  void *data;
  size_t size;
  size_t element_size;
} ArrayHandle;

typedef struct {
  void *data;
  size_t capacity;
  size_t count;
} CollisionBuffer;

typedef struct {
  void *data;
  size_t capacity;
  size_t count;
} ManifoldBuffer;

typedef struct CollisionLayer CollisionLayer;

typedef struct {
  CollisionLayer *layer;
  CollisionBuffer *collision_buffer;
  ManifoldBuffer *manifold_buffer;
} LayerHandle;

LayerHandle* layer_new_with_buffers(float cell_size, size_t max_collisions, size_t max_manifolds);
void layer_delete(LayerHandle *handle);
void layer_set_circle(LayerHandle *handle, uint32_t id, float x, float y, float r);
void layer_set_AABB(LayerHandle *handle, uint32_t id, float minx, float miny, float maxx, float maxy);
ArrayHandle layer_getCollisions(LayerHandle *handle, uint32_t id);
ArrayHandle layer_getManifolds(LayerHandle *handle, uint32_t id);
ArrayHandle layer_queryPoint(LayerHandle *handle, float x, float y);
ArrayHandle layer_queryAABB(LayerHandle *handle, float minx, float miny, float maxx, float maxy);
]]

local C = ffi.load("./build/ugly_c2_ffi.so")

-- Benchmark configuration
local NUM_SHAPES = 5000
local NUM_QUERIES = 1000
local WORLD_SIZE = 1000.0
local CELL_SIZE = 32.0

math.randomseed(os.time())

-- Create layer with large buffers
local layer = C.layer_new_with_buffers(CELL_SIZE, NUM_SHAPES * 4, NUM_SHAPES)

-- Generate random shapes
print("Creating " .. NUM_SHAPES .. " shapes...")
local create_start = os.clock()

for i = 1, NUM_SHAPES do
  local x = math.random() * WORLD_SIZE
  local y = math.random() * WORLD_SIZE
  local r = math.random() * 10 + 5
  
  if i % 3 == 0 then
    C.layer_set_circle(layer, i, x, y, r)
  else
    local w = math.random() * 20 + 10
    local h = math.random() * 20 + 10
    C.layer_set_AABB(layer, i, x, y, x + w, y + h)
  end
end

local create_time = os.clock() - create_start
print(string.format("  Creation time: %.4f seconds", create_time))

-- Benchmark 1: Collision queries
print("\nBenchmark 1: Collision queries (" .. NUM_QUERIES .. " queries)")
local query_start = os.clock()
local total_collisions = 0

for i = 1, NUM_QUERIES do
  local id = math.random(1, NUM_SHAPES)
  local result = C.layer_getCollisions(layer, id)
  total_collisions = total_collisions + result.size
end

local query_time = os.clock() - query_start
print(string.format("  Time: %.4f seconds", query_time))
print(string.format("  Avg per query: %.4f ms", (query_time / NUM_QUERIES) * 1000))
print(string.format("  Throughput: %.0f queries/sec", NUM_QUERIES / query_time))
print(string.format("  Total collisions found: %d", total_collisions))

-- Benchmark 2: Manifold queries
print("\nBenchmark 2: Manifold queries (" .. NUM_QUERIES .. " queries)")
local manifold_start = os.clock()
local total_manifolds = 0

for i = 1, NUM_QUERIES do
  local id = math.random(1, NUM_SHAPES)
  local result = C.layer_getManifolds(layer, id)
  total_manifolds = total_manifolds + result.size / 5  -- 5 floats per manifold
end

local manifold_time = os.clock() - manifold_start
print(string.format("  Time: %.4f seconds", manifold_time))
print(string.format("  Avg per query: %.4f ms", (manifold_time / NUM_QUERIES) * 1000))
print(string.format("  Throughput: %.0f queries/sec", NUM_QUERIES / manifold_time))
print(string.format("  Total manifolds found: %d", total_manifolds))

-- Benchmark 3: Point queries
print("\nBenchmark 3: Point queries (" .. NUM_QUERIES .. " queries)")
local point_start = os.clock()
local total_points = 0

for i = 1, NUM_QUERIES do
  local x = math.random() * WORLD_SIZE
  local y = math.random() * WORLD_SIZE
  local result = C.layer_queryPoint(layer, x, y)
  total_points = total_points + result.size
end

local point_time = os.clock() - point_start
print(string.format("  Time: %.4f seconds", point_time))
print(string.format("  Avg per query: %.4f ms", (point_time / NUM_QUERIES) * 1000))
print(string.format("  Throughput: %.0f queries/sec", NUM_QUERIES / point_time))
print(string.format("  Total points found: %d", total_points))

-- Benchmark 4: AABB queries
print("\nBenchmark 4: AABB queries (" .. NUM_QUERIES .. " queries)")
local aabb_start = os.clock()
local total_aabbs = 0

for i = 1, NUM_QUERIES do
  local x = math.random() * WORLD_SIZE
  local y = math.random() * WORLD_SIZE
  local size = math.random() * 50 + 10
  local result = C.layer_queryAABB(layer, x, y, x + size, y + size)
  total_aabbs = total_aabbs + result.size
end

local aabb_time = os.clock() - aabb_start
print(string.format("  Time: %.4f seconds", aabb_time))
print(string.format("  Avg per query: %.4f ms", (aabb_time / NUM_QUERIES) * 1000))
print(string.format("  Throughput: %.0f queries/sec", NUM_QUERIES / aabb_time))
print(string.format("  Total AABB results: %d", total_aabbs))

-- Benchmark 5: Rapid updates (simulating movement)
print("\nBenchmark 5: Rapid updates (" .. NUM_QUERIES .. " updates)")
local update_start = os.clock()

for i = 1, NUM_QUERIES do
  local id = math.random(1, NUM_SHAPES)
  local x = math.random() * WORLD_SIZE
  local y = math.random() * WORLD_SIZE
  local r = math.random() * 10 + 5
  C.layer_set_circle(layer, id, x, y, r)
end

local update_time = os.clock() - update_start
print(string.format("  Time: %.4f seconds", update_time))
print(string.format("  Avg per update: %.4f ms", (update_time / NUM_QUERIES) * 1000))
print(string.format("  Throughput: %.0f updates/sec", NUM_QUERIES / update_time))

-- Summary
print("\n" .. string.rep("=", 60))
print("SUMMARY")
print(string.rep("=", 60))
print(string.format("Total shapes: %d", NUM_SHAPES))
print(string.format("Total queries: %d", NUM_QUERIES * 4))
print(string.format("Total time: %.4f seconds", 
  query_time + manifold_time + point_time + aabb_time + update_time))
print(string.format("Memory: Preallocated buffers (no GC during benchmarks)"))

C.layer_delete(layer)
print("\nBenchmark completed!")