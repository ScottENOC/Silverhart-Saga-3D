extends RefCounted
## Capsule collision proxies for a posed body. Pure maths, no scene dependency.
## A proxy is a Dictionary: {id: StringName, a: Vector3, b: Vector3, radius: float}.
## All positions share one space (the rig space defined in docs/posing/POSING_CONTRACT.md).

static func make(id: StringName, a: Vector3, b: Vector3, radius: float) -> Dictionary:
	return {"id": id, "a": a, "b": b, "radius": radius}


## Minimum distance between segments p1-q1 and p2-q2.
## Ericson, Real-Time Collision Detection, 5.1.9.
static func segment_distance(p1: Vector3, q1: Vector3, p2: Vector3, q2: Vector3) -> float:
	const EPS := 1e-12
	var d1 := q1 - p1
	var d2 := q2 - p2
	var r := p1 - p2
	var a := d1.dot(d1)
	var e := d2.dot(d2)
	var f := d2.dot(r)
	var s := 0.0
	var t := 0.0
	if a <= EPS and e <= EPS:
		return p1.distance_to(p2)
	if a <= EPS:
		t = clampf(f / e, 0.0, 1.0)
	else:
		var c := d1.dot(r)
		if e <= EPS:
			s = clampf(-c / a, 0.0, 1.0)
		else:
			var b := d1.dot(d2)
			var denom := a * e - b * b
			if denom > EPS:
				s = clampf((b * f - c * e) / denom, 0.0, 1.0)
			t = (b * s + f) / e
			if t < 0.0:
				t = 0.0
				s = clampf(-c / a, 0.0, 1.0)
			elif t > 1.0:
				t = 1.0
				s = clampf((b - c) / a, 0.0, 1.0)
	return (p1 + d1 * s).distance_to(p2 + d2 * t)


## Gap between a capsule and a proxy. Negative means penetration depth.
static func clearance(a: Vector3, b: Vector3, radius: float, proxy: Dictionary) -> float:
	return segment_distance(a, b, proxy["a"], proxy["b"]) - radius - float(proxy["radius"])


## Smallest clearance of a capsule against every proxy whose id is not in `ignore`.
## Returns INF when nothing was tested.
static func min_clearance(a: Vector3, b: Vector3, radius: float, proxies: Array, ignore: Array = []) -> float:
	var result := INF
	for proxy in proxies:
		if ignore.has(proxy["id"]):
			continue
		result = minf(result, clearance(a, b, radius, proxy))
	return result
