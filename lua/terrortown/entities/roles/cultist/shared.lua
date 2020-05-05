-- Icon Materials

if SERVER then
	AddCSLuaFile()
	
	resource.AddFile('materials/vgui/ttt/dynamic/roles/icon_clti.vmt')
end

-- General settings

roles.InitCustomTeam("CULT", { -- this creates the var "TEAM_CULT"
	icon = "vgui/ttt/dynamic/roles/icon_clti",
	color = Color(123, 104, 238, 255)
})
function ROLE:PreInitialize()
	self.color = Color(123, 104, 238, 255) -- rolecolour
	
	self.abbr = 'clti' -- Abbreviation
	self.unknownTeam = true -- No teamchat
	self.defaultTeam = TEAM_CULT -- no team, own team
	self.preventFindCredits = true
	self.preventKillCredits = true
	self.preventTraitorAloneCredits = true
	self.preventWin = false -- cannot win unless he switches roles
	self.scoreKillsMultiplier       = 2
    self.scoreTeamKillsMultiplier   = -6
	
	-- ULX convars

	self.conVarData = {
		pct = 0.17, -- necessary: percentage of getting this role selected (per player)
		maximum = 2, -- maximum amount of roles in a round
		minPlayers = 9, -- minimum amount of players until this role is able to get selected
		credits = 0, -- the starting credits of a specific role
		shopFallback = SHOP_DISABLED,
		togglable = true, -- option to toggle a role for a client if possible (F1 menu)
		random = 50
	}
end

if SERVER then
	AddCSLuaFile()

	util.AddNetworkString("TTT2CltiSyncClasses")

	resource.AddFile("materials/vgui/ttt/dynamic/roles/icon_clti.vmt")

	CreateConVar("ttt2_clti_protection_time", 1, {FCVAR_NOTIFY, FCVAR_ARCHIVE})
	CreateConVar("ttt2_clti_mode", 1, {FCVAR_NOTIFY, FCVAR_ARCHIVE})
end

local plymeta = FindMetaTable("Player")
if not plymeta then return end

hook.Add("TTTUlxDynamicRCVars", "TTTUlxDynamicCltiCVars", function(tbl)
	tbl[ROLE_CULTIST] = tbl[ROLE_CULTIST] or {}

	table.insert(tbl[ROLE_CULTIST], {cvar = "ttt2_clti_protection_time", slider = true, min = 0, max = 60, desc = "Protection Time for new Cultist (Def. 1)"})
	table.insert(tbl[ROLE_CULTIST], {cvar = "ttt2_clti_mode", checkbox = true, desc = "Normal mode for the Cultist (Def. 1). 1 = Cultist -> Cultleader. 2 = Cultist receive targets"})
	table.insert(tbl[ROLE_CULTIST], {cvar = "ttt2_clti_deagle_refill", checkbox = true, desc = "The Cultist Deagle can be refilled when you missed a shot. (Def. 1)"})
	table.insert(tbl[ROLE_CULTIST], {cvar = "ttt2_clti_deagle_refill_cd", slider = true, min = 1, max = 300, desc = "Seconds to Refill (Def. 120)"})
	table.insert(tbl[ROLE_CULTIST], {cvar = "ttt2_clti_deagle_refill_cd_per_kill", slider = true, min = 1, max = 300, desc = "CD Reduction per Kill (Def. 60)"})
end)

function GetDarkenColor(color)
	if not istable(color) then return end
	local col = table.Copy(color)
	-- darken color
	for _, v in ipairs{"r", "g", "b"} do
		col[v] = col[v] - 60
		if col[v] < 0 then
			col[v] = 0
		end
	end

	col.a = 255

	return col
end

local function tmpfnc(ply, mate, colorTable)
	if IsValid(mate) and mate:IsPlayer() then
		if colorTable == "dkcolor" then
			return table.Copy(mate:GetRoleDkColor())
		elseif colorTable == "bgcolor" then
			return table.Copy(mate:GetRoleBgColor())
		elseif colorTable == "color" then
			return table.Copy(mate:GetRoleColor())
		end
	elseif ply.mateSubRole then
		return table.Copy(GetRoleByIndex(ply.mateSubRole)[colorTable])
	end
end

local function GetDarkenMateColor(ply, colorTable)
	ply = ply or LocalPlayer()

	if IsValid(ply) and ply.GetSubRole and ply:GetSubRole() and ply:GetSubRole() == ROLE_CULTIST then
		local col
		local deadSubRole = ply.lastMateSubRole
		local mate = ply:GetCultistMate()

		if not ply:Alive() and deadSubRole then
			if IsValid(mate) and mate:IsPlayer() and mate:IsInTeam(ply) and not mate:GetSubRoleData().unknownTeam then
				col = tmpfnc(ply, mate, colorTable)
			else
				col = table.Copy(GetRoleByIndex(deadSubRole)[colorTable])
			end
		else
			col = tmpfnc(ply, mate, colorTable)
		end

		return GetDarkenColor(col)
	end
end

function plymeta:IsCultist()
	return IsValid(self:GetNWEntity("binded_cultist", nil))
end

function plymeta:GetCultistMate()
	local data = self:GetNWEntity("binded_cultist", nil)

	if IsValid(data) then
		return data
	end
end

function plymeta:GetCultists()
	local tmp = {}

	for _, v in ipairs(player.GetAll()) do
		if v:GetSubRole() == ROLE_CULTIST and v:GetCultistMate() == self then
			table.insert(tmp, v)
		end
	end

	if #tmp == 0 then
		tmp = nil
	end

	return tmp
end

function HealPlayer(ply)
	ply:SetHealth(ply:GetMaxHealth())
end

if SERVER then
	util.AddNetworkString("TTT_HealPlayer")
	util.AddNetworkString("TTT2SyncCltiColor")

	function AddCultist(target, attacker)
		if target:IsCultist() or attacker:IsCultist() then return end

		target:SetNWEntity("binded_cultist", attacker)
		target:SetRole(ROLE_CULTIST, attacker:GetTeam())
		local credits = target:GetCredits()
		target:SetDefaultCredits()
		target:SetCredits(target:GetCredits() + credits)

		target.mateSubRole = attacker:GetSubRole()

		target.cltiTimestamp = os.time()
		target.cltiIssuer = attacker

		timer.Simple(0.1, SendFullStateUpdate)
	end

	hook.Add("PlayerShouldTakeDamage", "CltiProtectionTime", function(ply, atk)
		local pTime = GetConVar("ttt2_clti_protection_time"):GetInt()

		if pTime > 0 and IsValid(atk) and atk:IsPlayer()
		and ply:IsActive() and atk:IsActive()
		and atk:IsCultist() and atk.cltiIssuer == ply
		and atk.cltiTimestamp + pTime >= os.time() then
			return false
		end
	end)

	hook.Add("EntityTakeDamage", "CltiEntTakeDmg", function(target, dmginfo)
		local attacker = dmginfo:GetAttacker()

		if target:IsPlayer() and IsValid(attacker) and attacker:IsPlayer()
		and (target:Health() - dmginfo:GetDamage()) <= 0
		and hook.Run("TTT2CLTIAddCultist", attacker, target)
		then
			dmginfo:ScaleDamage(0)

			AddCultist(target, attacker)
			HealPlayer(target)

			-- do this clientside as well
			net.Start("TTT_HealPlayer")
			net.Send(target)
		end
	end)

	hook.Add("PlayerDisconnected", "CltiPlyDisconnected", function(discPly)
		local cltis, mate

		if discPly:IsCultist() then
			cltis = {discPly}
			mate = discPly:GetCultistMate()
		else
			cltis = discPly:GetCultists()
			mate = discPly
		end

		if cltis then
			local enabled = GetConVar("ttt2_clti_mode"):GetBool()

			for _, clti in ipairs(cltis) do
				if IsValid(clti) and clti:IsPlayer() and clti:IsActive() then
					clti:SetNWEntity("binded_cultist", nil)

					if enabled then
						local newRole = clti.mateSubRole or (IsValid(mate) and mate:GetSubRole())
						if newRole then
							clti:SetRole(newRole, TEAM_NOCHANGE)

							SendFullStateUpdate()
						end
					end
				end
			end
		end
	end)

	hook.Add("PostPlayerDeath", "PlayerDeathChangeClti", function(ply)
		if GetConVar("ttt2_clti_mode"):GetBool() then
			local cltis = ply:GetCultists()
			if cltis then
				for _, clti in ipairs(cltis) do
					if IsValid(clti) and clti:IsActive() then
						clti:SetNWEntity("binded_cultist", nil)

						local newRole = clti.mateSubRole or ply:GetSubRole()
						if newRole then
							clti:SetRole(newRole, TEAM_NOCHANGE)

							SendFullStateUpdate()
						end

						if #cltis == 1 then -- a player can just be binded with one player as cultist
							ply.spawn_as_cultist = clti
						end
					end
				end
			end
		end

		local mate = ply:GetCultistMate() -- Is Cultist?

		if not IsValid(mate) or ply.lastMateSubRole then return end

		ply.lastMateSubRole = ply.mateSubRole or mate:GetSubRole()
	end)

	hook.Add("PlayerSpawn", "PlayerSpawnsAsCultist", function(ply)
		if not ply.spawn_as_cultist then return end

		AddCultist(ply, ply.spawn_as_cultist)

		ply.spawn_as_cultist = nil
	end)

	hook.Add("TTT2OverrideDisabledSync", "CltiAllowTeammateSync", function(ply, p)
		if IsValid(p) and p:GetSubRole() == ROLE_CULTIST and ply:IsInTeam(p) and (not ply:GetSubRoleData().unknownTeam or ply == p:GetCultistMate()) then
			return true
		end
	end)

	hook.Add("TTTBodyFound", "CltiSendLastColor", function(ply, deadply, rag)
		if not IsValid(deadply) or deadply:GetSubRole() ~= ROLE_CULTIST then return end

		net.Start("TTT2SyncCltiColor")
		net.WriteString(deadply:EntIndex())
		net.WriteUInt(deadply.lastMateSubRole, ROLE_BITS)
		net.Broadcast()
	end)

	-- fix that innos can see their cltis
	hook.Add("TTT2SpecialRoleSyncing", "TTT2CltiInnoSyncFix", function(ply, tmp)
		local rd = ply:GetSubRoleData()
		local cltis = ply:GetCultists()

		if not rd.unknownTeam or not cltis then return end

		for _, clti in ipairs(cltis) do
			if IsValid(clti) and clti:IsInTeam(ply) then
				tmp[clti] = {ROLE_CULTIST, ply:GetTeam()}
			end
		end
	end)
end

if CLIENT then
	net.Receive("TTT_HealPlayer", function()
		HealPlayer(LocalPlayer())
	end)

	net.Receive("TTT2SyncCltiColor", function()
		local ply = Entity(net.ReadString())

		if not IsValid(ply) or not ply:IsPlayer() then return end

		ply.mateSubRole = net.ReadUInt(ROLE_BITS)
		ply.lastMateSubRole = net.ReadUInt(ROLE_BITS)
		ply:SetRoleColor(COLOR_BLACK)
	end)

	-- Modify colors
	hook.Add("TTT2ModifyRoleDkColor", "CltiModifyRoleDkColor", function(ply)
		return GetDarkenMateColor(ply, "dkcolor")
	end)

	hook.Add("TTT2ModifyRoleBgColor", "CltiModifyRoleBgColor", function(ply)
		return GetDarkenMateColor(ply, "bgcolor")
	end)
end

--modify role colors on both client and server
hook.Add("TTT2ModifyRoleColor", "CltiModifyRoleColor", function(ply)
	return GetDarkenMateColor(ply, "color")
end)

hook.Add("TTTPrepareRound", "CltiPrepareRound", function()
	for _, ply in ipairs(player.GetAll()) do
		ply.mateSubRole = nil
		ply.lastMateSubRole = nil
		ply.spawn_as_cultist = nil

		if SERVER then
			ply:SetNWEntity("binded_cultist", nil)
		end
	end
end)

-- CULTIST HITMAN FUNCTION
if SERVER then
	hook.Add("TTT2CheckCreditAward", "TTTCCultistMod", function(victim, attacker)
		if IsValid(attacker) and attacker:IsPlayer() and attacker:IsActive() and attacker:GetSubRole() == ROLE_CULTIST and not GetConVar("ttt2_clti_mode"):GetBool() then
			return false -- prevent awards
		end
	end)

	-- CLASSES syncing
	hook.Add("TTT2UpdateSubrole", "TTTCCultistMod", function(clti, oldRole, role)
		if not TTTC or not clti:IsActive() or role ~= ROLE_CULTIST or GetConVar("ttt2_clti_mode"):GetBool() then return end

		for _, ply in ipairs(player.GetAll()) do
			net.Start("TTT2CltiSyncClasses")
			net.WriteEntity(ply)
			net.WriteUInt(ply:GetCustomClass() or 0, CLASS_BITS)
			net.Send(clti)
		end
	end)

	include("target.lua")
end

if CLIENT then
	net.Receive("TTT2CltiSyncClasses", function(len)
		local target = net.ReadEntity()
		if not IsValid(target) then return end

		local hr = net.ReadUInt(CLASS_BITS)
		if hr == 0 then
			hr = nil
		end

		target:SetClass(hr)
	end)
end