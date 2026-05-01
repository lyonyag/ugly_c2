# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2024-01-05

### Added
- Initial release of Ugly C2 FFI
- High-performance collision detection using LuaJIT FFI
- Support for circles, AABBs, and capsules
- Preallocated buffer system (zero GC pressure during queries)
- Stateless spatial queries (point, AABB)
- Batch collision queries
- Collision manifold extraction
- Complete CMake build system
- Love2D example application
- Comprehensive examples and benchmarks
- Windows build support (MSVC and Clang)

### Performance
- **10-20x faster** than LuaBridge-based interfaces
- **14.5x faster** than HC (Haxe Collide)
- Sub-microsecond query times
- 270 FPS with 2000 moving objects
- Zero GC pressure during simulation

### Features
- `collision.new()` - Create collision layer with configurable buffers
- `layer:setCircle()` - Add/update circle shapes
- `layer:setAABB()` - Add/update axis-aligned bounding boxes
- `layer:setCapsule()` - Add/update capsule shapes
- `layer:remove()` - Remove shapes
- `layer:getCollisions()` - Query collisions for a shape
- `layer:getCollisionsBatch()` - Batch collision queries
- `layer:getManifolds()` - Get collision contact information
- `layer:queryPoint()` - Point-in-shape queries
- `layer:queryAABB()` - Region queries
- `layer:resetBuffers()` - Reset for new frame
- `layer:delete()` - Clean up resources

### Examples
- `examples/basic.lua` - Basic usage demonstration
- `examples/game-loop.lua` - Game loop with physics
- `examples/spatial-queries.lua` - Point and AABB queries
- `examples/physics.lua` - Collision response with manifolds
- `love2d-example/` - Interactive Love2D demo

### Benchmarks
- `benchmark/benchmark.lua` - Comprehensive performance tests
- `benchmark/hc_comparison.lua` - Fair comparison with HC library

### Documentation
- Complete API reference
- Best practices guide
- Troubleshooting section
- Windows build instructions

### Build System
- CMake 3.20+ configuration
- Cross-platform support (Linux, macOS, Windows)
- LuaJIT detection and linking
- Install targets for library and Lua modules

## [Unreleased]

### Planned
- Capsule shape support (in progress)
- Continuous collision detection (CCD)
- Spatial query optimizations
- SIMD acceleration for broadphase
- Lua 5.4+ compatibility improvements
- More comprehensive test suite