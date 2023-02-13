local config = require("./config")

local holidays = {d = {}, m = {}}

local e = {
	pface = "\xF0\x9F\xA5\xB3", 
	fist = "\xE2\x9C\x8A", 
	beers = "\xF0\x9F\x8D\xBB", 
	french = "\xEE\x94\x8D", 
	canada = "\xF0\x9F\x87\xA8\xF0\x9F\x87\xA6", 
	circ_orange = "\xF0\x9F\x9F\xA0", 
	gay = "\xF0\x9F\x8F\xB3\xEF\xB8\x8F\xE2\x80\x8D\xF0\x9F\x8C\x88", 
	turkey = "\xF0\x9F\xA6\x83", 
	pump = "\xF0\x9F\x8E\x83", 
	w_tree = "\xF0\x9F\x8E\x84", 
	ind_i = "\xE1\x90\x83", ind_nu = "\xE1\x93\x84", ind_k = "\xE1\x92\x83", ind_ti = "\xE1\x91\x8E", ind_tu = "\xE1\x91\x90", ind_t = "\xE1\x91\xA6"
}

local hdefault = {
	avatar = "default.jpg",
	name = "benbebot",
	text = false,
	status = "",
	game = "Sex Simulator"
}

local hnone = {
	avatar = "default.jpg",
	name = "benbebot",
	text = false,
	status = "",
	game = "none"
}

holidays.d["0101"] = { -- NEW YEAR
	avatar = "new_year.jpg",
	name = e.pface .. " benbebot " .. e.pface,
	text = "New Year"
}

holidays.d["3112"] = { -- NEW YEAR EVE
	avatar = "new_year.jpg",
	name = "benbebot",
	text = "New Year",
	game = "New Year Countdown"
}

holidays.d["1002"] = { -- BENBEBOT BDAY
	name = e.pface .. " benbebot " .. e.pface,
	text = "Benbebot Birthday"
}

holidays.d["1703"] = { -- ST PATRIC
	avatar = "green_shirt.jpg",
	name = e.beers .. " benbebot " .. e.beers,
	text = "St. Patrick's Day",
	game = nil
}

holidays.d["0704"] = { -- :)
	game = "Alphaplace"
}

holidays.d["0305"] = { -- :)
	avatar = nil,
	name = "benbebot",
	text = "Thank You GoldPikaKnight",
	game = "Minecraft"
}

holidays.d["2106"] = { -- INDIGENOUS DAY
	avatar = "indig.jpg",
	name = e.ind_i .. e.ind_nu .. e.ind_k .. e.ind_ti .. e.ind_tu .. e.ind_t, -- Olittâgutik
	text = "Indigenous Peoples Day",
	game = "none"
}

holidays.d["2406"] = { -- FRENCH DAY
	avatar = "quebec.jpg",
	name = "benbebot",
	text = "Saint-Jean-Baptiste Day",
	game = "Spy TF2 Simulator"
}

holidays.d["0906"] = { -- SEGS DAY
	game = "Sex IRL"
}

holidays.d["0107"] = { -- CANADA DAY
	avatar = "canada_day.jpg",
	name = e.canada .. " benbebot " .. e.canada,
	text = "Canada Day",
	game = "Syrup Simulator"
}

holidays.d["0508"] = { -- HERITAGE DAY
	avatar = nil,
	name = nil,
	text = nil,
	game = nil
}

holidays.d["3009"] = { -- RECONCILIATION DAY
	avatar = nil,
	name = "benbebot",
	text = "Truth and Reconciliation Day"
}

-- holidays.m["10"] = { -- PRIDE
	-- avatar = "gay_month.jpg",
	-- name = e.gay .. " benbebot " .. e.gay,
	-- text = "Pride Month",
	-- game = "Gay Sex Simulator"
-- }

holidays.d["1010"] = { -- THANKSGIVING
	avatar = "thanks.jpg",
	name = e.turkey .. " benbebot " .. e.turkey,
	text = "Thanksgiving",
	game = ":turkey:"
}

holidays.d["1710"] = { -- THANKSGIVING
	avatar = "poopass.jpg",
	name = "Poopass Run",
	text = "Poopass Run",
	game = "Team Fortress 2"
}

holidays.d["0910"] = { -- Leif Erikson
	avatar = nil,
	name = "benbebot",
	text = "Leif Erikson Day",
	game = "Viking Simulator"
}

holidays.d["3110"] = { -- HALLOWEEN
	avatar = nil,
	name = e.pump .. " benbebot " .. e.pump,
	text = "Halloween",
	game = "Phasmophobia"
}

holidays.d["1011"] = { -- FO4 RELEASE
	game = "Fallout 4"
}

holidays.d["1611"] = { -- HL2 RELEASE
	game = "Half Life 2"
}

holidays.d["1911"] = { -- HL RELEASE
	game = "Half Life"
}

holidays.d["1111"] = { -- REMEMBRANCE DAY
	avatar = nil,
	name = nil,
	text = "Remembrance Day",
	game = "none"
}

holidays.d["2512"] = { -- CHRISTMAS
	avatar = nil,
	name = e.w_tree .. " benbebot " .. e.w_tree,
	text = "Christmas",
	game = "Santa Simulator"
}

function getHoliday(index)
	if config.get().misc.suspend_holiday then
		return hnone
	else
	local h = holidays.d[os.date("%d%m")] or hdefault
	
	for i,v in pairs(hdefault) do
		if not h[i] then 
			h[i] = v
		end
	end
	
	return h
	end
end

return getHoliday