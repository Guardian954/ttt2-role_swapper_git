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
		desc = "Health swapper returns resurrects with (Def. 100)"
	})

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
end)

if SERVER then
	CreateConVar("ttt2_swapper_killer_health", "1", {FCVAR_NOTIFY, FCVAR_ARCHIVE})
	CreateConVar("ttt2_swapper_respawn_health", "100", {FCVAR_NOTIFY, FCVAR_ARCHIVE})
	CreateConVar("ttt2_swapper_entity_damage", "1", {FCVAR_NOTIFY, FCVAR_ARCHIVE})
	CreateConVar("ttt2_swapper_environmental_damage", "1", {FCVAR_NOTIFY, FCVAR_ARCHIVE})
	CreateConVar("ttt2_swapper_respawn_delay", "0", {FCVAR_NOTIFY, FCVAR_ARCHIVE})
	CreateConVar("ttt2_swapper_respawn_opposite_team", "0", {FCVAR_NOTIFY, FCVAR_ARCHIVE})
	CreateConVar("ttt2_swapper_respawn_delay_post_death", "0", {FCVAR_NOTIFY, FCVAR_ARCHIVE})

	local function SwapperRevive(ply, role)
		ply:Revive(GetConVar("ttt2_swapper_respawn_delay"):GetInt(), function()
			ply:SetHealth(GetConVar("ttt2_swapper_respawn_health"):GetInt())
			ply:SetRole(ply.newrole, ply.newteam)
			ply:ResetConfirmPlayer()

			SendFullStateUpdate()
		end)
	end

		-- Function to hand everyone their new weapons
	local function SwapWeapons(victim, attacker)
		-- Sort out the attacker first
		-- Strip all the attackers weapons
		for i = 1, #attacker.weapons do
			swapperRole.StripPlayerWeaponAndAmmo(attacker, attacker.weapons[i])
		end

		-- Give the attacker all their victims gear
		for i = 1, #victim.weapons do
			swapperRole.GivePlayerWeaponAndAmmo(attacker, victim.weapons[i])
		end
		attacker:SelectWeapon("weapon_zm_improvised")

		-- Next is the victim
		-- Strip all equipment from the victim
		for i = 1, #victim.weapons do
			local weapon = victim.weapons[i]
			swapperRole.StripPlayerWeaponAndAmmo(victim, weapon)
		end

		-- Give the victim all their attackers gear
		for i = 1, #attacker.weapons do
			local weapon = attacker.weapons[i]
			swapperRole.GivePlayerWeaponAndAmmo(victim, weapon)
		end
		victim:SelectWeapon("weapon_zm_improvised")

		timer.Simple(0.1, function()
			attacker.weapons = {}
			victim.weapons = {}
		end)
	end

	-- Swapper doesnt deal or take any damage in relation to players
	hook.Add("PlayerTakeDamage", "SwapperNoDamage", function(ply, inflictor, killer, amount, dmginfo)
		if swapperRole.ShouldTakeNoDamage(ply, killer, ROLE_SWAPPER) or swapperRole.ShouldDealNoDamage(ply, killer, ROLE_SWAPPER) then
			dmginfo:ScaleDamage(0)
			dmginfo:SetDamage(0)

			return
		end
	end)

	-- Check if the swapper can damage entities or be damaged by environmental effects
	hook.Add("EntityTakeDamage", "SwapperEntityNoDamage", function(ply, dmginfo)
		if swapperRole.ShouldDealNoEntityDamage(ply, dmginfo, ROLE_SWAPPER) or swapperRole.ShouldTakeEnvironmentalDamage(ply, dmginfo, ROLE_SWAPPER) then
			dmginfo:ScaleDamage(0)
			dmginfo:SetDamage(0)

			return
		end
	end)

	-- Grab the weapons tables before the player loses them
	hook.Add("DoPlayerDeath", "SwapperItemGrab", function(victim, attacker, dmginfo)
		if victim:GetSubRole() == ROLE_SWAPPER and IsValid(attacker) and attacker:IsPlayer() then
			victim.weapons = swapperRole.GetPlayerWeapons(victim)
			attacker.weapons = swapperRole.GetPlayerWeapons(attacker)
		end
	end)

	hook.Add("PlayerDeath", "SwapperDeath", function(victim, infl, attacker)
		if victim:GetSubRole() == ROLE_SWAPPER and IsValid(attacker) and attacker:IsPlayer() then
			if victim == attacker then return end -- Suicide so do nothing

			victim.newrole, victim.newteam = swapperRole.GetRespawnRole(attacker)

			-- Handle the killers swap to his new life of swapper
			attacker:SetRole(ROLE_SWAPPER)

			local health = GetConVar("ttt2_swapper_killer_health"):GetInt()

			if health <= 0 then
				attacker:Kill()
			else
				attacker:SetHealth(health)
			end

			attacker:PrintMessage(HUD_PRINTCENTER, "You killed the Swapper!")

			-- Handle the swappers new life as a new role
			if GetConVar("ttt2_swapper_respawn_delay_post_death"):GetBool() and health > 0 then
				hook.Add("PostPlayerDeath", "SwapperWaitForKillerDeath_" .. victim:SteamID64(), function(deadply)
					if not IsValid(attacker) or not IsValid(victim) then return end

					if deadply ~= attacker then return end

					SwapperRevive(victim)

					hook.Remove("PostPlayerDeath", "SwapperWaitForKillerDeath_" .. victim:SteamID64())
				end)
			else
				SwapperRevive(victim)
			end

			-- start the jester confetti
			net.Start("NewConfetti")
			net.WriteEntity(ply)
			net.Broadcast()

			timer.Simple(0, function()
				SwapWeapons(victim, attacker)
			end)
		end
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
end
