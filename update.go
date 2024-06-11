package main

import (
	"encoding/binary"
	"encoding/json"
	"log"
	"os"
	"strconv"
	"strings"

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
			return err
		}

		app, err := client.CurrentApplication()
		if err != nil {
			return err
		}
		for guildID, cmds := range profile {
			guildName := "all guilds"
			var commands []discord.Command

			if guildID == 0 {
				commands, err = client.BulkOverwriteCommands(app.ID, cmds)
			} else {
				guild, err := client.Guild(guildID)
				if err != nil {
					return err
				}
				guildName = guild.Name
				commands, err = client.BulkOverwriteGuildCommands(app.ID, guildID, cmds)
				if err != nil {
					return err
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

func (b *Benbebots) ResetStats() error {
	// canned foods
	token, err := b.LevelDB.Get([]byte("cannedFoodToken"), nil)
	if err != nil {
		log.Panicln(err)
		return err
	}
	client := api.NewClient(string(token))

	validChannelsStr, err := b.LevelDB.Get([]byte("cannedFoodValidChannels"), nil)
	if err != nil {
		log.Panicln(err)
		return err
	}

	var total uint64
	for _, v := range strings.Fields(string(validChannelsStr)) {
		id, _ := strconv.ParseUint(v, 10, 64)
		if id == 0 {
			continue
		}

		channel, err := client.Channel(discord.ChannelID(id))
		if err != nil {
			continue
		}

		guild, err := client.Guild(channel.GuildID)
		if err != nil {
			continue
		}
		log.Printf("scanning %s in %s", channel.Name, guild.Name)

		messages, err := client.Messages(channel.ID, 0)
		if err != nil {
			log.Panicln(err)
			return err
		}

		var current uint
		for _, message := range messages {
			for i, reaction := range message.Reactions {
				if i > 2 {
					break
				}

				if reaction.Emoji.APIString() != cannedFoodEmoji {
					continue
				}

				current += uint(reaction.CountDetails.Normal)
			}
		}
		log.Printf("found %d canned foods\n", current)
		total += uint64(current)
	}

	err = b.LevelDB.Put(getKey("Canned Foods"), binary.AppendUvarint(nil, total), nil)
	if err != nil {
		log.Panicln(err)
		return err
	}
	log.Printf("found %d canned foods in all channels", total)

	// family guys
	client = api.NewClient("Bot " + b.Tokens["familyGuy"].Password)
	me, err := client.Me()
	if err != nil {
		log.Panicln(err)
		return err
	}

	guilds, err := client.Guilds(0)
	if err != nil {
		log.Panicln(err)
		return err
	}

	total = 0
	users := []discord.UserID{} //opts.PublicChannel
	index := 1
	for _, guild := range guilds {
		log.Printf("scanning members from %s\n", guild.Name)
		members, err := client.Members(guild.ID, 0)
		if err != nil {
			log.Panicln(err)
			return err
		}
		users = append(users, make([]discord.UserID, len(members)+1)...)

		for _, member := range members {
			exists := false
			for _, id := range users[:index] {
				if id == member.User.ID {
					exists = true
				}
			}
			if exists {
				continue
			}
			users[index] = member.User.ID
			index += 1

			priv, err := client.CreatePrivateChannel(member.User.ID)
			if err != nil {
				continue
			}

			log.Printf("scanning %s\n", member.User.Username)
			messages, err := client.Messages(priv.ID, 0)
			if err != nil {
				log.Panicln(err)
				return err
			}

			var current uint
			for _, message := range messages {
				if message.Author.ID != me.ID || (len(message.Attachments) <= 0 && !strings.HasPrefix(message.Content, "https://cdn.discordapp.com/attachments/")) {
					continue
				}

				current += 1
			}
			log.Printf("found %d/%d family guy clips\n", current, len(messages))
			total += uint64(current)
		}
	}

	err = b.LevelDB.Put(getKey("Family Guys"), binary.AppendUvarint(nil, total), nil)
	if err != nil {
		log.Panicln(err)
		return err
	}
	log.Printf("found %d family guy clips sent", total)

	return nil
}
