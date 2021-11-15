if SERVER then
	AddCSLuaFile()

	resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_swa.vmt")
end

function ROLE:PreInitialize()
	self.color = Color(214, 47, 125, 255)

	self.abbr = "swa"
	self.score.surviveBonusMultiplier = 0
	self.score.aliveTeammatesBonusMultiplier = 0
	self.score.survivePenaltyMultiplier = -4
	self.score.timelimitMultiplier = -4
	self.score.killsMultiplier = 0
	self.score.teamKillsMultiplier = -16
	self.score.bodyFoundMuliplier = 0
	self.preventWin = true

	self.defaultTeam = TEAM_JESTER
	self.defaultEquipment = SPECIAL_EQUIPMENT

	self.conVarData = {
		pct = 0.2,
		maximum = 1,
		minPlayers = 5,
		togglable = true
	}
end

hook.Add("TTTUlxDynamicRCVars", "TTTUlxDynamicSwaCVars", function(tbl)
	tbl[ROLE_SWAPPER] = tbl[ROLE_SWAPPER] or {}


	table.insert(tbl[ROLE_SWAPPER], {
		cvar = "ttt2_swapper_entity_damage",
		checkbox = true,
		desc = "Can the swapper damage entities? (Def. 1)"
	})

	table.insert(tbl[ROLE_SWAPPER], {
		cvar = "ttt2_swapper_environmental_damage",
		checkbox = true,
		desc = "Can explode, burn, crush, fall, drown? (Def. 1)"
	})

	table.insert(tbl[ROLE_SWAPPER], {
		cvar = "ttt2_swapper_killer_health",
		slider = true,
		min = 0,
		max = 100,
		decimal = 0,
		desc = "Health of swappers killer on resurrection (Def. 1)"
	})

	table.insert(tbl[ROLE_SWAPPER], {
		cvar = "ttt2_swapper_respawn_health",
		slider = true,
		min = 0,
		max = 100,
		decimal = 0,
		desc = "Health swapper resurrects into role with (Def. 100)"
	})

	table.insert(tbl[ROLE_SWAPPER], {
		cvar = "ttt2_swapper_respawn_delay",
		slider = true,
		min = 0,
		max = 60,
		decimal = 0,
		desc = "The respawn delay in seconds (Def. 0)"
	})

	table.insert(tbl[ROLE_SWAPPER], {
		cvar = "ttt2_swapper_respawn_opposite_team",
		checkbox = true,
		desc = "Should the swapper respawn in the opposite team? (Def. 0)"
	})

	table.insert(tbl[ROLE_SWAPPER], {
		cvar = "ttt2_swapper_respawn_delay_post_death",
		checkbox = true,
		desc = "Should the respawn be delayed until the killer's death? (Def. 0)"
	})

	table.insert(tbl[ROLE_SWAPPER], {
		cvar = "ttt2_swapper_randomise_rounds",
		checkbox = true,
		desc = "Should the above 2 cvars be randomised every round? (Def. 0)"
	})
end)

if SERVER then
	CreateConVar("ttt2_swapper_entity_damage", "1", {FCVAR_NOTIFY, FCVAR_ARCHIVE})
	CreateConVar("ttt2_swapper_environmental_damage", "1", {FCVAR_NOTIFY, FCVAR_ARCHIVE})
	CreateConVar("ttt2_swapper_respawn_health", "100", {FCVAR_NOTIFY, FCVAR_ARCHIVE})
	CreateConVar("ttt2_swapper_respawn_delay", "0", {FCVAR_NOTIFY, FCVAR_ARCHIVE})
	CreateConVar("ttt2_swapper_respawn_opposite_team", "0", {FCVAR_NOTIFY, FCVAR_ARCHIVE})
	CreateConVar("ttt2_swapper_respawn_delay_post_death", "0", {FCVAR_NOTIFY, FCVAR_ARCHIVE})
	CreateConVar("ttt2_swapper_randomise_rounds", "0", {FCVAR_NOTIFY, FCVAR_ARCHIVE})

	local cvKillerHealth = CreateConVar("ttt2_swapper_killer_health", "1", {FCVAR_NOTIFY, FCVAR_ARCHIVE})

	cvars.AddChangeCallback("ttt2_swapper_respawn_opposite_team", function(_, old, new)
		roles.SWAPPER.HandleReviveConvars()
	end)

	cvars.AddChangeCallback("ttt2_swapper_respawn_delay_post_death", function(_, old, new)
		roles.SWAPPER.HandleReviveConvars()
	end)

	cvars.AddChangeCallback("ttt2_swapper_randomise_rounds", function(_, old, new)
		roles.SWAPPER.HandleReviveConvars()
	end)

	hook.Add("TTTBeginRound", "SwapperRandomCvarCheck", function()
		roles.SWAPPER.HandleReviveConvars()
	end)

	-- Swapper doesnt deal or take any damage in relation to players
	hook.Add("PlayerTakeDamage", "SwapperNoDamage", function(ply, inflictor, killer, amount, dmginfo)
		if roles.SWAPPER.ShouldTakeNoDamage(ply, killer, ROLE_SWAPPER)
			or roles.SWAPPER.ShouldDealNoDamage(ply, killer, ROLE_SWAPPER)
		then
			dmginfo:ScaleDamage(0)
			dmginfo:SetDamage(0)
		end
	end)

	-- Check if the swapper can damage entities or be damaged by environmental effects
	hook.Add("EntityTakeDamage", "SwapperEntityNoDamage", function(ply, dmginfo)
		if roles.SWAPPER.ShouldDealNoEntityDamage(ply, dmginfo, ROLE_SWAPPER)
			or roles.SWAPPER.ShouldTakeEnvironmentalDamage(ply, dmginfo, ROLE_SWAPPER)
		then
			dmginfo:ScaleDamage(0)
			dmginfo:SetDamage(0)
		end
	end)

	-- Grab the weapons tables before the player loses them
	hook.Add("DoPlayerDeath", "SwapperItemGrab", function(victim, attacker, dmginfo)
		if victim:GetSubRole() == ROLE_SWAPPER and IsValid(attacker) and attacker:IsPlayer() then
			victim.weapons = roles.SWAPPER.GetPlayerWeapons(victim)
			attacker.weapons = roles.SWAPPER.GetPlayerWeapons(attacker)
		end
	end)

	hook.Add("PlayerDeath", "SwapperDeath", function(victim, infl, attacker)
		if victim:GetSubRole() ~= ROLE_SWAPPER or not IsValid(attacker)
			or not attacker:IsPlayer() or victim == attacker
		then return end

		local role, team = roles.SWAPPER.GetRespawnRole(victim, attacker)

		-- Handle the killers swap to his new life of swapper
		attacker:SetRole(ROLE_SWAPPER)
		SendFullStateUpdate()

		local health = cvKillerHealth:GetInt()

		if health <= 0 then
			attacker:Kill()
		else
			attacker:SetHealth(health)
		end

		attacker:PrintMessage(HUD_PRINTCENTER, "You killed the Swapper!")

		-- Handle the swappers new life as a new role
		if roles.SWAPPER.waitForDeath and health > 0 then
			hook.Add("PostPlayerDeath", "SwapperWaitForKillerDeath_" .. victim:SteamID64(), function(deadply)
				if not IsValid(attacker) or not IsValid(victim) then return end

				if deadply ~= attacker then return end

				roles.SWAPPER.Revive(victim, role, team)

				hook.Remove("PostPlayerDeath", "SwapperWaitForKillerDeath_" .. victim:SteamID64())
			end)
		else
			roles.SWAPPER.Revive(victim, role, team)
		end

		roles.JESTER.SpawnJesterConfetti(victim)

		timer.Simple(0, function()
			if not IsValid(victim) or not IsValid(attacker) then return end

			roles.SWAPPER.SwapWeapons(victim, attacker)
		end)
	end)

	-- hide the swapper as a normal jester
	hook.Add("TTT2JesterModifySyncedRole", "SwapperHideAsJester", function(_, syncPly)
		if syncPly:GetSubRole() ~= ROLE_SWAPPER then return end

		return {ROLE_JESTER, TEAM_JESTER}
	end)

	-- reset hooks at round end
	hook.Add("TTTEndRound", "SwapperEndRoundReset", function()
		local plys = player.GetAll()

		for i = 1, #plys do
			hook.Remove("PostPlayerDeath", "SwapperWaitForKillerDeath_" .. plys[i]:SteamID64())
		end
	end)
	
	hook.Add("TTT2CanBeHitmanTarget", "TTT2SwapperNoHitmanTarget", function(hitman, ply)
		if ply:GetSubRole() == ROLE_SWAPPER then
			return false
		end
	end)
end
