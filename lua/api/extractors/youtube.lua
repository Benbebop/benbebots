local _LOGIN_URL, _TWOFACTOR_URL = 'https://accounts.google.com/ServiceLogin', 'https://accounts.google.com/signin/challenge'

local _LOOKUP_URL, _CHALLENGE_URL, _TFA_URL = 'https://accounts.google.com/_/signin/sl/lookup', 'https://accounts.google.com/_/signin/sl/challenge', 'https://accounts.google.com/_/signin/challenge?hl=en&TL={0}'

local _PLAYLIST_ID_RE = r'(?:(?:PL|LL|EC|UU|FL|RD|UL|TL|PU|OLAK5uy_)[0-9A-Za-z-_]{10,}|RDMM)'

local yt = {}
yt.__index = yt

function create()
	
	return setmetatable({}, yt)
	
end

function yt:_login()
	 username, password = self._get_login_info()
	 
	 if not username then
	 
	 end
	 
	 
	 
end