function roles.SWAPPER.GetRespawnRole(killer, opposite)
	if opposite then
		local rd = killer:GetSubRoleData()
		local selectablePlys = roleselection.GetSelectablePlayers(player.GetAll())
		local reviveRoleCandidates = table.Copy(roleselection.GetAllSelectableRolesList(#selectablePlys))
		local reviveRoles = {}

		-- make sure innocent and traitor are revive candidate roles
		reviveRoleCandidates[ROLE_INNOCENT] = reviveRoleCandidates[ROLE_INNOCENT] or 1
		reviveRoleCandidates[ROLE_TRAITOR] = reviveRoleCandidates[ROLE_TRAITOR] or 1

		--remove jester like roles from the revive candidate roles
		reviveRoleCandidates[ROLE_JESTER] = nil
		reviveRoleCandidates[ROLE_BEGGAR] = nil
		reviveRoleCandidates[ROLE_CLOWN] = nil

		for k in pairs(reviveRoleCandidates) do
			local roleData = roles.GetByIndex(k)
			if roleData.defaultTeam ~= rd.defaultTeam then
				reviveRoles[#reviveRoles + 1] = k
			end
		end

		local selectedRole = reviveRoles[math.random(1, #reviveRoles)]

		return selectedRole, roles.GetByIndex(selectedRole).defaultTeam
	else
		return killer:GetSubRole(), killer:GetTeam()
	end
end

function roles.SWAPPER.GetPlayerWeapons(ply)
	local processedWeapons = {}
	local weapons = ply:GetWeapons()

	for i = 1, #weapons do
		local weapon = weapons[i]
		local primary_ammo = nil
		local primary_ammo_type = nil

		if weapon.Primary and weapon.Primary.Ammo ~= "none" then
			primary_ammo_type = weapon.Primary.Ammo
			primary_ammo = ply:GetAmmoCount(primary_ammo_type)
		end

		local secondary_ammo = nil
		local secondary_ammo_type = nil

		if weapon.Secondary and weapon.Secondary.Ammo ~= "none" and weapon.Secondary.Ammo ~= primary_ammo_type then
			secondary_ammo_type = weapon.Secondary.Ammo
			secondary_ammo = ply:GetAmmoCount(secondary_ammo_type)
		end

		processedWeapons[i] = {
			class = WEPS.GetClass(weapon),
			category = weapon.Category,
			primary_ammo = primary_ammo,
			primary_ammo_type = primary_ammo_type,
			secondary_ammo = secondary_ammo,
			secondary_ammo_type = secondary_ammo_type
		}
	end

	return processedWeapons
end

function roles.SWAPPER.StripPlayerWeaponAndAmmo(ply, weapon)
	ply:StripWeapon(weapon.class)

	if weapon.primary_ammo then
		ply:SetAmmo(0, weapon.primary_ammo_type)
	end

	if weapon.secondary_ammo then
		ply:SetAmmo(0, weapon.secondary_ammo_type)
	end
end

function roles.SWAPPER.GivePlayerWeaponAndAmmo(ply, weapon)
	ply:Give(weapon.class)

	if weapon.primary_ammo then
		ply:SetAmmo(weapon.primary_ammo, weapon.primary_ammo_type)
	end

	if weapon.secondary_ammo then
		ply:SetAmmo(weapon.secondary_ammo, weapon.secondary_ammo_type)
	end
end

-- Handle the ply only taking damage from other players
function roles.SWAPPER.ShouldTakeNoDamage(ply, attacker, role)
	if not IsValid(ply) or ply:GetSubRole() ~= role then return end

	if not IsValid(attacker) or not attacker:IsPlayer() or attacker ~= ply then return end

	print("Blocking " .. role .. " taking damage")

	return true -- true to block damage event
end

-- Handle the attacker only damaging other players
function roles.SWAPPER.ShouldDealNoDamage(ply, attacker, role)
	if not IsValid(ply) or not IsValid(attacker) or not attacker:IsPlayer() or attacker:GetSubRole() ~= role then return end
	if SpecDM and (ply.IsGhost and ply:IsGhost() or (attacker.IsGhost and attacker:IsGhost())) then return end

	print("Blocking " .. role .. " damaging others")

	return true -- true to block damage event
end

-- Handle the attacker only damaging entities
function roles.SWAPPER.ShouldDealNoEntityDamage(ply, dmginfo, role)
	local attacker = dmginfo:GetAttacker()
	local roleName = roles.GetByIndex(role).name

	if not IsValid(attacker) or not attacker:IsPlayer() or attacker:GetSubRole() ~= role then return end

	-- Allow the player to damage entities unless convar is false
	if GetConVar("ttt2_" .. roleName .. "_entity_damage"):GetBool() then return end

	print("Blocking " .. roleName .. " entity damage")

	return true -- true to block damage event
end

-- Handle the ply only taking environmental damage
function roles.SWAPPER.ShouldTakeEnvironmentalDamage(ply, dmginfo, role)
	local attacker = dmginfo:GetAttacker()
	local roleName = roles.GetByIndex(role).name

	if not IsValid(ply) or not ply:IsPlayer() or ply:GetSubRole() ~= role then return end

	-- we dont want to consider player damage at all here
	if IsValid(attacker) and attacker:IsPlayer() then return end

	-- Allow the player to take environmental damage unless convar is false
	if GetConVar("ttt2_" .. roleName .. "_environmental_damage"):GetBool()
		and (dmginfo:IsDamageType(DMG_BLAST + DMG_BURN + DMG_CRUSH + DMG_FALL + DMG_DROWN))
	then return end

	print("Blocking " .. roleName .. " taking environmental damage")

	return true -- true to block damage event
end

-- Function to hand everyone their new weapons
function roles.SWAPPER.SwapWeapons(victim, attacker)
	-- Sort out the attacker first
	-- Strip all the attackers weapons
	for i = 1, #attacker.weapons do
		roles.SWAPPER.StripPlayerWeaponAndAmmo(attacker, attacker.weapons[i])
	end

	-- Give the attacker all their victims gear
	for i = 1, #victim.weapons do
		roles.SWAPPER.GivePlayerWeaponAndAmmo(attacker, victim.weapons[i])
	end
	attacker:SelectWeapon("weapon_zm_improvised")

	-- Next is the victim
	-- Strip all equipment from the victim
	for i = 1, #victim.weapons do
		local weapon = victim.weapons[i]

		roles.SWAPPER.StripPlayerWeaponAndAmmo(victim, weapon)
	end

	-- Give the victim all their attackers gear
	for i = 1, #attacker.weapons do
		local weapon = attacker.weapons[i]

		roles.SWAPPER.GivePlayerWeaponAndAmmo(victim, weapon)
	end
	victim:SelectWeapon("weapon_zm_improvised")

	timer.Simple(0, function()
		attacker.weapons = {}
		victim.weapons = {}
	end)
end

function roles.SWAPPER.Revive(ply, role, team)
	ply:Revive(GetConVar("ttt2_swapper_respawn_delay"):GetInt(), function()
		ply:SetHealth(GetConVar("ttt2_swapper_respawn_health"):GetInt())
		ply:SetRole(role, team)
		ply:ResetConfirmPlayer()

		SendFullStateUpdate()
	end)
end
