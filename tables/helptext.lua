local tbl = {
	
	role = [[You can add a role with
role [role name]
You can remove a role with
unrole [role name]

You can add a permarole, which will persist if you leave, with
permarole [role name]
Remove a permarole with
unpermarole [role name]
Set all current roles to permaroles
permarole all
note: permaroles can be setup for any role, not just the ones in "role list", you must just already have the role

reccomended roles:

pinged for stupid shit, pinged for important shit

type "role list" for whole list]],
	
	render = [[render takes in lua code and produces an image. Its syntax is as follows:

bbb render <x> <y> \`\`\`lua
<your code here>
\`\`\`

<x> is the width of the image, <y> is the height

This code will run on every pixel and must return the rgb (0-1) of said pixel. There are 4 variables you can access, the x and y coordinates of the current pixel (x, y), and the length and width of the image (h, v). You can also access some functions, all of the lua math functions are avalible other then randomseed (randomseed is already set to os.clock for you). The following code will produce an image 50 by 50 pixels, mapping each pixel.

bbb render 50 50 \`\`\`lua
return x / h, y / v, 0
\`\`\`]],

	companyrebrand = [[company was succesfully rebranded, here are the changes:
company name `1a` was changed to `1b`
company color `2aa 2ab 2ac` was changed to `2ba 2bb 2bc`
autoemploy string `3a` was changed to `3b`
ceo role name `4a` was changed to `4b`
employee role name `5a` was changed to `5b`]],

	joingmod = [[On the main menu, click on options, then advanced options at the bottom of the options window and then check "enable developer console". 
Next, on the main menu you will have to press `SHIFT` + `~` or in game just press `~`.
Lastly, type `connect p2p:<address>` in and press enter.
You should then join the game, if not then idk]]

}

return tbl