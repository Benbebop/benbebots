package resource

import (
	"benbebop.net/benbebots/internal/generated/commands"
	"github.com/diamondburned/arikawa/v3/api"
	"github.com/diamondburned/arikawa/v3/discord"
)

type constNames map[string]api.CreateCommandData

func GetCommandData() map[string]map[discord.GuildID]constNames { // just so it isnt loaded into memory during regular execution
	return map[string]map[discord.GuildID]constNames{
		"benbebot": {
			1068640496139915345: {
				"PingMe": {
					ID:          commands.PingMe,
					Type:        discord.ChatInputCommand,
					Name:        "pingme",
					Description: "make the bots ping you",
					Options: []discord.CommandOption{
						&discord.IntegerOption{
							OptionName:  "times",
							Description: "number of times to ping you",
							Required:    true,
						},
					},
				},
				"MashupRadio": {
					ID:          commands.MashupRadio,
					Type:        discord.ChatInputCommand,
					Name:        "mashupradio",
					Description: "control mashup radio",
					Options: []discord.CommandOption{
						&discord.SubcommandOption{
							OptionName:  "skip",
							Description: "skip current mashup",
						},
					},
				},
				"Subscribe": {
					ID:          commands.Subscribe,
					Type:        discord.ChatInputCommand,
					Name:        "subscribe",
					Description: "subscribe to a certain service and send notifs to stuff",
					Options: []discord.CommandOption{
						&discord.StringOption{
							OptionName:  "url",
							Description: "url to subscribe to",
							Required:    true,
						},
						&discord.BooleanOption{
							OptionName:  "unsub",
							Description: "whether to unsubscribe",
							Required:    false,
						},
					},
				},
				"Download": {
					ID:          commands.Download,
					Type:        discord.ChatInputCommand,
					Name:        "download",
					Description: "download a video",
					Options:     []discord.CommandOption{},
				},
			},
			822165179692220476: {
				"Permarole": {
					ID:          commands.Permarole,
					Type:        discord.ChatInputCommand,
					Name:        "permarole",
					Description: "modify your permaroles",
					Options: []discord.CommandOption{
						&discord.SubcommandOption{
							OptionName:  "add",
							Description: "add a permarole",
							Required:    false,
							Options: []discord.CommandOptionValue{
								&discord.RoleOption{
									OptionName:  "role",
									Description: "permarole to add",
									Required:    true,
								},
							},
						},
						&discord.SubcommandOption{
							OptionName:  "remove",
							Description: "remove a permarole",
							Required:    false,
							Options: []discord.CommandOptionValue{
								&discord.RoleOption{
									OptionName:  "role",
									Description: "permarole to remove",
									Required:    true,
								},
							},
						},
						&discord.SubcommandOption{
							OptionName:  "list",
							Description: "list your permaroles",
							Required:    false,
							Options:     []discord.CommandOptionValue{},
						},
					},
				},
				"ManagePermaroles": {
					ID:          commands.ManagePermaroles,
					Type:        discord.ChatInputCommand,
					Name:        "managepermaroles",
					Description: "modify a user's permaroles",
					Options: []discord.CommandOption{
						&discord.SubcommandOption{
							OptionName:  "add",
							Description: "add a permarole",
							Required:    false,
							Options: []discord.CommandOptionValue{
								&discord.UserOption{
									OptionName:  "user",
									Description: "user to modify",
									Required:    true,
								},
								&discord.RoleOption{
									OptionName:  "role",
									Description: "permarole to add",
									Required:    true,
								},
							},
						},
						&discord.SubcommandOption{
							OptionName:  "remove",
							Description: "remove a permarole",
							Required:    false,
							Options: []discord.CommandOptionValue{
								&discord.UserOption{
									OptionName:  "user",
									Description: "user to modify",
									Required:    true,
								},
								&discord.RoleOption{
									OptionName:  "role",
									Description: "permarole to remove",
									Required:    true,
								},
							},
						},
						&discord.SubcommandOption{
							OptionName:  "list",
							Description: "list a user's permaroles",
							Required:    false,
							Options: []discord.CommandOptionValue{
								&discord.UserOption{
									OptionName:  "user",
									Description: "user to list",
									Required:    true,
								},
							},
						},
					},
				},
				"Sex": {
					ID:          commands.Sex,
					Type:        discord.ChatInputCommand,
					Name:        "sex",
					Description: "fuckyou",
					Options:     []discord.CommandOption{},
				},
			},
		},
		"fnaf": {
			1124505130348314644: {
				"Gnerb": {
					ID:          commands.Gnerb,
					Type:        discord.ChatInputCommand,
					Name:        "gnerb",
					Description: "force a gnerb to send",
				},
			},
		},
	}
}
