#!/bin/sh

echo "$PACKAGE_NAME"
echo "$PACKAGE_VERSION"
dest_dir=$(mktemp --directory)
dest="$dest_dir/$PACKAGE_NAME.$PACKAGE_VERSION.nupkg"
while ! curl -L --fail -o "$dest" "https://www.nuget.org/api/v2/package/$PACKAGE_NAME/$PACKAGE_VERSION" ; do
  sleep 10;
done

echo "downloaded_nupkg=$dest" >> "$GITHUB_OUTPUT"
