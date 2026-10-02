-- $MOD kit: loader (frozen). Loads the kit's bricks then the agent's mod (lua/sigf_mod/).
-- Order: sh.lua (shared), sv.lua (server), cl.lua (client), demo.lua (server, demo only).
-- Outside the stream (the mod installed by a player), data/sigf/stage.txt does not exist: only the bricks and the mod run.
Sigf = Sigf or {}

if SERVER then
	for _, f in ipairs({ "sh_bricks", "cl_bricks", "sh_stage", "cl_stage" }) do AddCSLuaFile("sigf_kit/" .. f .. ".lua") end
	include("sigf_kit/sh_bricks.lua")
	include("sigf_kit/sv_bricks.lua")
	include("sigf_kit/sh_stage.lua")
	include("sigf_kit/sv_stage.lua")
	Sigf.LoadMod()
else
	include("sigf_kit/sh_bricks.lua")
	include("sigf_kit/cl_bricks.lua")
	include("sigf_kit/sh_stage.lua")
	include("sigf_kit/cl_stage.lua")
	Sigf.LoadModClient()
end
