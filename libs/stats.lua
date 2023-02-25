local discordia = require("discordia")
local class = discordia.class
local Container = class.classes.Container

local Stat = class("Stat", Container)

function Stat:__init( ... )
	Container.__init(self, ...)
end

function Stat:get()
	return self._parent.name:match("^(.-)%s*:%s*(%d+)")
end

function Stat:set( amount, name )
	name = name or self._parent.name:match("^(.-)%s*:")
	self._parent:setName(string.format("%s : %d", name, amount))
end

function Stat:increment( amount )
	amount = amount or 1
	
	local name, value = self:get()
	value = value + amount
	self:set( amount, name )
end

local Client = class.classes.Client

function Client.Stat( channel )
	return Stat( channel )
end