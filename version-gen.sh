# this script automatically generates a version.go with git hashes in it

echo -n "package main;const(versionHash=\"" > version.go
git rev-parse HEAD | tr -d '\n' >> version.go
echo -n "\";versionHashShort=\"" >> version.go
git rev-parse --short HEAD | tr -d '\n' >> version.go
echo -n "\")" >> version.go