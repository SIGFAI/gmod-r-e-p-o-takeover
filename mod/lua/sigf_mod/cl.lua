-- R.E.P.O. Takeover: client side. Loot price tags, extraction zone, haul HUD, floating money pops.
local pops = {}
local glowMat = Material("sigf/glow_gold")
local ringMat = Material("sprites/light_glow02_add")

net.Receive("repo_pop", function()
	pops[#pops + 1] = { pos = net.ReadVector(), text = net.ReadString(), col = net.ReadColor(), t = RealTime() }
end)

local fonts = {}
local function F(size, weight)
	local k = size .. "_" .. (weight or 800)
	if not fonts[k] then
		fonts[k] = "Repo" .. k
		surface.CreateFont(fonts[k], { font = "Roboto", size = math.floor(size * ScrH() / 1080), weight = weight or 800, antialias = true })
	end
	return fonts[k]
end

local loot, actors = {}, {}
timer.Create("repo_scan", 0.4, 0, function()
	loot, actors = {}, {}
	for _, e in ipairs(ents.GetAll()) do
		if e:GetNWInt("repo_val", 0) > 0 then loot[#loot + 1] = e
		elseif e:GetNWString("repo_name", "") ~= "" then actors[#actors + 1] = e end
	end
end)

local function money(n) return "$" .. string.Comma(n) end

hook.Add("PostDrawTranslucentRenderables", "repo_world", function(depth, sky)
	if depth or sky then return end
	local now = CurTime()
	for _, e in ipairs(loot) do
		if IsValid(e) then
			render.SetMaterial(glowMat)
			local s = 70 + 12 * math.sin(now * 4 + e:EntIndex())
			render.DrawSprite(e:WorldSpaceCenter(), s, s, Color(255, 220, 80, 200))
		end
	end
	local z = GetGlobalVector("repo_zone", vector_origin)
	if z ~= vector_origin then
		local pulse = 1 + 0.08 * math.sin(now * 3)
		render.SetColorMaterial()
		local zc = z + Vector(0, 0, 4)
		mesh.Begin(MATERIAL_TRIANGLES, 32)
		for i = 0, 31 do
			local a1, a2 = i / 32 * math.pi * 2, (i + 1) / 32 * math.pi * 2
			local c = Color(70, 255, 130, 120)
			for _, v in ipairs({ zc, zc + Vector(math.cos(a1), math.sin(a1), 0) * 150 * pulse, zc + Vector(math.cos(a2), math.sin(a2), 0) * 150 * pulse }) do
				mesh.Position(v) mesh.Color(c.r, c.g, c.b, c.a) mesh.AdvanceVertex()
			end
		end
		mesh.End()
		render.SetMaterial(ringMat)
		local eye = EyePos()
		for i = 0, 23 do
			local a = i / 24 * math.pi * 2 + now * 0.8
			local p = z + Vector(math.cos(a) * 150, math.sin(a) * 150, 10)
			local k = math.Clamp((p:Distance(eye) - 80) / 220, 0, 1)
			render.DrawSprite(p, 26 * k, 26 * k, Color(120, 255, 160, 255))
		end
		for h = 0, 220, 22 do
			local p = z + Vector(0, 0, 20 + h)
			local k = math.Clamp((p:Distance(eye) - 120) / 300, 0, 1)
			render.DrawSprite(p, 90 - h * 0.2, 90 - h * 0.2, Color(60, 255, 120, (70 - h * 0.25) * k))
		end
	end
end)

local function drawTag(pos, lines, ent)
	local sp = pos:ToScreen()
	if not sp.visible then return end
	local tr = util.TraceLine({ start = EyePos(), endpos = pos, mask = MASK_SOLID_BRUSHONLY })
	if tr.Hit then return end
	local y = sp.y
	for _, l in ipairs(lines) do
		draw.SimpleTextOutlined(l.text, F(l.size, 900), sp.x, y, l.col, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 255))
		y = y + l.size * ScrH() / 1080 * 1.0
	end
end

hook.Add("HUDPaint", "repo_hud", function()
	local eye = EyePos()
	for _, e in ipairs(loot) do
		if IsValid(e) then
			local d = e:GetPos():Distance(eye)
			if d < 1500 then
				local v, m = e:GetNWInt("repo_val"), e:GetNWInt("repo_max")
				local col = v < m and Color(255, 170, 60) or Color(130, 255, 130)
				drawTag(e:GetPos() + Vector(0, 0, e:OBBMaxs().z + 22), {
					{ text = money(v), size = 34, col = col },
					{ text = e:GetNWString("repo_name"), size = 20, col = Color(255, 255, 255) },
				})
			end
		end
	end
	for _, e in ipairs(actors) do
		if IsValid(e) and e:Health() > 0 then
			local c = e:GetNWString("repo_name") == "HUNTSMAN" and Color(255, 70, 70) or Color(255, 150, 180)
			drawTag(e:GetPos() + Vector(0, 0, e:OBBMaxs().z * e:GetModelScale() + 18), { { text = e:GetNWString("repo_name"), size = 22, col = c } })
		end
	end
	local z = GetGlobalVector("repo_zone", vector_origin)
	if z ~= vector_origin then
		drawTag(z + Vector(0, 0, 150), { { text = "EXTRACTION POINT", size = 30, col = Color(120, 255, 160) } })
	end
	-- Pops
	local now = RealTime()
	for i = #pops, 1, -1 do
		local p = pops[i]
		local age = now - p.t
		if age > 1.6 then table.remove(pops, i) else
			local sp = (p.pos + Vector(0, 0, age * 50)):ToScreen()
			if sp.visible then
				draw.SimpleTextOutlined(p.text, F(40, 900), sp.x, sp.y, Color(p.col.r, p.col.g, p.col.b, 255 * (1 - age / 1.6)), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 2, Color(0, 0, 0, 255 * (1 - age / 1.6)))
			end
		end
	end
	-- Haul panel (bottom center)
	local haul, quota, level = GetGlobalInt("repo_haul", 0), math.max(1, GetGlobalInt("repo_quota", 1)), GetGlobalInt("repo_level", 1)
	local w, h = 560 * ScrH() / 1080, 86 * ScrH() / 1080
	local x, y = ScrW() / 2 - w / 2, ScrH() - h - 40 * ScrH() / 1080
	draw.RoundedBox(10, x, y, w, h, Color(15, 20, 15, 215))
	draw.RoundedBox(10, x, y, w, 6, Color(255, 215, 40, 255))
	draw.SimpleText("HAUL  " .. money(haul) .. " / " .. money(quota), F(34, 900), x + w / 2, y + h * 0.36, Color(255, 225, 70), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	local bw = w - 40
	draw.RoundedBox(6, x + 20, y + h * 0.66, bw, h * 0.2, Color(40, 50, 40, 255))
	draw.RoundedBox(6, x + 20, y + h * 0.66, bw * math.Clamp(haul / quota, 0, 1), h * 0.2, Color(110, 255, 140, 255))
	draw.SimpleText("LEVEL " .. level, F(24, 900), x + 16, y - 20 * ScrH() / 1080, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
end)

RunConsoleCommand("cl_showhints", "0")
