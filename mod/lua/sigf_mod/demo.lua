-- Demo: the five moments of clip.txt, in order.
local function loot(pos) return Sigf.RepoSpawnLoot(pos + Vector(0, 0, 24)) end

Sigf.Demo(0.5, function()
	Sigf.Pilot(false)
	local h = Sigf.Host()
	local dir = h:GetForward() dir.z = 0 dir:Normalize()
	local side = dir:Cross(Vector(0, 0, 1))
	local zpos = Sigf.RepoOpenGround(Sigf.Front(500), 250)
	Sigf.RepoMoveZone(zpos)
	Sigf.Text("R.E.P.O. TAKEOVER", 4, { color = Color(255, 215, 40), y = 0.1, size = 64 })
	Sigf.Text("Robots grab loot and haul it to extraction", 5, { y = 0.2, size = 40, color = Color(255, 255, 255) })
	for i = -1, 1 do
		local rp = Sigf.Front(230) + side * (i * 110)
		local r = Sigf.RepoRobot(rp)
		if IsValid(r) then r:SetAngles(Angle(0, dir:Angle().y, 0)) end
		loot(Sigf.Front(330) + side * (i * 130))
	end
	Sigf.Focus(zpos, 12)
end)

Sigf.Demo(9, function()
	Sigf.Text("Break loot and the price drops", 4, { y = 0.2, size = 42, color = Color(255, 255, 255) })
	local v = loot(Sigf.Front(300))
	if IsValid(v) then
		Sigf.After(0.6, function()
			Sigf.LookAt(v, 3)
			Sigf.Shoot(1.4)
		end)
	end
end)

Sigf.Demo(19, function()
	Sigf.Pilot(true)
	Sigf.Text("GNOMES: tiny, angry, squeaky", 4, { y = 0.2, size = 42, color = Color(255, 150, 180) })
	for i = 1, 2 do
		local g = Sigf.RepoMonster("gnome", Sigf.Front(190 + i * 50))
		if IsValid(g) then
			Sigf.After(3.5 + i * 0.8, function() Sigf.LookAt(g, 1) Sigf.Shoot(0.8) Sigf.After(0.5, function() Sigf.KillByHost(g) end) end)
		end
	end
end)

Sigf.Demo(31, function()
	Sigf.Text("The HUNTSMAN is hunting you", 4, { y = 0.2, size = 42, color = Color(255, 90, 90) })
	local m = Sigf.RepoMonster("huntsman", Sigf.Front(360))
	if IsValid(m) then
		Sigf.After(1, function() Sigf.LookAt(m, 4) Sigf.Shoot(4) end)
		Sigf.After(5, function() Sigf.KillByHost(m) end)
	end
end)

Sigf.Demo(43, function()
	Sigf.Pilot(false)
	local z = Sigf.RepoZone()
	Sigf.RepoNearQuota(4000)
	local h = Sigf.Host()
	local back = Sigf.RepoOpenGround(z, 420)
	local look = (z - back) look.z = 0
	Sigf.Teleport(h, back + Vector(0, 0, 8), Vector(0, 0, 0))
	h:SetEyeAngles(Angle(0, look:Angle().y, 0))
	Sigf.Text("Drop it in the green zone: cha-ching!", 5, { y = 0.2, size = 42, color = Color(120, 255, 140) })
	for i = 1, 4 do
		Sigf.After(i * 0.9, function()
			local v = loot(z + Vector(math.random(-90, 90), math.random(-90, 90), 160))
			if IsValid(v) then v.SigfValue = 2200 v.SigfMax = 2200 v:SetNWInt("repo_val", 2200) end
		end)
	end
	Sigf.Focus(z, 10)
end)

Sigf.Demo(58, function()
	Sigf.Pilot(true)
	Sigf.Text("Quota hit. Next level: bigger quota!", 4, { y = 0.2, size = 42, color = Color(255, 225, 70) })
end)
