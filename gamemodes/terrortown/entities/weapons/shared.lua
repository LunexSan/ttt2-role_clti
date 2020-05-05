SWEP.Base = "weapon_tttbase"

SWEP.Spawnable = true
SWEP.AutoSpawnable = false
SWEP.AdminSpawnable = true

SWEP.HoldType = "pistol"

SWEP.AutoSwitchTo = false
SWEP.AutoSwitchFrom = false

if SERVER then
	AddCSLuaFile()

	resource.AddFile("materials/vgui/ttt/icon_cultistdeagle.vmt")

	util.AddNetworkString("tttCultistMSG_attacker")
	util.AddNetworkString("tttCultistMSG_target")
	util.AddNetworkString("tttCultistRefillCDReduced")
	util.AddNetworkString("tttCultistDeagleRefilled")
	util.AddNetworkString("tttCultistDeagleMiss")
	util.AddNetworkString("tttCultistSameTeam")
else
	hook.Add("Initialize", "TTTInitCltiDeagleLang", function()
		LANG.AddToLanguage("English", "ttt2_weapon_cultistdeagle_desc", "Shoot a player to make him your cultist.")
		LANG.AddToLanguage("Deutsch", "ttt2_weapon_cultistdeagle_desc", "Schieße auf einen Spieler, um ihn zu deinem Cultist zu machen.")
	end)

	SWEP.PrintName = "Cultist Deagle"
	SWEP.Author = "Alf21"

	SWEP.Slot = 7

	SWEP.ViewModelFOV = 54
	SWEP.ViewModelFlip = false

	SWEP.Category = "Deagle"
	SWEP.Icon = "vgui/ttt/icon_cultistdeagle.vtf"
	SWEP.EquipMenuData = {
		type = "Weapon",
		desc = "ttt2_weapon_cultistdeagle_desc"
	}
end

-- dmg
SWEP.Primary.Delay = 1
SWEP.Primary.Recoil = 6
SWEP.Primary.Automatic = false
SWEP.Primary.NumShots = 1
SWEP.Primary.Damage = 0
SWEP.Primary.Cone = 0.00001
SWEP.Primary.Ammo = "2"
SWEP.Primary.ClipSize = 1
SWEP.Primary.ClipMax = 1
SWEP.Primary.DefaultClip = 1

-- some other stuff
SWEP.InLoadoutFor = nil
SWEP.AllowDrop = false
SWEP.IsSilent = false
SWEP.NoSights = false
SWEP.UseHands = true
SWEP.Kind = WEAPON_EXTRA
SWEP.CanBuy = {}
SWEP.LimitedStock = true
SWEP.globalLimited = true
SWEP.NoRandom = true

-- view / world
SWEP.ViewModel = "models/weapons/cstrike/c_pist_deagle.mdl"
SWEP.WorldModel = "models/weapons/w_pist_deagle.mdl"
SWEP.Weight = 5
SWEP.Primary.Sound = Sound("Weapon_Deagle.Single")

SWEP.IronSightsPos = Vector(-6.361, -3.701, 2.15)
SWEP.IronSightsAng = Vector(0, 0, 0)

SWEP.notBuyable = true

local ttt2_cultist_deagle_refill_conv = CreateConVar("ttt2_clti_deagle_refill", 1, {FCVAR_NOTIFY, FCVAR_ARCHIVE})
local ttt2_cultist_deagle_refill_cd_conv = CreateConVar("ttt2_clti_deagle_refill_cd", 120, {FCVAR_NOTIFY, FCVAR_ARCHIVE})

local function CultistDeagleRefilled(wep)
	if not IsValid(wep) then return end

	local text = LANG.GetTranslation("ttt2_clti_recharged")
	MSTACK:AddMessage(text)

	STATUS:RemoveStatus("ttt2_cultist_deagle_reloading")
	net.Start("tttCultistDeagleRefilled")
	net.WriteEntity(wep)
	net.SendToServer()
end

local function CultistDeagleCallback(attacker, tr, dmg)
	if CLIENT then return end

	local target = tr.Entity

	--invalid shot return
	if not GetRoundState() == ROUND_ACTIVE or not IsValid(attacker) or not attacker:IsPlayer() or not attacker:IsTerror() then return end

	--no/bad hit: (send message), start timer and return
	if not IsValid(target) or not target:IsPlayer() or not target:IsTerror() or target:IsInTeam(attacker) then
		if IsValid(target) and target:IsPlayer() and target:IsTerror() and target:IsInTeam(attacker) then
			net.Start("tttCultistSameTeam")
			net.Send(attacker)
		end

		if ttt2_cultist_deagle_refill_conv:GetBool() then
			net.Start("tttCultistDeagleMiss")
			net.Send(attacker)
		end

		return
	end

	local deagle = attacker:GetWeapon("weapon_ttt2_cultistdeagle")
	if IsValid(deagle) then
		deagle:Remove()
	end

	AddCultist(target, attacker)

	net.Start("tttCultistMSG_attacker")
	net.WriteEntity(target)
	net.Send(attacker)

	net.Start("tttCultistMSG_target")
	net.WriteEntity(attacker)
	net.Send(target)

	return true
end

function SWEP:OnDrop()
	self:Remove()
end

function SWEP:ShootBullet(dmg, recoil, numbul, cone)
	cone = cone or 0.01

	local bullet = {}
	bullet.Num = 1
	bullet.Src = self:GetOwner():GetShootPos()
	bullet.Dir = self:GetOwner():GetAimVector()
	bullet.Spread = Vector(cone, cone, 0)
	bullet.Tracer = 0
	bullet.TracerName = self.Tracer or "Tracer"
	bullet.Force = 10
	bullet.Damage = 0
	bullet.Callback = CultistDeagleCallback

	self:GetOwner():FireBullets(bullet)

	self.BaseClass.ShootBullet(self, dmg, recoil, numbul, cone)
end

function SWEP:OnRemove()
	if CLIENT then
		STATUS:RemoveStatus("ttt2_cultist_deagle_reloading")

		timer.Stop("ttt2_cultist_deagle_refill_timer")
	end
end

function ShootCultist(target, dmginfo)
	local attacker = dmginfo:GetAttacker()

	if not attacker:IsPlayer() or not target:IsPlayer() or not IsValid(attacker:GetActiveWeapon())
		or not attacker:IsTerror() or not IsValid(target) or not target:IsTerror() then return end

	if target:GetSubRole() == ROLE_CULTLEADER or target:GetSubRole() == ROLE_CULTADJUTANT or target:GetSubRole() == ROLE_CULTIST then
		return
	end

	AddCultist(target, attacker)

	net.Start("tttCultistMSG_attacker")
	net.WriteEntity(target)
	net.Send(attacker)

	net.Start("tttCultistMSG_target")
	net.WriteEntity(attacker)
	net.Send(target)
end


if SERVER then
	hook.Add("PlayerDeath", "CultistDeagleRefillReduceCD", function(victim, inflictor, attacker)
		if IsValid(attacker) and attacker:IsPlayer() and attacker:HasWeapon("weapon_ttt2_cultistdeagle") and ttt2_cultist_deagle_refill_conv:GetBool() then
			net.Start("tttCultistRefillCDReduced")
			net.Send(attacker)
		end
	end)
end

if CLIENT then
	hook.Add("TTT2FinishedLoading", "InitCltiMsgText", function()
		LANG.AddToLanguage("English", "ttt2_clti_shot", "Successfully shot {name} too be a cultist!")
		LANG.AddToLanguage("Deutsch", "ttt2_clti_shot", "Erfolgreich {name} zum Kultisten geschossen!")

		LANG.AddToLanguage("English", "ttt2_clti_were_shot", "You were shot to be a cultist by {name}!")
		LANG.AddToLanguage("Deutsch", "ttt2_clti_were_shot", "Du wurdest von {name} zum Kultisten geschossen!")

		LANG.AddToLanguage("English", "ttt2_clti_sameteam", "You can't shoot someone from your team to be a cultist!")
		LANG.AddToLanguage("Deutsch", "ttt2_clti_sameteam", "Du kannst niemanden aus deinem Team zum Kumpanen schießen!")

		LANG.AddToLanguage("English", "ttt2_clti_ply_killed", "Your cultist deagle cooldown was reduced by {amount} seconds.")
		LANG.AddToLanguage("Deutsch", "ttt2_clti_ply_killed", "Deine Kultist Deagle Wartezeit wurde um {amount} Sekunden reduziert.")

		LANG.AddToLanguage("English", "ttt2_clti_recharged", "Your cultist deagle has been recharged.")
		LANG.AddToLanguage("Deutsch", "ttt2_clti_recharged", "Deine Kultist Deagle wurde wieder aufgefüllt.")
	end)

	hook.Add("Initialize", "ttt_cultist_init_status", function()
		STATUS:RegisterStatus("ttt2_cultist_deagle_reloading", {
			hud = Material("vgui/ttt/hud_icon_deagle.png"),
			type = "bad"
		})
	end)

	net.Receive("tttCultistMSG_attacker", function(len)
		local target = net.ReadEntity()
		if not IsValid(target) then return end

		local text = LANG.GetParamTranslation("ttt2_clti_shot", {name = target:GetName()})
		MSTACK:AddMessage(text)
	end)

	net.Receive("tttCultistMSG_target", function(len)
		local attacker = net.ReadEntity()
		if not IsValid(attacker) then return end

		local text = LANG.GetParamTranslation("ttt2_clti_were_shot", {name = attacker:GetName()})
		MSTACK:AddMessage(text)
	end)

	net.Receive("tttCultistRefillCDReduced", function()
		if not timer.Exists("ttt2_cultist_deagle_refill_timer") or not LocalPlayer():HasWeapon("weapon_ttt2_cultistdeagle") then return end

		local timeLeft = timer.TimeLeft("ttt2_cultist_deagle_refill_timer") or 0
		local newTime = math.max(timeLeft - ttt2_clti_deagle_refill_cd_per_kill_conv:GetInt(), 0.1)

		local wep = LocalPlayer():GetWeapon("weapon_ttt2_cultistdeagle")
		if not IsValid(wep) then return end

		timer.Adjust("ttt2_cultist_deagle_refill_timer", newTime, 1, function()
			if not IsValid(wep) then return end

			CultistDeagleRefilled(wep)
		end)

		if STATUS.active["ttt2_cultist_deagle_reloading"] then
			STATUS.active["ttt2_cultist_deagle_reloading"].displaytime = CurTime() + newTime
		end
	end)

	net.Receive("tttCultistDeagleMiss", function()
		local client = LocalPlayer()
		if not IsValid(client) or not client:IsTerror() or not client:HasWeapon("weapon_ttt2_cultistdeagle") then return end

		local wep = client:GetWeapon("weapon_ttt2_cultistdeagle")
		if not IsValid(wep) then return end

		local initialCD = ttt2_cultist_deagle_refill_cd_conv:GetInt()

		STATUS:AddTimedStatus("ttt2_cultist_deagle_reloading", initialCD, true)

		timer.Create("ttt2_cultist_deagle_refill_timer", initialCD, 1, function()
			if not IsValid(wep) then return end

			CultistDeagleRefilled(wep)
		end)
	end)

	net.Receive("tttCultistSameTeam", function()
		MSTACK:AddMessage(LANG.GetTranslation("ttt2_clti_sameteam"))
	end)
else
	net.Receive("tttCultistDeagleRefilled", function()
		local wep = net.ReadEntity()

		if not IsValid(wep) then return end

		wep:SetClip1(1)
	end)
end