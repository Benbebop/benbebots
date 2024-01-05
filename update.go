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

func sqlUpdate() {
	row := db.QueryRow("SELECT USER()")
	var username string
	if err := row.Scan(&username); err == nil {
		log.Printf("updating database as %s", username)
	}

	// TODO proper warning handling
	// TODO compare table type
	// benbebot user
	_, err := db.Exec("CREATE USER IF NOT EXISTS 'benbebot'@'localhost' IDENTIFIED BY '" + tokens["sql"].Password + "'") // cant prepare a create user statement but we provide password so it should be fine
	if err != nil {
		log.Fatalln(err)
	} else if sqlCatchWarning().code != 1973 {
		log.Println("added benbebot@localhost user")
	}

	// breadbag database
	_, err = db.Exec("CREATE DATABASE IF NOT EXISTS breadbagDiscord")
	if err != nil {
		log.Fatalln(err)
	} else if sqlCatchWarning().code != 1007 {
		log.Println("added breadbagDiscord database")
	}
	_, err = db.Exec("GRANT CREATE, ALTER, DROP, INSERT, UPDATE, DELETE, SELECT ON breadbagDiscord.* TO 'benbebot'@'localhost'")
	if err != nil {
		log.Fatalln(err)
	}
	log.Println("granted permissions for breadbagDiscord")
	_, err = db.Exec("USE breadbagDiscord")
	if err != nil {
		log.Fatalln(err)
	}

	_, err = db.Exec("CREATE TABLE IF NOT EXISTS vcHours (name CHAR(60), hours DOUBLE UNSIGNED)")
	if err != nil {
		log.Fatalln(err)
	} else if sqlCatchWarning().code != 1050 {
		log.Println("added voice chat hours table")
	}

	// clips database
	_, err = db.Exec("CREATE DATABASE IF NOT EXISTS discordClips")
	if err != nil {
		log.Fatalln(err)
	} else if sqlCatchWarning().code != 1007 {
		log.Println("added discordClips database")
	}
	_, err = db.Exec("GRANT CREATE, ALTER, DROP, INSERT, UPDATE, DELETE, SELECT ON discordClips.* TO 'benbebot'@'localhost'")
	if err != nil {
		log.Fatalln(err)
	}
	log.Println("granted permissions for discordClips")
	_, err = db.Exec("USE discordClips")
	if err != nil {
		log.Fatalln(err)
	}

	_, err = db.Exec("CREATE TABLE IF NOT EXISTS familyguy (id INT UNSIGNED NOT NULL AUTO_INCREMENT, upload VARCHAR(255), PRIMARY KEY (id))")
	if err != nil {
		log.Fatalln(err)
	} else if sqlCatchWarning().code != 1050 {
		log.Println("added family guy clips table")
	}
	_, err = db.Exec("CREATE TABLE IF NOT EXISTS youngsheldon (id INT UNSIGNED NOT NULL AUTO_INCREMENT, upload VARCHAR(255), PRIMARY KEY (id))")
	if err != nil {
		log.Fatalln(err)
	} else if sqlCatchWarning().code != 1050 {
		log.Println("added young sheldon clips table")
	}

	db.Close()
	log.Println("update complete")
}

func commandUpdate() {

}
