package main

import (
	"encoding/binary"
	"fmt"
	"os"
	"strconv"
	"strings"

	"benbebop.net/benbebots/internal/stats"
	"benbebop.net/benbebots/resource"
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

const (
	commandFile    = "internal/generated/commands/commands.go"
	commandFileOld = commandFile + "_old"
)

func updateCommands() {
	logs.OnFatal = func() {
		os.Rename(commandFileOld, commandFile)
		os.Exit(1)
	}
	os.Rename(commandFile, commandFileOld)

	f, err := os.OpenFile(commandFile, os.O_WRONLY|os.O_CREATE, os.ModePerm)
	if err != nil {
		logs.FatalQuick(err)
	}

	_, err = f.WriteString(`package commands

import "github.com/diamondburned/arikawa/v3/discord"

`)
	if err != nil {
		logs.FatalQuick(err)
	}

	for name, data := range resource.GetCommandData() {
		client := api.NewClient("Bot " + tokens[name].Password)
		app, err := client.CurrentApplication()
		if err != nil {
			logs.FatalQuick(err)
		}

		f.WriteString("// " + name + "\n\n")

		for guildId, constNames := range data {
			createData := make([]api.CreateCommandData, 0, len(constNames))
			for _, v := range constNames {
				createData = append(createData, v)
			}

			guildName := "global"
			var commands []discord.Command
			if guildId == 0 {
				commands, err = client.BulkOverwriteCommands(app.ID, createData)
				if err != nil {
					logs.FatalQuick(err)
				}
			} else {
				guild, err := client.Guild(guildId)
				if err != nil {
					logs.FatalQuick(err)
				}
				guildName = guild.Name
				commands, err = client.BulkOverwriteGuildCommands(app.ID, guildId, createData)
				if err != nil {
					logs.FatalQuick(err)
				}
			}

			f.WriteString("const ( // " + guildName + "\n")

			for constName, createe := range constNames {
				var found bool
				for _, created := range commands {
					if created.Name == createe.Name {
						found = true
						f.WriteString(fmt.Sprintf("\t%s discord.CommandID = %d\n", constName, created.ID))
						break
					}
				}
				if !found {
					f.WriteString(fmt.Sprintf("\t%s discord.CommandID = %d\n", constName, createe.ID))
				}
			}
			f.WriteString(")\n\n")

			logs.Info("Updated %d commands for %s in %s.", len(commands), app.Name, guildName)
		}
	}
}

func resetStats() error {
	// canned foods
	token, err := lvldb.Get([]byte("cannedFoodToken"), nil)
	if err != nil {
		logs.FatalQuick(err)
		return err
	}
	client := api.NewClient(string(token))

	validChannelsStr, err := lvldb.Get([]byte("cannedFoodValidChannels"), nil)
	if err != nil {
		logs.FatalQuick(err)
		return err
	}

	var total int64
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
		logs.Info("scanning %s in %s", channel.Name, guild.Name)

		messages, err := client.Messages(channel.ID, 0)
		if err != nil {
			logs.FatalQuick(err)
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
		logs.Info("found %d canned foods", current)
		total += int64(current)
	}

	err = lvldb.Put(stats.GetKey("Canned Foods"), binary.AppendVarint(nil, total), nil)
	if err != nil {
		logs.FatalQuick(err)
		return err
	}
	logs.Info("found %d canned foods in all channels", total)

	// family guys
	client = api.NewClient("Bot " + tokens["familyGuy"].Password)
	me, err := client.Me()
	if err != nil {
		logs.FatalQuick(err)
		return err
	}

	guilds, err := client.Guilds(0)
	if err != nil {
		logs.FatalQuick(err)
		return err
	}

	total = 0
	users := []discord.UserID{} //opts.PublicChannel
	index := 1
	for _, guild := range guilds {
		logs.Info("scanning members from %s", guild.Name)
		members, err := client.Members(guild.ID, 0)
		if err != nil {
			logs.FatalQuick(err)
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

			logs.Info("scanning %s", member.User.Username)
			messages, err := client.Messages(priv.ID, 0)
			if err != nil {
				logs.FatalQuick(err)
				return err
			}

			var current uint
			for _, message := range messages {
				if message.Author.ID != me.ID || (len(message.Attachments) <= 0 && !strings.HasPrefix(message.Content, "https://cdn.discordapp.com/attachments/")) {
					continue
				}

				current += 1
			}
			logs.Info("found %d/%d family guy clips", current, len(messages))
			total += int64(current)
		}
	}

	err = lvldb.Put(stats.GetKey("Family Guys"), binary.AppendVarint(nil, total), nil)
	if err != nil {
		logs.FatalQuick(err)
		return err
	}
	logs.Info("found %d family guy clips sent", total)

	return nil
}
