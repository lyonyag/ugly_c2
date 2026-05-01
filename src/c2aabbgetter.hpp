#pragma once

#include "broadphase_grid.hpp"
#include "c2wrapper.hpp"

#include <algorithm>
#include <variant>


BroadphaseGrid::AABB getAABB(const c2w::Circle& A){
    float x = A.p.x;
    float y = A.p.y;
    float r = A.r; 
    return {.min_x = x -r,
    .min_y = y - r,
.max_x = x + r,
.max_y = y + r };
}

BroadphaseGrid::AABB getAABB(const c2w::AABB& A){
    return {.min_x = A.min.x,
    .min_y = A.min.y,
.max_x = A.max.x,
.max_y = A.max.y};
}

BroadphaseGrid::AABB getAABB(const c2w::Capsule& A){
    float minx = std::min(A.a.x,A.b.x)-A.r;
    float maxx = std::max(A.a.x,A.b.x)+A.r;
    float miny = std::min(A.a.y,A.b.y)-A.r;
    float maxy = std::max(A.a.y,A.b.y)+A.r;
    return {.min_x = minx, .min_y = miny,  .max_x = maxx, .max_y = maxy};
}

BroadphaseGrid::AABB getAABBc2(const c2w::Shape &A) {
  return std::visit(
      [&](const auto &A) -> BroadphaseGrid::AABB {
        return getAABB(A);
      },
      A);
}