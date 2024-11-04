# this script automatically generates a version.go with git hashes in it

file="internal/generated/version/version.go"

echo -n "package version;const(Hash=\"" > $file
git rev-parse HEAD | tr -d '\n' >> $file
echo -n "\";HashShort=\"" >> $file
git rev-parse --short HEAD | tr -d '\n' >> $file
echo -n "\")" >> $file