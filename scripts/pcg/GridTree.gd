extends RefCounted
## Shared grid helpers for the maze and circuit generators.
## Each cell stores a 4-bit mask of OPEN sides: N=1, E=2, S=4, W=8.

const Rng = preload("res://scripts/pcg/Rng.gd")

const N := 1
const E := 2
const S := 4
const W := 8
const DIRS := [1, 2, 4, 8]


static func opposite(dir: int) -> int:
	return ((dir << 2) | (dir >> 2)) & 15


## Neighbour cell index in direction `dir`, or -1 outside the grid.
static func step(cell: int, dir: int, w: int, h: int) -> int:
	var x: int = cell % w
	var y: int = int(cell / w)
	if dir == N:
		y -= 1
	elif dir == S:
		y += 1
	elif dir == E:
		x += 1
	else:
		x -= 1
	if x < 0 or x >= w or y < 0 or y >= h:
		return -1
	return y * w + x


## Rotates a side mask clockwise by `turns` quarter turns.
static func rotate_mask(mask: int, turns: int) -> int:
	var t: int = posmod(turns, 4)
	return ((mask << t) | (mask >> (4 - t))) & 15


## Random spanning tree (depth-first backtracker): every cell reachable, no loops.
static func carve(w: int, h: int, rng: RandomNumberGenerator) -> Array:
	var cells: Array = []
	cells.resize(w * h)
	cells.fill(0)
	var visited: Dictionary = {0: true}
	var stack: Array = [0]
	while not stack.is_empty():
		var cur: int = stack[stack.size() - 1]
		var options: Array = []
		for dir in DIRS:
			var candidate: int = step(cur, int(dir), w, h)
			if candidate >= 0 and not visited.has(candidate):
				options.append(int(dir))
		if options.is_empty():
			stack.pop_back()
			continue
		var chosen: int = int(Rng.pick(options, rng))
		var nxt: int = step(cur, chosen, w, h)
		cells[cur] = int(cells[cur]) | chosen
		cells[nxt] = int(cells[nxt]) | opposite(chosen)
		visited[nxt] = true
		stack.append(nxt)
	return cells


## True when every open side points at an in-grid neighbour that opens back.
static func is_consistent(cells: Array, w: int, h: int) -> bool:
	for cell in cells.size():
		for dir in DIRS:
			if (int(cells[cell]) & int(dir)) == 0:
				continue
			var nxt: int = step(cell, int(dir), w, h)
			if nxt < 0 or (int(cells[nxt]) & opposite(int(dir))) == 0:
				return false
	return true


## Breadth-first search. With `mutual` a link counts only if both cells open to each other.
## Returns {"dist": Array (-1 = unreachable), "via": Array (direction used to enter)}.
static func bfs(cells: Array, w: int, h: int, from: int, mutual: bool = false) -> Dictionary:
	var dist: Array = []
	dist.resize(w * h)
	dist.fill(-1)
	var via: Array = []
	via.resize(w * h)
	via.fill(0)
	dist[from] = 0
	var queue: Array = [from]
	var head: int = 0
	while head < queue.size():
		var cur: int = queue[head]
		head += 1
		for dir in DIRS:
			if (int(cells[cur]) & int(dir)) == 0:
				continue
			var nxt: int = step(cur, int(dir), w, h)
			if nxt < 0 or int(dist[nxt]) >= 0:
				continue
			if mutual and (int(cells[nxt]) & opposite(int(dir))) == 0:
				continue
			dist[nxt] = int(dist[cur]) + 1
			via[nxt] = int(dir)
			queue.append(nxt)
	return {"dist": dist, "via": via}


## Shortest list of directions from one cell to another ([] if unreachable or same cell).
static func path(cells: Array, w: int, h: int, from: int, to: int) -> Array:
	var res: Dictionary = bfs(cells, w, h, from)
	var out: Array = []
	if int(res["dist"][to]) < 0:
		return out
	var cur: int = to
	while cur != from:
		var dir: int = int(res["via"][cur])
		out.push_front(dir)
		cur = step(cur, opposite(dir), w, h)
	return out
