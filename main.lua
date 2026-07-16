BACKGROUND_COLOR = { x = 0, y = 0, z = 0 }
Scene = {
	spheres = {},
	lights = {},
	addSphere = function(c, r, color, specular, reflective)
		table.insert(
			Scene.spheres,
			{ center = c, radius = r, color = color, specular = specular, reflective = reflective }
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
Scene.addSphere({ x = 0, y = -5001, z = 0 }, 5000, { 1, 1, 0, 1 }, 1000, 0.5)
Scene.addLight("ambient", 0.2, nil, nil)
Scene.addLight("point", 0.6, { x = 2, y = 1, z = 0 })
Scene.addLight("directional", 0.2, nil, { x = 1, y = 4, z = 4 })

Camera = {
	position = { x = 1, y = 0, z = 0 },
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

function Dot(V1, V2)
	return (V1.x * V2.x) + (V1.y * V2.y) + (V1.z * V2.z)
end

function Mult(V1, V2)
	return { x = (V1.x * V2.x), y = (V1.y * V2.y), z = (V1.z * V2.z) }
end

function Add(V1, V2)
	return { x = (V1.x + V2.x), y = (V1.y + V2.y), z = (V1.z + V2.z) }
end

function Sub(V1, V2)
	return { x = (V1.x - V2.x), y = (V1.y - V2.y), z = (V1.z - V2.z) }
end

function Negative(V)
	return { x = -V.x, y = -V.y, z = -V.z }
end

function VLength(V)
	return math.sqrt(V.x * V.x + V.y * V.y + V.z * V.z)
end

function IntersectRaySphere(origin, direction, sphere)
	local r = sphere.radius
	local CO = {
		x = origin.x - sphere.center.x,
		y = origin.y - sphere.center.y,
		z = origin.z - sphere.center.z,
	}

	local a = Dot(direction, direction)
	local b = 2 * Dot(CO, direction)
	local c = Dot(CO, CO) - r ^ 2

	local discriminant = b ^ 2 - 4 * a * c
	if discriminant < 0 then
		return math.huge, math.huge
	end

	local t1 = (-b + math.sqrt(discriminant)) / (2 * a)
	local t2 = (-b - math.sqrt(discriminant)) / (2 * a)
	return t1, t2
end

function ClosestIntersection(origin, direction, t_min, t_max)
	local closest_t = 999999
	local closest_sphere = nil
	for _, sphere in ipairs(Scene.spheres) do
		local t1, t2 = IntersectRaySphere(origin, direction, sphere)

		if t_min < t1 and t_max > t1 and t1 < closest_t then
			closest_t = t1
			closest_sphere = sphere
		end

		if t_min < t2 and t_max > t2 and t2 < closest_t then
			closest_t = t2
			closest_sphere = sphere
		end
	end
	return closest_sphere, closest_t
end

function TraceRay(origin, direction, t_min, t_max, recursion_depth)
	local closest_sphere, closest_t = ClosestIntersection(origin, direction, t_min, t_max)

	if closest_sphere == nil then
		return BACKGROUND_COLOR
	end

	local position = {
		x = closest_t * direction.x,
		y = closest_t * direction.y,
		z = closest_t * direction.z,
	}
	position = { x = position.x + origin.x, y = position.y + origin.y, z = position.z + origin.z }
	local normal = {
		x = position.x - closest_sphere.center.x,
		y = position.y - closest_sphere.center.y,
		z = position.z - closest_sphere.center.z,
	}
	local intensity = ComputeLighting(
		position,
		normal,
		{ x = -direction.x, y = -direction.y, z = -direction.z },
		closest_sphere.specular
	)

	local local_color = {
		x = closest_sphere.color[1] * intensity,
		y = closest_sphere.color[2] * intensity,
		z = closest_sphere.color[3] * intensity,
	}

	local r = closest_sphere.reflective
	if recursion_depth <= 0 or r <= 0 then
		return local_color
	end
	normal = { x = normal.x / VLength(normal), y = normal.y / VLength(normal), z = normal.z / VLength(normal) }
	local ray = ReflectRay(Negative(direction), normal)
	local reflected_color = TraceRay(position, ray, 0.001, math.huge, recursion_depth - 1)

	local trm_1 = Mult(local_color, { x = (1 - r), y = (1 - r), z = (1 - r) })
	return Add(trm_1, { x = reflected_color.x * r, y = reflected_color.y * r, z = reflected_color.z * r })
end

function ReflectRay(ray, normal)
	return Sub(
		Mult(
			Mult({ x = 2, y = 2, z = 2 }, normal),
			{ x = Dot(normal, ray), y = Dot(normal, ray), z = Dot(normal, ray) }
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
				light_position = Sub(light.position, position)
				t_max = 1
			else
				light_position = light.direction
				t_max = math.huge
			end

			shadow_sphere, shadow_t = ClosestIntersection(position, light_position, 0.001, t_max)
			if shadow_sphere ~= nil then
				goto continue
			end
			local n_dot_1 = Dot(normal, light_position)
			if n_dot_1 > 0 then
				intensity = intensity + light.intensity * n_dot_1 / (VLength(normal) * VLength(light_position))
			end

			if s ~= -1 then
				local ray = ReflectRay(light_position, normal)
				local r_dot_v = Dot(ray, direction)
				if r_dot_v > 0 then
					intensity = intensity
						+ light.intensity * math.pow((r_dot_v / (VLength(ray) * VLength(direction))), s)
				end
			end
		end
		::continue::
	end
	return intensity
end

function love.draw()
	for x = -Canvas.width / 2, Canvas.width / 2 do
		for y = -Canvas.height / 2, Canvas.height / 2 do
			local direction = GetViewportPx(x, y)
			local recursion_depth = 3
			local color = TraceRay(Camera.position, direction, 1, 999999, recursion_depth)
			love.graphics.setColor({ color.x, color.y, color.z, 1 })
			love.graphics.rectangle("fill", x + Canvas.width / 2, y + Canvas.height / 2, 1, 1)
		end
	end
end
