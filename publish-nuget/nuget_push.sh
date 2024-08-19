#!/bin/sh

# Expects an env var NUGET_API_KEY.
# Provides step results of "version=${version number pushed}" and "result={published|skipped}".
# Succeeds with exit code 0 if a package already exists at the given version in NuGet, and sets `result=skipped`.
# Fails with exit code 1 if we fail to publish for any other reason.

NUGET_SOURCE="https://api.nuget.org/v3/index.json"
cd "$PACKAGE_DIR" || exit 1
SOURCE_NUPKG=$(find . -maxdepth 1 -type f -name '*.nupkg')

# Get the last three dot-separated chunks of the nupkg file path; interpret this as a version number.
PACKAGE_VERSION=$(basename "$SOURCE_NUPKG" | rev | cut -d '.' -f 2-4 | rev)

echo "version=$PACKAGE_VERSION" >> "$GITHUB_OUTPUT"

nuget_output=$(mktemp)

if ! "$DOTNET_EXE" nuget push "$SOURCE_NUPKG" --api-key "$NUGET_API_KEY" --source "$NUGET_SOURCE" > "$nuget_output" ; then
    cat "$nuget_output"
    if grep 'already exists and cannot be modified' "$nuget_output" ; then
        echo "result=skipped" >> "$GITHUB_OUTPUT"
        exit 0
    else
        echo "Unexpected failure to upload"
        exit 1
    fi
fi

cat "$nuget_output"

echo "result=published" >> "$GITHUB_OUTPUT"
