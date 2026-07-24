SIMULTANEOUS_THREADS = 4
BACKGROUND_COLOR = { x = 0, y = 0, z = 0 }
Scene = {
	spheres = {},
	lights = {},
	triangles = {},
	addSphere = function(c, r, color, specular, reflective)
		table.insert(
			Scene.spheres,
			{ center = c, radius_squared = r, color = color, specular = specular, reflective = reflective }
		)
	end,
	addTriangle = function(a, b, c, color, specular, reflective)
		table.insert(
			Scene.triangles,
			{ position = { a, b, c }, color = color, specular = specular, reflective = reflective }
		)
	end,
	addLight = function(type, intensity, position, direction)
		if type == "ambient" then
			table.insert(Scene.lights, { type = type, intensity = intensity })
		end

		if type == "point" then
			table.insert(Scene.lights, { type = type, intensity = intensity, position = position })
		end

		if type == "directional" then
			table.insert(Scene.lights, { type = type, intensity = intensity, direction = direction })
		end
	end,
}

love.window.setMode(1000, 1000)

Scene.addSphere({ x = 0, y = -1, z = 3 }, 1, { 1, 0, 0, 1 }, 500, 0.2)
Scene.addSphere({ x = 2, y = 0, z = 4 }, 1, { 0, 0, 1, 1 }, 500, 0.3)
Scene.addSphere({ x = -2, y = 0, z = 4 }, 1, { 0, 1, 0, 1 }, 10, 0.4)
Scene.addSphere({ x = 0, y = -5001, z = 0 }, 25000000, { 1, 1, 0, 1 }, 1000, 0.5)
Scene.addTriangle({ x = 1, y = 0, z = 1 }, { x = 2, y = 3, z = 5 }, { x = 6, y = 7, z = 8 }, { 1, 0, 0, 1 }, 500, 0.2)
Scene.addLight("ambient", 0.2, nil, nil)
Scene.addLight("point", 0.6, { x = 2, y = 1, z = 0 })
Scene.addLight("directional", 0.2, nil, { x = 1, y = 4, z = 4 })

Camera = {
	position = { x = 1, y = 0, z = 0 },
	rotation = {
		{ 0.7, 0, -0.7 },
		{ 0, 1, 0 },
		{ 0.7, 0, 0.7 },
	},
}

Viewport = {
	distance = 1,
	width = 1,
	height = 1,
}
VIEWPORT_SIZE = 1
PROJECTION_PLANE_Z = 1

_, _, WindowWidth, WindowHeight = love.window.getSafeArea()
Canvas = {
	width = WindowWidth,
	height = WindowHeight,
}

function GetViewportPx(x, y)
	return {
		x = x * VIEWPORT_SIZE / Canvas.width,
		y = -y * VIEWPORT_SIZE / Canvas.height,
		z = PROJECTION_PLANE_Z,
	}
end

function Cross2D(ax, ay, bx, by)
	return ax * by - ay * bx
end

function Cross3D(ax, ay, az, bx, by, bz)
	local xComp = ay * bz - az * by
	local yComp = az * bx - ax * bz
	local zComp = ax * by - ay * bx
	return { x = xComp, y = yComp, z = zComp }
end

function InBaryCoords(ax, ay, bx, by, cx, cy, px, py)
	local mainArea = Cross2D(bx - ax, by - ay, cx - ax, cy - ay)
	local subtri1Area = Cross2D(bx - px, by - py, cx - px, cy - py) / mainArea
	local subtri2Area = Cross2D(cx - px, cy - py, ax - px, ay - py) / mainArea
	local subtri3Area = 1 - subtri1Area - subtri2Area
	return (subtri1Area >= 0 and subtri2Area >= 0 and subtri3Area >= 0)
end

Vec = {
	dot = function(V1, V2)
		return (V1.x * V2.x) + (V1.y * V2.y) + (V1.z * V2.z)
	end,
	mult = function(V1, V2)
		return { x = (V1.x * V2.x), y = (V1.y * V2.y), z = (V1.z * V2.z) }
	end,
	add = function(V1, V2)
		return { x = (V1.x + V2.x), y = (V1.y + V2.y), z = (V1.z + V2.z) }
	end,
	sub = function(V1, V2)
		return { x = (V1.x - V2.x), y = (V1.y - V2.y), z = (V1.z - V2.z) }
	end,
	neg = function(V)
		return { x = -V.x, y = -V.y, z = -V.z }
	end,
	length = function(V)
		return math.sqrt(V.x * V.x + V.y * V.y + V.z * V.z)
	end,
	drop = function(V)
		local absX, absY, absZ = math.abs(V.x), math.abs(V.y), math.abs(V.z)
		if absX > absY and absX > absZ then
			return "x"
		elseif absY > absX and absY > absZ then
			return "y"
		end
		return "z"
	end,
}

function ProjectTo2D(V, drop)
	if drop == "x" then
		return { x = V.y, y = V.z }
	elseif drop == "y" then
		return { x = V.x, y = V.z }
	end
	return { x = V.x, y = V.y }
end

function IntersectRayTriangle(origin, direction, triangle)
	local edge1 = Vec.sub(triangle.position[2], triangle.position[1])
	local edge2 = Vec.sub(triangle.position[3], triangle.position[1])
	local normal = Cross3D(edge1.x, edge1.y, edge1.z, edge2.x, edge2.y, edge2.z)
	local distance = Vec.dot(normal, triangle.position[1])
	local t = (distance - Vec.dot(normal, origin)) / Vec.dot(normal, direction)
	local nDrop = Vec.drop(normal)
	local P = { x = origin.x + t * direction.x, y = origin.y + t * direction.y, z = origin.z + t * direction.z }
	P = ProjectTo2D(P, nDrop)
	local a2 = ProjectTo2D(triangle.position[1], nDrop)
	local b2 = ProjectTo2D(triangle.position[2], nDrop)
	local c2 = ProjectTo2D(triangle.position[3], nDrop)
	local isInsideTri = InBaryCoords(a2.x, a2.y, b2.x, b2.y, c2.x, c2.y, P.x, P.y)
	if isInsideTri then
		return t, normal
	end
	return math.huge, nil
end

function IntersectRaySphere(origin, direction, sphere, a)
	local r2 = sphere.radius_squared
	local CO = Vec.sub(origin, sphere.center)

	local b = 2 * Vec.dot(CO, direction)
	local c = Vec.dot(CO, CO) - r2

	local discriminant = b ^ 2 - 4 * a * c
	if discriminant < 0 then
		return math.huge, math.huge
	end

	local t1 = (-b + math.sqrt(discriminant)) / (2 * a)
	local t2 = (-b - math.sqrt(discriminant)) / (2 * a)
	return t1, t2
end

function AnyIntersection(origin, direction, t_min, t_max)
	local lastIntersectedSphere = nil
	local a = Vec.dot(direction, direction)

	for _, sphere in ipairs(Scene.spheres) do
		if sphere ~= lastIntersectedSphere then
			local t1, t2 = IntersectRaySphere(origin, direction, sphere, a)
			if (t_min < t1 and t1 < t_max) or (t_min < t2 and t2 < t_max) then
				lastIntersectedSphere = sphere
				return true
			end
		end
	end

	return false
end

function ClosestIntersection(origin, direction, t_min, t_max)
	local closest_t = 999999
	local closest_normal = nil
	local closest_triangle = nil
	local closest_sphere = nil

	local a = Vec.dot(direction, direction)

	for _, triangle in ipairs(Scene.triangles) do
		local t, normal = IntersectRayTriangle(origin, direction, triangle)
		if t_min < t and t_max > t and t < closest_t then
			closest_t = t
			closest_triangle = triangle
			closest_normal = normal
		end
	end

	for _, sphere in ipairs(Scene.spheres) do
		local t1, t2 = IntersectRaySphere(origin, direction, sphere, a)

		if t_min < t1 and t_max > t1 and t1 < closest_t then
			closest_t = t1
			closest_sphere = sphere
		end

		if t_min < t2 and t_max > t2 and t2 < closest_t then
			closest_t = t2
			closest_sphere = sphere
		end
	end

	return closest_sphere, closest_triangle, closest_t, closest_normal
end

function TraceRay(origin, direction, t_min, t_max, recursion_depth)
	local closest_sphere, closest_triangle, closest_t, closest_normal =
		ClosestIntersection(origin, direction, t_min, t_max)

	if closest_sphere == nil and closest_triangle == nil then
		return BACKGROUND_COLOR
	end

	local position = {
		x = closest_t * direction.x,
		y = closest_t * direction.y,
		z = closest_t * direction.z,
	}
	position = { x = position.x + origin.x, y = position.y + origin.y, z = position.z + origin.z }
	local normal
	if closest_triangle ~= nil then
		normal = closest_normal
	else
		normal = Vec.sub(position, closest_sphere.center)
	end

	local closest_object = closest_triangle or closest_sphere
	local intensity = ComputeLighting(position, normal, Vec.neg(direction), closest_object.specular)

	local local_color = {
		x = closest_object.color[1] * intensity,
		y = closest_object.color[2] * intensity,
		z = closest_object.color[3] * intensity,
	}

	local r = closest_object.reflective
	if recursion_depth <= 0 or r <= 0 then
		return local_color
	end
	normal = { x = normal.x / Vec.length(normal), y = normal.y / Vec.length(normal), z = normal.z / Vec.length(normal) }
	local ray = ReflectRay(Vec.neg(direction), normal)
	local reflected_color = TraceRay(position, ray, 0.001, math.huge, recursion_depth - 1)

	local trm_1 = Vec.mult(local_color, { x = (1 - r), y = (1 - r), z = (1 - r) })
	return Vec.add(trm_1, { x = reflected_color.x * r, y = reflected_color.y * r, z = reflected_color.z * r })
end

function ReflectRay(ray, normal)
	return Vec.sub(
		Vec.mult(
			Vec.mult({ x = 2, y = 2, z = 2 }, normal),
			{ x = Vec.dot(normal, ray), y = Vec.dot(normal, ray), z = Vec.dot(normal, ray) }
		),
		ray
	)
end

function ComputeLighting(position, normal, direction, s)
	local intensity = 0.0
	local light_position = nil
	local t_max = math.huge
	for _, light in ipairs(Scene.lights) do
		if light.type == "ambient" then
			intensity = intensity + light.intensity
		else
			if light.type == "point" then
				light_position = Vec.sub(light.position, position)
				t_max = 1
			else
				light_position = light.direction
				t_max = math.huge
			end

			if AnyIntersection(position, light_position, 0.001, t_max) then
				goto continue
			end
			local n_dot_1 = Vec.dot(normal, light_position)
			if n_dot_1 > 0 then
				intensity = intensity + light.intensity * n_dot_1 / (Vec.length(normal) * Vec.length(light_position))
			end

			if s ~= -1 then
				local ray = ReflectRay(light_position, normal)
				local r_dot_v = Vec.dot(ray, direction)
				if r_dot_v > 0 then
					intensity = intensity
						+ light.intensity * math.pow((r_dot_v / (Vec.length(ray) * Vec.length(direction))), s)
				end
			end
		end
		::continue::
	end
	return intensity
end

function MultiplyMatrixVector(M, V)
	local result = { 0, 0, 0 }
	local vec = { V.x, V.y, V.z }

	for i = 1, 3 do
		for j = 1, 3 do
			result[i] = result[i] + (vec[j] * M[i][j])
		end
	end

	return { x = result[1], y = result[2], z = result[3] }
end

function love.update(dt)
	local speed = 0.5
	local forward = {
		x = Camera.rotation[1][3],
		y = Camera.rotation[2][3],
		z = Camera.rotation[3][3],
	}
	local forwardResult = { x = forward.x * speed, y = forward.y * speed, z = forward.z * speed }
	if love.keyboard.isDown("a") then
	elseif love.keyboard.isDown("d") then
	end

	if love.keyboard.isDown("w") then
		Camera.position = Vec.add(Camera.position, forwardResult)
	elseif love.keyboard.isDown("s") then
		Camera.position = Vec.sub(Camera.position, forwardResult)
	end
end

Rotation = 0.1
Position = 1
function love.keypressed(key)
	local speed = 0.5
	local forward = {
		x = Camera.rotation[1][3],
		y = Camera.rotation[2][3],
		z = Camera.rotation[3][3],
	}
	local forwardResult = { x = forward.x * speed, y = forward.y * speed, z = forward.z * speed }
	if key == "a" then
		Rotation = Rotation + 0.1
	end
	if key == "d" then
		Rotation = Rotation - 0.1
	end
	Camera.rotation = {
		{ math.cos(Rotation), 0, -math.sin(Rotation) },
		{ 0, 1, 0 },
		{ math.sin(Rotation), 0, math.cos(Rotation) },
	}
end

SUBSAMPLE_AMOUNT = 12
function love.draw()
	for x = -Canvas.width / 2, Canvas.width / 2, SUBSAMPLE_AMOUNT do
		for y = -Canvas.height / 2, Canvas.height / 2, SUBSAMPLE_AMOUNT do
			local direction = MultiplyMatrixVector(Camera.rotation, GetViewportPx(x, y))
			local recursion_depth = 3
			local color = TraceRay(Camera.position, direction, 1, 999999, recursion_depth)
			love.graphics.setColor({ color.x, color.y, color.z, 1 })
			love.graphics.rectangle(
				"fill",
				x + Canvas.width / 2,
				y + Canvas.height / 2,
				SUBSAMPLE_AMOUNT,
				SUBSAMPLE_AMOUNT
			)
		end
	end
end
