local default_header = {
	{"Host", "www.aha-music.com"},
	{"Accept", "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8"},
	{"Content-Type", "multipart/form-data; boundary=---------------------------36101260663944986031757793179"},
	{"Connection", "keep-alive"},
	{"Upgrade-Insecure-Requests", 0},
	{"Sec-Fetch-Dest", "document"},
}

local default_payload = [[-----------------------------36101260663944986031757793179
Content-Disposition: form-data; name="_token"

cpWcOzwD56C5mv6uAWmw5WUxoXXPCHL5JaMfrYiH
-----------------------------36101260663944986031757793179
Content-Disposition: form-data; name="files[]"; filename="video0.mp4"
Content-Type: video/mp4
]]