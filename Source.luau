--// Author: 8ch99
--// Date written: 10/04/2024

--[[

This is the permissions module that i originally wrote for PBSF, its still used but ive decided to open source it
Its a pretty solid and basic system, with caching aswell
	
You can add your own permissions by adding modules under this one that return the function used to do permission checks
Or you can add them where the hardcoded functions are if thats what you prefer
	
You can also adjust the caching interval if needed
	
This also has a bypass system, which if a player is bypassed, they automatically pass all checks
	
API:
	Permissions:Add(Permission: string, Function: (Player) -> boolean) - Adds a new permission to the permissions system
	Permissions:CreateCache(Player: Player, Permission: string, Result: boolean?) - Creates a new cache instance for the given player, permission with the result.
	Permissions:GetCache(Player: Player, Permission: string) - Returns the found cache instance for the player and permission
	Permissions:Has(Player, Permission: string) - Returns if the given player validates the given permission
	Permissions:HasList(Player, Permissions: { string }) - Returns if the given player validates one of more of the given permissions (returns true if none given)
		- If a permission passes, the permission name is also returned.
	Permissions:HasListStrict(Player, Permissions: { string }) - Returns if the given player validates EVERY given permission
		- If a permission fails, the permission name is also returned.
	Permissions:AddBypass(Player: Player) - Gives the player a global bypass
	Permissions:RemoveBypass(Player: Player) - Revokes the player's global bypass
	Permissions:AddBypassFromId(UserId: number) - Gives the UserId a global bypass
	Permissions:RemoveBypassFromId(UserId: number) - Revokes the UserId's global bypass

Example Usage:
	
Permissions:Has(Player, "Owner") --// Will be true if the "Owner" permission check succeeds
Permissions:HasList(Player, { "Moderator", "Owner" }) --// Will be true if ANY of these checks pass
Permissions:HasList(Player, {}) --// Will always be true, since it auto assumes no permissions are needed
Permissions:HasList(Player) --// Will also always be true, since it auto assumes no permissions are needed if there is nothing to check
Permissions:HasListStrict(Player, { "Moderator", "Owner" }) --// Will only be true if ALL checks pass
Permissions:HasListStrict(Player, {}) --// Will always be false

]]

local Permissions = {}
Permissions.CacheInterval = 60
Permissions.Cache = {}
Permissions.Functions = {}
Permissions.Bypasses = {}

--// @module Permissions

function Permissions:Add(Permission: string, Function: (Player) -> boolean)
	self.Cache[Permission] = {}
	self.Functions[Permission] = Function
end

function Permissions:CreateCache(Player: Player, Permission: string, Result: boolean?)
	local CacheInstance = {
		Time = os.clock(),
		Result = (Result == nil and false) or Result
	}

	self.Cache[Permission][Player.UserId] = CacheInstance

	return CacheInstance
end

function Permissions:GetCache(Player: Player, Permission: string)
	local Cache = self.Cache[Permission]
	if Cache then
		return Cache[Player.UserId]
	end
end

function Permissions:Has(Player: Player, Permission: string)
	if self.Bypasses[Player.UserId] then
		return true
	end
	
	if not Permission then
		--// An empty list/non-existant list will be assumed as an "allow everyone"
		return true
	end
	
	if not self.Functions[Permission] then
		warn(`Permissions: Unknown permission '{Permission}'!`)
		return false
	end

	local Cache = self:GetCache(Player, Permission)
	if Cache and os.clock() - Cache.Time <= self.CacheInterval then
		return Cache.Result
	end

	local Success, Result = pcall(function()
		return self.Functions[Permission](Player) == true
	end)

	if Success then
		return self:CreateCache(Player, Permission, Result).Result
	end

	if Cache then
		--// Return the previous result if failed
		return Cache.Result
	end

	return false
end

function Permissions:HasList(Player: Player, Permissions: { string })
	if self.Bypasses[Player.UserId] then
		return true
	end
	
	if not Permissions or #Permissions == 0 then
		--// An empty list/non-existant list will be assumed as an "allow everyone"
		return true
	end

	for _, Permission in Permissions do
		if self:Has(Player, Permission) then
			return true, Permission
		end
	end

	return false
end

function Permissions:HasListStrict(Player: Player, Permissions: { string })
	if self.Bypasses[Player.UserId] then
		return true
	end

	if not Permissions or #Permissions == 0 then
		return false
	end

	for _, Permission in Permissions do
		if not self:Has(Player, Permission) then
			return false, Permission
		end
	end

	return true
end

function Permissions:AddBypass(Player: Player)
	self.Bypasses[Player.UserId] = true
end

function Permissions:RemoveBypass(Player: Player)
	self.Bypasses[Player.UserId] = nil
end

function Permissions:AddBypassFromId(UserId: number)
	self.Bypasses[UserId] = true
end

function Permissions:RemoveBypassFromId(UserId: number)
	self.Bypasses[UserId] = nil
end

--// Hardcoded permissions
Permissions:Add("Nobody", function()
	return false
end)

--// Require childing modules
for _, Module in script:GetChildren() do
	Permissions:Add(Module.Name, require(Module))
end

return Permissions
