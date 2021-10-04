swapperRole = swapperRole or {}

function swapperRole.GetPlayerWeapons(ply)
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

function swapperRole.StripPlayerWeaponAndAmmo(ply, weapon)
	ply:StripWeapon(weapon.class)

	if weapon.primary_ammo then
		ply:SetAmmo(0, weapon.primary_ammo_type)
	end

	if weapon.secondary_ammo then
		ply:SetAmmo(0, weapon.secondary_ammo_type)
	end
end

function swapperRole.GivePlayerWeaponAndAmmo(ply, weapon)
	ply:Give(weapon.class)

	if weapon.primary_ammo then
		ply:SetAmmo(weapon.primary_ammo, weapon.primary_ammo_type)
	end

	if weapon.secondary_ammo then
		ply:SetAmmo(weapon.secondary_ammo, weapon.secondary_ammo_type)
	end
end

-- Handle the ply only taking damage from other players
function swapperRole.ShouldTakeNoDamage(ply, attacker, role)
	if not IsValid(ply) or ply:GetSubRole() ~= role then return end

	if not IsValid(attacker) or not attacker:IsPlayer() or attacker ~= ply then return end

	print("Blocking " .. role .. " taking damage")

	return true -- true to block damage event
end

-- Handle the attacker only damaging other players
function swapperRole.ShouldDealNoDamage(ply, attacker, role)
	if not IsValid(ply) or not IsValid(attacker) or not attacker:IsPlayer() or attacker:GetSubRole() ~= role then return end
	if SpecDM and (ply.IsGhost and ply:IsGhost() or (attacker.IsGhost and attacker:IsGhost())) then return end

	print("Blocking " .. role .. " damaging others")

	return true -- true to block damage event
end

-- Handle the attacker only damaging entities
function swapperRole.ShouldDealNoEntityDamage(ply, dmginfo, role)
	local attacker = dmginfo:GetAttacker()
	local roleName = roles.GetByIndex(role).name

	if not IsValid(attacker) or not attacker:IsPlayer() or attacker:GetSubRole() ~= role then return end

	-- Allow the player to damage entities unless convar is false
	if GetConVar("ttt2_" .. roleName .. "_entity_damage"):GetBool() then return end

	print("Blocking " .. roleName .. " entity damage")

	return true -- true to block damage event
end

-- Handle the ply only taking environmental damage
function swapperRole.ShouldTakeEnvironmentalDamage(ply, dmginfo, role)
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
