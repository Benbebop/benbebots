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
	} else if out != "" && sqlCatchWarning().code != code {
		log.Println(out)
	}
}

func sqlUpdate() {
	log.Printf("updating database as %s", sqlGetUsername())

	// TODO proper warning handling
	// TODO compare table type
	// benbebot user
	sqlAssertWarn(1973, "added benbebot@localhost user", "CREATE USER IF NOT EXISTS 'benbebot'@'localhost' IDENTIFIED BY '"+tokens["sql"].Password+"'") // cant prepare a create user statement but we provide password so it should be fine

	// breadbag database
	sqlAssertWarn(1007, "added breadbagdiscord database", "CREATE DATABASE IF NOT EXISTS breadbagdiscord")
	sqlAssertWarn(0000, "granted permissions for breadbagdiscord", "GRANT CREATE, ALTER, DROP, INSERT, UPDATE, DELETE, SELECT ON breadbagdiscord.* TO 'benbebot'@'localhost'")
	sqlAssertWarn(0000, "", "USE breadbagdiscord")

	sqlAssertWarn(1050, "added voice chat hours table", "CREATE TABLE IF NOT EXISTS vcHours (name CHAR(60), hours DOUBLE UNSIGNED)")

	// clips database
	sqlAssertWarn(1007, "added discordclips database", "CREATE DATABASE IF NOT EXISTS discordclips")
	sqlAssertWarn(0000, "granted permissions for discordclips", "GRANT CREATE, ALTER, DROP, INSERT, UPDATE, DELETE, SELECT ON discordclips.* TO 'benbebot'@'localhost'")
	sqlAssertWarn(0000, "", "USE discordclips")

	sqlAssertWarn(1050, "added family guy clips table", "CREATE TABLE IF NOT EXISTS familyguy (id INT UNSIGNED NOT NULL AUTO_INCREMENT, upload VARCHAR(255), PRIMARY KEY (id))")
	sqlAssertWarn(1050, "added young sheldon clips table", "CREATE TABLE IF NOT EXISTS youngsheldon (id INT UNSIGNED NOT NULL AUTO_INCREMENT, upload VARCHAR(255), PRIMARY KEY (id))")

	db.Close()
	log.Println("update complete")
}

func commandUpdate() {

}
