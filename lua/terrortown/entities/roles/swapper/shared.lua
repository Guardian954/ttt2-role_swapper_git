if SERVER then
	AddCSLuaFile()

	resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_swa.vmt")
end

function ROLE:PreInitialize()
	self.color = Color(245, 48, 155, 255)

	self.abbr = "swa" -- abbreviation
	self.radarColor = Color(245, 48, 155) -- color if someone is using the radar
	self.surviveBonus = 0 -- bonus multiplier for every survive while another player was killed
	self.scoreKillsMultiplier = 1 -- multiplier for kill of player of another team
	self.scoreTeamKillsMultiplier = -8 -- multiplier for teamkill
	self.preventWin = true -- set true if role can't win (maybe because of own / special win conditions)
	self.defaultTeam = TEAM_JESTER -- the team name: roles with same team name are working together
	self.defaultEquipment = SPECIAL_EQUIPMENT -- here you can set up your own default equipment

	self.conVarData = {
		pct = 0.15, -- necessary: percentage of getting this role selected (per player)
		maximum = 1, -- maximum amount of roles in a round
		minPlayers = 5, -- minimum amount of players until this role is able to get selected
		credits = 1, -- the starting credits of a specific role
		togglable = true, -- option to toggle a role for a client if possible (F1 menu)
		shopFallback = SHOP_DISABLED,
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
end)

if SERVER then
	CreateConVar("ttt2_swapper_killer_health", "1", {FCVAR_NOTIFY, FCVAR_ARCHIVE})
	CreateConVar("ttt2_swapper_respawn_health", "100", {FCVAR_NOTIFY, FCVAR_ARCHIVE})
	CreateConVar("ttt2_swapper_entity_damage", "1", {FCVAR_NOTIFY, FCVAR_ARCHIVE})
	CreateConVar("ttt2_swapper_environmental_damage", "1", {FCVAR_NOTIFY, FCVAR_ARCHIVE})

	local function SwapperRevive(ply, role)
		ply:Revive(0, function()
			local health = GetConVar("ttt2_swapper_respawn_health"):GetInt()

			ply:SetHealth(health)
			ply:SetRole(ply.newrole, ply.newteam)
			ply:UpdateTeam(ply.newteam)
			ply:SetDefaultCredits()
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

	hook.Add("TTT2JesterModifyList", "AddSwapperToJesterList", function(jesterTable)
		local players = player.GetAll()

		for i = 1, #players do
			local ply = players[i]

			if ply:GetSubRole() ~= ROLE_SWAPPER then continue end

			jesterTable[#jesterTable + 1] = ply
		end
	end)

	-- Hide the swapper as a normal jester to the traitors
	hook.Add("TTT2SpecialRoleSyncing", "TTT2RoleSwapper", function(ply, tbl)
		if ply and not ply:HasTeam(TEAM_TRAITOR) or ply:GetSubRoleData().unknownTeam or GetRoundState() == ROUND_POST then return end

		for swapper in pairs(tbl) do
			if not swapper:IsTerror() or swapper == ply then continue end

			if ply:GetSubRole() ~= ROLE_SWAPPER and swapper:GetSubRole() == ROLE_SWAPPER then
				if not swapper:Alive() then continue end

				if ply:GetTeam() ~= TEAM_JESTER then
					tbl[swapper] = {ROLE_JESTER, TEAM_JESTER}
				else
					tbl[swapper] = {ROLE_SWAPPER, TEAM_JESTER}
				end
			end
		end
	end)

	hook.Add("TTT2ModifyRadarRole", "TTT2ModifyRadarRoleSwapper", function(ply, target)
		if ply:HasTeam(TEAM_TRAITOR) and target:GetSubRole() == ROLE_SWAPPER then
			return ROLE_JESTER, TEAM_JESTER
		end
	end)

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

			victim.newrole = attacker:GetSubRole()
			victim.newteam = attacker:GetTeam()

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
			SwapperRevive(victim)

			-- start the jester confetti
			net.Start("NewConfetti")
			net.WriteEntity(ply)
			net.Broadcast()

			timer.Simple(0, function()
				SwapWeapons(victim, attacker)
			end)
		end
	end)
end
