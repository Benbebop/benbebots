package main

import (
	"encoding/json"
	"log"
	"os"

	"github.com/diamondburned/arikawa/v3/api"
	"github.com/diamondburned/arikawa/v3/discord"
)

type sqlWarning struct {
	level   string
	code    uint16
	message string
}

func sqlCatchWarning() sqlWarning {
	row := db.QueryRow("SHOW WARNINGS")
	var warn sqlWarning
	row.Scan(&warn.level, &warn.code, &warn.message)
	return warn
}

func sqlGetUsername() string {
	row := db.QueryRow("SELECT USER()")
	var username string
	if err := row.Scan(&username); err == nil {
		return username
	}
	return ""
}

// TODO pass variable arguments to exec
func sqlAssertWarn(code uint16, out string, query string, pass ...string) {
	_, err := db.Exec(query)
	if err != nil {
		log.Fatalln(err)
	} else if out != "" && (code == 0 || sqlCatchWarning().code != code) {
		log.Println(out)
	}
}

func sqlRenderSchema(database string, name string, schema string) string {
	return "CREATE TABLE IF NOT EXISTS " + database + "." + name + " (" + schema + ")"
}

func sqlCompareTable(database string, name string, schema string) string {
	if err := db.QueryRow("SELECT * FROM information_schema.tables WHERE table_schema = " + database + " AND table_name = " + name + " LIMIT 1").Err(); err != nil {
		return sqlRenderSchema(database, name, schema)
	}

	tmpName := name + "_compare_test"
	_, err := db.Exec("CREATE TABLE " + database + "." + tmpName + " (" + schema + ")")
	if err != nil {
		log.Println(err)
		return sqlRenderSchema(database, name, schema)
	}
	defer func() {
		_, err := db.Exec("DROP TABLE " + database + "." + tmpName)
		if err != nil {
			log.Println(err)
		}
	}()

	row := db.QueryRow(`SELECT COUNT(1)>0 Comparison FROM
(
	SELECT
		column_name,ordinal_position,
		data_type,column_type,COUNT(1) rowcount
	FROM information_schema.columns
	WHERE table_schema=?
	AND table_name IN (?,?)
	GROUP BY
		column_name,ordinal_position,
		data_type,column_type
	HAVING COUNT(1)=1
) A`, database, name, tmpName)
	var diff bool
	if err := row.Scan(&diff); err != nil {
		log.Println(err)
		return sqlRenderSchema(database, name, schema)
	}

	if diff {
		_, err = db.Exec("RENAME TABLE " + database + "." + name + " TO " + database + "." + name + "_old")
		if err != nil {
			log.Println(err)
			return sqlRenderSchema(database, name, schema)
		}
		log.Printf("The schema of table %s.%s is outdated. Moving data to %s.%s.", database, name, database, name+"_old")
	}

	return sqlRenderSchema(database, name, schema)
}

func sqlUpdate() {
	log.Printf("updating database as %s", sqlGetUsername())

	// TODO proper warning handling
	// benbebot user
	sqlAssertWarn(1973, "added benbebot@localhost user", "CREATE USER IF NOT EXISTS 'benbebot'@'localhost' IDENTIFIED BY '"+tokens["sql"].Password+"'") // cant prepare a create user statement but we provide password so it should be fine

	// breadbag database
	sqlAssertWarn(1007, "added breadbag discord database", "CREATE DATABASE IF NOT EXISTS breadbag_discord")
	sqlAssertWarn(0000, "granted permissions for breadbag discord", "GRANT CREATE, ALTER, DROP, INSERT, UPDATE, DELETE, SELECT ON breadbag_discord.* TO 'benbebot'@'localhost'")

	sqlAssertWarn(1050, "added user voice time table", sqlCompareTable("breadbag_discord", "user_voice_time", "id BIGINT UNSIGNED, ms BIGINT UNSIGNED, PRIMARY KEY (id)"))
	sqlAssertWarn(1050, "added channel voice time table", sqlCompareTable("breadbag_discord", "channel_voice_time", "id BIGINT UNSIGNED, ms BIGINT UNSIGNED, PRIMARY KEY (id)"))

	// clips database
	sqlAssertWarn(1007, "added discord clips database", "CREATE DATABASE IF NOT EXISTS discord_clips")
	sqlAssertWarn(0000, "granted permissions for discord clips", "GRANT CREATE, ALTER, DROP, INSERT, UPDATE, DELETE, SELECT ON discord_clips.* TO 'benbebot'@'localhost'")

	clipsTable := "id INT UNSIGNED NOT NULL AUTO_INCREMENT, message BIGINT UNSIGNED, name VARCHAR(32), PRIMARY KEY (id)"
	sqlAssertWarn(1050, "added family guy clips table", sqlCompareTable("discord_clips", "family_guy", clipsTable))
	sqlAssertWarn(1050, "added young sheldon clips table", sqlCompareTable("discord_clips", "young_sheldon", clipsTable))

	// gnerb database
	sqlAssertWarn(1007, "added gnerb database", "CREATE DATABASE IF NOT EXISTS gnerb")
	sqlAssertWarn(0000, "granted permissions for gnerb", "GRANT CREATE, ALTER, DROP, INSERT, UPDATE, DELETE, SELECT ON gnerb.* TO 'benbebot'@'localhost'")

	sqlAssertWarn(1050, "added gnerb send delay table", sqlCompareTable("gnerb", "send_lost_time", "date DATE DEFAULT CURRENT_TIMESTAMP, lost INT, PRIMARY KEY (time)"))

	db.Close()
	log.Println("update complete")
}

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

func commandUpdate(reset bool) {
	var toUnmarshal map[string]map[discord.GuildID][]api.CreateCommandData
	toMarshal := make(map[string]map[discord.GuildID][]discord.Command)

	inData, err := os.ReadFile(commandFile)
	if err != nil {
		log.Fatalln(err)
	}
	err = json.Unmarshal(inData, &toUnmarshal)
	if err != nil {
		log.Fatalln(err)
	}

	for index, profile := range toUnmarshal {
		client := api.NewClient("Bot " + tokens[index].Password)
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
		log.Fatalln(err)
	}

	if _, err = os.Stat(commandFileOld); err != nil {
		err = os.Rename(commandFile, commandFileOld)
		if err != nil {
			log.Fatalln(err)
		}
	}
	err = os.WriteFile(commandFile, outData, 0777)
	if err != nil {
		log.Fatalln(err)
	}
}
