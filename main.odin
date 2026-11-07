package main

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:slice"
import "core:strings"
import rl "vendor:raylib"

print :: fmt.println

vec2 :: [2]f32
PI :: math.PI

Triangle :: [3]vec2

Angle_Type :: enum {
	ACUTE, // ACUTE == SHARP == < 180deg
	REFLEX, // REFLEX == OBTUSE == > 180deg
}

active_vertex_index: int = 0
// clockwise winding order
vertices := [?]vec2{{530, 230}, {1250, 280}, {1210, 790}, {810, 780}, {550, 830}}

VERTEX_SIZE :: 30

main :: proc() {

	rl.SetConfigFlags({.WINDOW_RESIZABLE})
	rl.InitWindow(1920, 1080, "Triangulation Demo")

	rl.InitAudioDevice()

	for !rl.WindowShouldClose() {
		handle_input()

		rl.BeginDrawing()

		rl.ClearBackground({0, 0, 0, 0})

		for v, i in vertices {
			color := i == active_vertex_index ? rl.BLUE : rl.GRAY
			draw_vertex(v, color)
		}

		draw_lines()

		draw_neighbours()

		draw_angle_type()

		draw_polygon_triangles()

		rl.EndDrawing()
	}

	rl.CloseWindow()
}

draw_polygon_triangles :: proc() {
	triangles := triangulate_polygon(vertices[:])

	colors := [?]rl.Color {
		rl.DARKBLUE,
		rl.VIOLET,
		rl.SKYBLUE,
		rl.ORANGE,
		rl.RED,
		rl.PINK,
		rl.GOLD,
		rl.LIME,
		rl.GREEN,
		rl.SKYBLUE,
	}

	for t, i in triangles {
		rl.DrawTriangleLines(t[0], t[1], t[2], colors[i])
	}
}

// Assumes clockwise winding order and uses the ear-cut algorithm
triangulate_polygon :: proc(vertices: []vec2, allocator := context.temp_allocator) -> []Triangle {
	checklist := slice.clone_to_dynamic(vertices)
	triangles := make([dynamic]Triangle, 0, len(vertices) - 2, allocator)

	for len(checklist) > 3 {
		checklist_loop: for current, i in checklist {
			prev, next := get_neighbour_vertices(checklist[:], i)

			to_prev := current - prev
			to_next := current - next

			angle_type := get_angle_type(to_prev, to_next)

			if angle_type == .REFLEX {
				continue
			}

			triangle := Triangle{prev, current, next}

			for pos in checklist {
				if pos == current || pos == prev || pos == next {
					continue
				}

				// if any other point is in the triangle, we can't cut it, so we continue the outer loop
				if is_point_inside_triangle(pos, triangle) {
					continue checklist_loop
				}
			}

			append(&triangles, triangle)
			ordered_remove(&checklist, i)
			break
		}
	}

	last_triangle := Triangle{checklist[0], checklist[1], checklist[2]}
	append(&triangles, last_triangle)

	assert(len(triangles) == len(vertices) - 2)
	return triangles[:]
}

is_point_inside_triangle :: proc(point: vec2, triangle: Triangle) -> bool {
	// Defining the triangle as formed of vertices, A, B, C, we compute the edge vectors:
	AB := triangle[1] - triangle[0]
	BC := triangle[2] - triangle[1]
	CA := triangle[0] - triangle[2]

	// Then compute the vectors to the point
	AP := point - triangle[0]
	BP := point - triangle[1]
	CP := point - triangle[2]

	// Then we make sure that the cross products of these components have the same sign,
	// which means that the point "sits" on the same side of all vertices
	// If the point is on the same side for all cross products, the point is inside the triangle,
	// otherwise, it is outside the triangle
	first_cross := linalg.cross(AB, AP)
	second_cross := linalg.cross(BC, BP)
	third_cross := linalg.cross(CA, CP)

	if first_cross > 0 && second_cross > 0 && third_cross > 0 {
		return true
	}

	if first_cross < 0 && second_cross < 0 && third_cross < 0 {
		return true
	}

	return false
}

draw_neighbours :: proc() {
	if active_vertex_index == -1 {
		return
	}

	selected_vert := vertices[active_vertex_index]

	first_neighbour, second_neighbour := get_neighbour_vertices(vertices[:], active_vertex_index)

	rl.DrawCircleV(first_neighbour, 12, rl.RED)
	rl.DrawCircleV(second_neighbour, 12, rl.RED)
}

get_neighbour_vertices :: proc(vertices: []vec2, index: int) -> (n1, n2: vec2) {
	first_index := -1
	second_index := -1

	if index == 0 {
		first_index = len(vertices) - 1
		second_index = index + 1
	} else if index == len(vertices) - 1 {
		first_index = index - 1
		second_index = 0
	} else {
		first_index = index - 1
		second_index = index + 1
	}

	return vertices[first_index], vertices[second_index]
}

handle_input :: proc() {
	if rl.IsMouseButtonPressed(.LEFT) {
		mouse_pos := rl.GetMousePosition()

		is_intersecting_cursor: bool

		for pos, i in vertices {
			is_intersecting_cursor =
				mouse_pos.x > pos.x - VERTEX_SIZE / 2 &&
				mouse_pos.y > pos.y - VERTEX_SIZE / 2 &&
				mouse_pos.x < pos.x + VERTEX_SIZE / 2 &&
				mouse_pos.y < pos.y + VERTEX_SIZE / 2

			if is_intersecting_cursor {
				active_vertex_index = i
				break
			}
		}

		if !is_intersecting_cursor {
			active_vertex_index = -1
		}
	}

	if rl.IsMouseButtonDown(.LEFT) && active_vertex_index != -1 {
		vertices[active_vertex_index] = rl.GetMousePosition()
	}
}

get_angle_type :: proc(v1: vec2, v2: vec2) -> Angle_Type {
	// NOTE: we compute the cross product to see if the angle is pointing "right" or "left" (more or less than 180 degrees)
	// if the polygon is constructed with clockwise winding order, and the cross product is < 0, the angle is more than 180 degrees
	// in which case, we can't form a triangle out of the neighbouring vertices, because the triangle would be outside of the polygon
	cross_product := linalg.cross(v1, v2)

	angle_type: Angle_Type

	if cross_product > 0 {
		angle_type = .REFLEX
	} else {
		angle_type = .ACUTE
	}

	return angle_type
}


draw_angle_type :: proc() {
	if active_vertex_index == -1 {
		return
	}

	font_size: i32 = 24

	selected_vert := vertices[active_vertex_index]

	first_neighbour, second_neighbour := get_neighbour_vertices(vertices[:], active_vertex_index)

	vector_to_first_neighbor := selected_vert - first_neighbour
	vector_to_second_neighbor := selected_vert - second_neighbour

	angle_type := get_angle_type(vector_to_first_neighbor, vector_to_second_neighbor)

	color: rl.Color

	if angle_type == .REFLEX {
		color = rl.RED
	} else {
		color = rl.GREEN
	}

	text := strings.clone_to_cstring(fmt.tprintf("Angle type: %v", angle_type))

	text_size := rl.MeasureText(text, font_size)
	rl.DrawText(text, 1920 / 2 - text_size / 2, 30, font_size, color)
}

draw_lines :: proc() {
	for i in 1 ..< len(vertices) {
		current := vertices[i]
		prev := vertices[i - 1]

		rl.DrawLineV(prev, current, rl.WHITE)
	}
	rl.DrawLineV(vertices[len(vertices) - 1], vertices[0], rl.WHITE)
}

draw_vertex :: proc(pos: vec2, color: rl.Color) {
	rl.DrawRectangleV(pos - VERTEX_SIZE / 2, VERTEX_SIZE, color)

	text := fmt.tprintf("(%v, %v)", pos.x, pos.y)

	c_text := strings.clone_to_cstring(text)

	rl.DrawText(c_text, i32(pos.x) - VERTEX_SIZE / 2, i32(pos.y) + VERTEX_SIZE, 24, color)
}

deg_to_rad :: proc(deg: f32) -> f32 {
	return deg * (PI / 180)
}

rad_to_deg :: proc(radians: f32) -> f32 {
	return radians * (180 / PI)
}
