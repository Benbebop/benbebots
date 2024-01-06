package main

import (
	"log"
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

	sqlAssertWarn(1050, "added family guy clips table", sqlCompareTable("discord_clips", "family_guy", "id INT UNSIGNED NOT NULL AUTO_INCREMENT, message BIGINT UNSIGNED, PRIMARY KEY (id)"))
	sqlAssertWarn(1050, "added young sheldon clips table", sqlCompareTable("discord_clips", "young_sheldon", "id INT UNSIGNED NOT NULL AUTO_INCREMENT, message BIGINT UNSIGNED, PRIMARY KEY (id)"))

	db.Close()
	log.Println("update complete")
}

func commandUpdate() {

}
