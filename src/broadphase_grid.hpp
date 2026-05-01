
#pragma once

#include <algorithm>
#include <cmath>
#include <cstdint>
#include <unordered_map>
#include <unordered_set>
#include <vector>

class BroadphaseGrid {
public:
  BroadphaseGrid(float cell_size) { cell_size_ = cell_size; };

  struct AABB {
    float min_x, min_y, max_x, max_y;
  };

  void update(uint id, AABB aabb) {
    CellBounds new_bounds = get_cell_bounds(aabb);

    auto it = object_bounds_.find(id);
    if (it != object_bounds_.end()) {

      const CellBounds &old_bounds = it->second;
      // if (new_bounds == old_bounds) {
      //   return; // No change
      // }

      remove_from_cells(id, old_bounds);

      it->second = new_bounds;
    } else {
      // New object
      object_bounds_[id] = new_bounds;
    }

    // Add to new cells
    add_to_cells(id, new_bounds);
  }

  void remove(uint id) {
    auto it = object_bounds_.find(id);
    if (it == object_bounds_.end())
      return;

    remove_from_cells(id, it->second);
    object_bounds_.erase(it);
  }

private:
  struct Cell {
    std::vector<uint> ids;
    auto begin() const { return ids.begin(); }
    auto end() const { return ids.end(); }
    void insert(uint id) { ids.push_back(id); };
    void erase(uint id) {
      auto it = std::find(ids.begin(), ids.end(), id);
      if (it != ids.end()) {
        *it = ids.back();
        ids.pop_back();
      }
    }
  };

public:
  std::vector<uint> raycast(float start_x, float start_y, float dx, float dy) {
    std::unordered_set<uint> visited_cache;
    std::vector<uint> out;

    float length = std::sqrt(dx * dx + dy * dy);
    if (length == 0)
      return out;

    dx /= length;
    dy /= length;

    RayIterator ray(start_x, start_y, dx, dy, cell_size_);
    float t = 0;

    while (t < length) {
      uint32_t cell_key = ray.current_cell();
      auto it = cell_key_to_index_.find(cell_key);

      if (it != cell_key_to_index_.end()) {
        const Cell& cell = cells_[it->second];
        for (const auto id : cell.ids) {
          if (visited_cache.insert(id).second) {
            out.push_back(id);
          }
        }
      }
      float next_t = ray.current_t();
      if (next_t >= length)
        break;
      ray.next();
      t = next_t;
    }
    return out;
  }

  std::unordered_set<uint> &query(uint id) {
    visited_set.clear();

    auto it = object_bounds_.find(id);
    if (it == object_bounds_.end()) {
      return visited_set;
    }
    CellBounds bounds = it->second;
    for (uint32_t key : get_cell_keys(bounds)) {
      auto cell_it = cell_key_to_index_.find(key);
      if (cell_it != cell_key_to_index_.end()) {
        visited_set.insert(cells_[cell_it->second].begin(), cells_[cell_it->second].end());
      }
    };
    return visited_set;
  }

  std::unordered_set<uint> &queryAABB(const AABB &aabb) {
    visited_set.clear();
    for (uint32_t key : get_cell_keys(get_cell_bounds(aabb))) {
      auto it = cell_key_to_index_.find(key);
      if (it != cell_key_to_index_.end()) {
        visited_set.insert(cells_[it->second].begin(), cells_[it->second].end());
      }
    };
    return visited_set;
  }

 private:
  struct CellBounds {
    int min_cx, min_cy, max_cx, max_cy;
    bool operator==(const CellBounds &other) const {
      return min_cx == other.min_cx && min_cy == other.min_cy &&
             max_cx == other.max_cx && max_cy == other.max_cy;
    }
  };

  float cell_size_;
  // Use vector instead of unordered_map for faster access
  // Index = encoded cell key, with sparse allocation using a hash map for key->index lookup
  std::vector<Cell> cells_;
  std::unordered_map<uint32_t, size_t> cell_key_to_index_;
  std::unordered_map<uint, CellBounds> object_bounds_;
  std::unordered_set<uint> visited_set;

  static constexpr int32_t UOFFSET = 32768;
  static constexpr uint32_t MAX_CELLS = 65536; // Max cells for direct indexing

  static uint32_t encode_cell(int x, int y) {
    return (static_cast<int32_t>(x + UOFFSET) << 16) |
           static_cast<uint32_t>(y + UOFFSET);
  };

  static std::pair<int, int> decode_cell(uint32_t key) {
    int x = static_cast<int>(key >> 16) - UOFFSET;
    int y = static_cast<int>(key) - UOFFSET;
    return {x, y};
  };

  int world_to_cell(float world) const {
    return static_cast<int>(std::floor(world / cell_size_));
  };

  CellBounds get_cell_bounds(const AABB &aabb) const {
    return {.min_cx = world_to_cell(aabb.min_x),
            .min_cy = world_to_cell(aabb.min_y),
            .max_cx = world_to_cell(aabb.max_x),
            .max_cy = world_to_cell(aabb.max_y)};
  };

  std::vector<uint32_t> get_cell_keys(const CellBounds &bounds) const {
    std::vector<uint32_t> keys;
    for (int cy = bounds.min_cy; cy <= bounds.max_cy; cy++) {
      for (int cx = bounds.min_cx; cx <= bounds.max_cx; cx++) {
        keys.push_back(encode_cell(cx, cy));
      };
    }
    return keys;
  };

  Cell& get_or_create_cell(uint32_t key) {
    auto it = cell_key_to_index_.find(key);
    if (it != cell_key_to_index_.end()) {
      return cells_[it->second];
    }
    // Create new cell
    size_t index = cells_.size();
    cells_.emplace_back();
    cell_key_to_index_[key] = index;
    return cells_[index];
  }

  void add_to_cells(uint id, const CellBounds &bounds) {
    auto keys = get_cell_keys(bounds);
    for (uint32_t key : keys) {
      get_or_create_cell(key).insert(id);
    }
  };

  void remove_from_cells(uint id, const CellBounds &bounds) {
    auto keys = get_cell_keys(bounds);
    for (uint32_t key : keys) {
      auto it = cell_key_to_index_.find(key);
      if (it != cell_key_to_index_.end()) {
        cells_[it->second].erase(id);
      }
    }
  };

  class RayIterator {
  private:
    float x_, y_;
    int cell_x_, cell_y_;
    float t_max_x_, t_max_y_;
    float t_delta_x_, t_delta_y_;
    int step_x_, step_y_;
    bool infinite_x_, infinite_y_;

  public:
    RayIterator(float start_x, float start_y, float dx, float dy,
                float cell_size)
        : x_(start_x), y_(start_y) {

      cell_x_ = static_cast<int>(std::floor(start_x / cell_size));
      cell_y_ = static_cast<int>(std::floor(start_y / cell_size));

      infinite_x_ = (dx == 0);
      infinite_y_ = (dy == 0);

      step_x_ = (dx > 0) ? 1 : -1;
      step_y_ = (dy > 0) ? 1 : -1;

      // Next cell boundary in x
      if (!infinite_x_) {
        float next_boundary_x = (cell_x_ + (dx > 0 ? 1 : 0)) * cell_size;
        t_max_x_ = (next_boundary_x - start_x) / dx;
        t_delta_x_ = cell_size / std::abs(dx);
      } else {
        t_max_x_ = std::numeric_limits<float>::max();
        t_delta_x_ = std::numeric_limits<float>::max();
      }

      // Next cell boundary in y
      if (!infinite_y_) {
        float next_boundary_y = (cell_y_ + (dy > 0 ? 1 : 0)) * cell_size;
        t_max_y_ = (next_boundary_y - start_y) / dy;
        t_delta_y_ = cell_size / std::abs(dy);
      } else {
        t_max_y_ = std::numeric_limits<float>::max();
        t_delta_y_ = std::numeric_limits<float>::max();
      }
    }

    uint32_t current_cell() const { return encode_cell(cell_x_, cell_y_); }

    void next() {
      if (t_max_x_ < t_max_y_) {
        cell_x_ += step_x_;
        t_max_x_ += t_delta_x_;
      } else {
        cell_y_ += step_y_;
        t_max_y_ += t_delta_y_;
      }
    }

    float current_t() const { return std::min(t_max_x_, t_max_y_); }
  };
};
