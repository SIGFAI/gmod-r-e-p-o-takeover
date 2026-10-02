-- R.E.P.O. Takeover: yellow robot employees haul pricey loot to a green extraction point
-- while Huntsmen and tiny Gnomes try to stop them.
util.AddNetworkString("repo_pop")

local ZONE_R = 150
local zone, haul, quota, level = nil, 0, 16000, 1
local valuables = {}

local LOOT = {
	{ "models/props_c17/frame002a.mdl", "Oil Painting", 1800 },
	{ "models/props_combine/breenbust.mdl", "Golden Bust", 5200, true },
	{ "models/props_lab/monitor01a.mdl", "Retro Monitor", 900 },
	{ "models/props_c17/pottery02a.mdl", "Ming Vase", 3400 },
	{ "models/props_combine/breenglobe.mdl", "Fancy Globe", 2600 },
	{ "models/props_lab/huladoll.mdl", "Hula Doll", 700 },
	{ "models/props_junk/watermelon01.mdl", "Golden Melon", 2000, true },
	{ "models/props_c17/chair_kleiner03a.mdl", "Posh Chair", 1200 },
}

local function pop(pos, text, color)
	net.Start("repo_pop")
	net.WriteVector(pos)
	net.WriteString(text)
	net.WriteColor(color or Color(120, 255, 140))
	net.Broadcast()
end

local function fitTo(ent, size, byHeight)
	local mn, mx = ent:GetModelBounds()
	local d = byHeight and (mx.z - mn.z) or math.max(mx.x - mn.x, mx.y - mn.y)
	if d > 0 then ent:SetModelScale(size / d, 0) end
end

---------------------------------------------------------------- loot
local function spawnLoot(pos)
	local pick = LOOT[math.random(#LOOT)]
	if not util.IsValidModel(pick[1]) then return end
	local e = Sigf.Prop(pick[1], pos, 1, 0)
	if not IsValid(e) then return end
	local value = pick[3] + math.random(0, 4) * 100
	e.SigfValue, e.SigfMax = value, value
	e:SetNWInt("repo_val", value)
	e:SetNWInt("repo_max", value)
	e:SetNWString("repo_name", pick[2])
	if pick[4] then e:SetMaterial("sigf/gold") end
	valuables[#valuables + 1] = e
	return e
end

local function breakLoot(e, attacker)
	local p = e:WorldSpaceCenter()
	Sigf.Effect("ManhackSparks", p)
	Sigf.Effect("GlassImpact", p)
	Sigf.Sound("sigf/shatter.wav", p, 85, math.random(95, 110))
	pop(p + Vector(0, 0, 20), "BROKEN!", Color(255, 80, 70))
	e.SigfDead = true
	e:Remove()
end

hook.Add("EntityTakeDamage", "sigf_repo_loot", function(t, dmg)
	if t.SigfValue and not t.SigfDead then
		local loss = math.floor(t.SigfMax * math.Clamp(dmg:GetDamage() / 60, 0.04, 0.5))
		t.SigfValue = math.max(0, t.SigfValue - loss)
		t:SetNWInt("repo_val", t.SigfValue)
		pop(t:WorldSpaceCenter() + Vector(0, 0, 14), "-$" .. loss, Color(255, 90, 80))
		Sigf.Effect("Sparks", t:WorldSpaceCenter(), { magnitude = 1 })
		if t.SigfValue <= 0 then
			local a = dmg:GetAttacker()
			timer.Simple(0, function() if IsValid(t) then breakLoot(t, a) end end)
		end
	end
end)

local function collect(e)
	local v = e.SigfValue or 0
	e.SigfDead = true
	local p = e:WorldSpaceCenter()
	haul = haul + v
	SetGlobalInt("repo_haul", haul)
	Sigf.Sound("sigf/cha_ching.wav", p, 90, 100)
	Sigf.Effect("balloon_pop", p, { color = 2 })
	pop(p + Vector(0, 0, 30), "+$" .. v, Color(255, 225, 60))
	for i = 1, 4 do
		Sigf.Sprite("sigf/coin", p + VectorRand() * 40 + Vector(0, 0, 40 + i * 14), 22, 1.4)
	end
	e:Remove()
	if haul >= quota then
		level = level + 1
		haul = haul - quota
		quota = math.floor(quota * 1.5 / 100) * 100
		SetGlobalInt("repo_haul", haul)
		SetGlobalInt("repo_quota", quota)
		SetGlobalInt("repo_level", level)
		Sigf.Sound2D("sigf/quota.wav")
		Sigf.Text("QUOTA REACHED! EXTRACTION COMPLETE", 4, { color = Color(120, 255, 140), y = 0.32, size = 56 })
		for i = 1, 14 do
			Sigf.After(i * 0.08, function()
				Sigf.Sprite("sigf/coin", zone + Vector(math.random(-120, 120), math.random(-120, 120), 60 + math.random(0, 120)), 18, 2)
			end)
		end
		Sigf.Effect("HelicopterMegaBomb", zone + Vector(0, 0, 60))
	end
end

---------------------------------------------------------------- characters
local function head(ent, size, mat, offset)
	local h = ents.Create("prop_dynamic")
	h:SetModel("models/hunter/misc/sphere025x025.mdl")
	h:SetPos(ent:GetPos())
	h:Spawn()
	local att = ent:LookupAttachment("eyes")
	h:SetParent(ent, att > 0 and att or -1)
	h:SetLocalPos(offset or Vector(-1, 0, 0))
	h:SetLocalAngles(Angle(0, 0, 0))
	fitTo(h, size)
	h:SetMaterial(mat)
	h:SetNotSolid(true)
	return h
end

local function dress(ent, kind)
	ent.SigfRepoKind = kind
	local parts = {}
	if kind == "robot" then
		ent:SetMaterial("sigf/robot_body")
		parts[1] = head(ent, 22, "sigf/robot_head", Vector(0, 0, 0))
		ent:SetNWString("repo_name", "")
	elseif kind == "gnome" then
		ent:SetMaterial("sigf/gnome_hat")
		local hat = ents.Create("prop_dynamic")
		hat:SetModel("models/props_junk/TrafficCone001a.mdl")
		hat:SetPos(ent:GetPos())
		hat:Spawn()
		local att = ent:LookupAttachment("eyes")
		hat:SetParent(ent, att > 0 and att or -1)
		hat:SetLocalPos(Vector(-1, 0, 3.5))
		hat:SetLocalAngles(Angle(0, 0, 0))
		fitTo(hat, 14 * 1, true)
		hat:SetMaterial("sigf/gnome_hat")
		hat:SetNotSolid(true)
		parts[1] = hat
		local beard = head(ent, 7, "sigf/beard", Vector(3, 0, -4))
		parts[2] = beard
		ent:SetNWString("repo_name", "GNOME")
	elseif kind == "huntsman" then
		ent:SetColor(Color(95, 95, 110))
		ent:SetNWString("repo_name", "HUNTSMAN")
	end
	for _, p in ipairs(parts) do ent:DeleteOnRemove(p) end
	ent.SigfParts = parts
end

hook.Add("SigfBattleSpawn", "sigf_repo_spawn", function(npc, side)
	if side == "combine" then
		if math.random() < 0.5 then
			npc:SetModelScale(0.55, 0)
			npc:SetMaxHealth(35) npc:SetHealth(35)
			dress(npc, "gnome")
		else
			npc:SetModelScale(1.35, 0)
			npc:SetMaxHealth(140) npc:SetHealth(140)
			dress(npc, "huntsman")
		end
	else
		dress(npc, "robot")
	end
end)

-- Bots are players: give them the robot look too, and re-apply after a respawn.
local function dressPlayers()
	for _, p in ipairs(Sigf.Players()) do
		if not IsValid(p.SigfHead) then
			p:SetMaterial("sigf/robot_body")
			p.SigfHead = head(p, 22, "sigf/robot_head", Vector(0, 0, 0))
			p:DeleteOnRemove(p.SigfHead)
		end
	end
end
hook.Add("PlayerDeath", "sigf_repo_pdeath", function(p)
	if IsValid(p.SigfHead) then p.SigfHead:Remove() end
	p.SigfHead = nil
end)

-- Hits show: sparks on robots, squeaks on gnomes, growls on huntsmen.
hook.Add("EntityTakeDamage", "sigf_repo_hit", function(t, dmg)
	local k = t.SigfRepoKind
	if not k or (t.SigfNextFx or 0) > CurTime() then return end
	t.SigfNextFx = CurTime() + 0.25
	local p = t:WorldSpaceCenter()
	if k == "robot" then Sigf.Effect("Sparks", p) Sigf.Effect("ManhackSparks", p)
	elseif k == "gnome" then Sigf.Sound("sigf/squeak.wav", p, 80, math.random(90, 130))
	else Sigf.Effect("StunstickImpact", p) end
end)

-- Corpses keep the monster's size and skin, and vanish after a while.
hook.Add("CreateEntityRagdoll", "sigf_repo_rag", function(owner, rag)
	if not owner.SigfRepoKind then return end
	rag:SetModelScale(owner:GetModelScale(), 0)
	SafeRemoveEntityDelayed(rag, 10)
end)

hook.Add("OnNPCKilled", "sigf_repo_kill", function(npc, attacker)
	local k = npc.SigfRepoKind
	if not k then return end
	local p = npc:WorldSpaceCenter()
	if k == "gnome" then
		Sigf.Effect("balloon_pop", p, { color = 1 })
		Sigf.Sound("sigf/squeak.wav", p, 85, 150)
		pop(p, "GNOMED!", Color(255, 120, 120))
	elseif k == "huntsman" then
		Sigf.Sound("sigf/huntsman.wav", p, 85, 100)
		pop(p, "HUNTSMAN DOWN", Color(255, 120, 120))
	else
		Sigf.Effect("Explosion", p)
		pop(p, "ROBOT DOWN", Color(255, 220, 80))
	end
end)

---------------------------------------------------------------- couriers: robots carry loot to the zone
local function courierTick()
	if not zone then return end
	for _, n in ipairs(Sigf.NPCs()) do
		if n.SigfRepoKind == "robot" and n:Health() > 0 then
			local c = n.SigfCarry
			if IsValid(c) and not c.SigfDead then
				local fwd = n:GetForward()
				local target = n:GetPos() + fwd * 34 + Vector(0, 0, 62)
				local phys = c:GetPhysicsObject()
				if IsValid(phys) then
					phys:Wake()
					phys:SetVelocity((target - c:GetPos()) * 12)
					phys:AddAngleVelocity(-phys:GetAngleVelocity())
				end
				if n:GetPos():Distance(zone) < ZONE_R * 0.7 then
					c.SigfCarrier = nil
					c:SetCollisionGroup(COLLISION_GROUP_NONE)
					n.SigfCarry = nil
				elseif (n.SigfNextGo or 0) < CurTime() then
					n.SigfNextGo = CurTime() + 1
					n:SetLastPosition(zone)
					n:SetSchedule(SCHED_FORCED_GO_RUN)
				end
			else
				n.SigfCarry = nil
				if (n.SigfNextGo or 0) < CurTime() then
					n.SigfNextGo = CurTime() + 1
					local best, bd = nil, 2500
					for _, v in ipairs(valuables) do
						if IsValid(v) and not v.SigfDead and not v.SigfCarrier and v:GetPos():Distance(zone) > ZONE_R then
							local d = v:GetPos():Distance(n:GetPos())
							if d < bd then best, bd = v, d end
						end
					end
					if best then
						if bd < 90 then
							best.SigfCarrier = n
							n.SigfCarry = best
							best:SetCollisionGroup(COLLISION_GROUP_DEBRIS_TRIGGER)
							Sigf.Sound("sigf/grab.wav", best:GetPos(), 75, 100)
							pop(best:WorldSpaceCenter() + Vector(0, 0, 30), "GRAB!", Color(255, 255, 255))
						else
							n:SetLastPosition(best:GetPos())
							n:SetSchedule(SCHED_FORCED_GO_RUN)
						end
					end
				end
			end
		end
	end
end

local function zoneTick()
	if not zone then return end
	for i = #valuables, 1, -1 do
		local v = valuables[i]
		if not IsValid(v) then
			table.remove(valuables, i)
		elseif not v.SigfDead and not v.SigfCarrier and v:GetPos():Distance(zone) < ZONE_R then
			table.remove(valuables, i)
			collect(v)
		end
	end
end

---------------------------------------------------------------- boot
-- Ground point with no wall within 320 units (so the extraction ring never hides in a corner).
function Sigf.RepoOpenGround(center, radius)
	local best, bestFree = nil, -1
	for _ = 1, 25 do
		local p = Sigf.Ground(center, radius)
		local free = 320
		for a = 0, 315, 45 do
			local d = Angle(0, a, 0):Forward()
			local tr = util.TraceLine({ start = p + Vector(0, 0, 40), endpos = p + Vector(0, 0, 40) + d * 320, mask = MASK_SOLID_BRUSHONLY })
			free = math.min(free, tr.Hit and tr.Fraction * 320 or 320)
		end
		if free > bestFree then best, bestFree = p, free end
		if free >= 320 then break end
	end
	return best
end
function Sigf.RepoZone() return zone end
function Sigf.RepoNearQuota(gap) haul = quota - gap SetGlobalInt("repo_haul", haul) end
function Sigf.RepoSpawnLoot(pos) return spawnLoot(pos) end
function Sigf.RepoMoveZone(pos)
	zone = pos
	SetGlobalVector("repo_zone", zone)
end
function Sigf.RepoRobot(pos)
	local e = Sigf.NPC("npc_citizen", pos, { weapon = "weapon_smg1", keys = { citizentype = 3 }, life = 90 })
	if IsValid(e) then e.SigfSide = "rebel" hook.Run("SigfBattleSpawn", e, "rebel") end
	return e
end
function Sigf.RepoMonster(kind, pos)
	local e = Sigf.NPC("npc_combine_s", pos, { weapon = "weapon_smg1", life = 90 })
	if not IsValid(e) then return end
	e.SigfSide = "combine"
	if kind == "gnome" then
		e:SetModelScale(0.55, 0) e:SetMaxHealth(35) e:SetHealth(35) dress(e, "gnome")
	else
		e:SetModelScale(1.35, 0) e:SetMaxHealth(140) e:SetHealth(140) dress(e, "huntsman")
	end
	return e
end

Sigf.Battle.rebels = 4
Sigf.Battle.combine = 5

hook.Add("SigfReady", "sigf_repo_ready", function()
	zone = Sigf.RepoOpenGround(Sigf.Arena(), 450)
	SetGlobalVector("repo_zone", zone)
	SetGlobalInt("repo_haul", 0)
	SetGlobalInt("repo_quota", quota)
	SetGlobalInt("repo_level", level)
	for i = 1, 5 do
		Sigf.After(0.3 * i, function() spawnLoot(Sigf.Ground(zone, 900) + Vector(0, 0, 30)) end)
	end
	Sigf.After(1, function() Sigf.Text("R.E.P.O. TAKEOVER", 4, { color = Color(255, 215, 40), y = 0.12, size = 60 }) end)
	Sigf.Every(5, function()
		local n = 0
		for _, v in ipairs(valuables) do if IsValid(v) then n = n + 1 end end
		if n < 7 then spawnLoot(Sigf.Ground(zone, 1000) + Vector(0, 0, 30)) end
	end)
	-- The stream camera follows the loot runs: a carrying robot, otherwise the extraction point.
	if Sigf.Stage() ~= "demo" then
		Sigf.Every(14, function()
			for _, n in ipairs(Sigf.NPCs()) do
				if n.SigfCarry and IsValid(n.SigfCarry) then Sigf.Focus(n, 9) return end
			end
			Sigf.Focus(zone, 7)
		end)
	end
	Sigf.Every(0.1, courierTick)
	Sigf.Every(0.2, zoneTick)
	Sigf.Every(2, dressPlayers)
end)
