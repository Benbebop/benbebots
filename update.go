package main

import (
	"encoding/json"
	"log"
	"os"

	"github.com/diamondburned/arikawa/v3/api"
	"github.com/diamondburned/arikawa/v3/discord"
)

func createCommandsToCommands(inputs []api.CreateCommandData) []discord.Command {
	output := make([]discord.Command, len(inputs))
	for index, input := range inputs {
		output[index] = discord.Command{
			ID:                       input.ID,
			Type:                     input.Type,
			Name:                     input.Name,
			NameLocalizations:        input.NameLocalizations,
			Description:              input.Description,
			DescriptionLocalizations: input.DescriptionLocalizations,
			Options:                  input.Options,
			DefaultMemberPermissions: input.DefaultMemberPermissions,
			NoDMPermission:           input.NoDMPermission,
			NoDefaultPermission:      input.NoDefaultPermission,
		}
	}
	return output
}

var commandFile = "resource/commands.json"
var commandFileOld = "resource/commands_old.json"

func (b *Benbebots) UpdateCommands(reset bool) error {
	var toUnmarshal map[string]map[discord.GuildID][]api.CreateCommandData
	toMarshal := make(map[string]map[discord.GuildID][]discord.Command)

	inData, err := os.ReadFile(commandFile)
	if err != nil {
		return err
	}
	err = json.Unmarshal(inData, &toUnmarshal)
	if err != nil {
		return err
	}

	for index, profile := range toUnmarshal {
		client := api.NewClient("Bot " + b.Tokens[index].Password)
		myUser, err := client.Me()
		if err != nil {
			log.Println(err)
			continue
		}

		app, err := client.CurrentApplication()
		if err != nil {
			log.Println(err)
			continue
		}
		for guildID, cmds := range profile {
			guildName := "all guilds"
			var commands []discord.Command

			if guildID == 0 {
				commands, err = client.BulkOverwriteCommands(app.ID, cmds)
			} else {
				guild, err := client.Guild(guildID)
				if err != nil {
					log.Println(err)
					continue
				}
				guildName = guild.Name
				commands, err = client.BulkOverwriteGuildCommands(app.ID, guildID, cmds)
				if err != nil {
					log.Println(err)
					continue
				}
			}
			if _, ok := toMarshal[index]; !ok {
				toMarshal[index] = make(map[discord.GuildID][]discord.Command)
			}

			if err != nil {
				toMarshal[index][guildID] = createCommandsToCommands(cmds)
				log.Printf("Failed to update commands for %s in %s: %s.\n", myUser.Username, guildName, err)
			} else {
				toMarshal[index][guildID] = commands
				log.Printf("Updated %d commands for %s in %s.\n", len(commands), myUser.Username, guildName)
			}
		}
	}

	outData, err := json.MarshalIndent(toMarshal, "", "\t")
	if err != nil {
		return err
	}

	if _, err = os.Stat(commandFileOld); err != nil {
		err = os.Rename(commandFile, commandFileOld)
		if err != nil {
			return err
		}
	}
	err = os.WriteFile(commandFile, outData, 0777)
	if err != nil {
		return err
	}
	return nil
}
