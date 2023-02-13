local success, err = pcall(require, './bot-pvz')

if not success then
	print(err)
	os.execute("pause")
	os.exit()
end