#!/bin/sh

DRAFT=${DRAFT:-false}
PRERELEASE=${PRERELEASE:-false}
GENERATE_RELEASE_NOTES=${GENERATE_RELEASE_NOTES:-false}

# target_commitish is empty by default to indicate the repo default branch
curl_body='{"tag_name":"'"$TAG"'","target_commitish":"'"$TARGET_COMMITISH"'","name":"'"$TAG"'","draft":'"$DRAFT"',"prerelease": '"$PRERELEASE"',"generate_release_notes":'"$GENERATE_RELEASE_NOTES"'}'

echo "cURL body: $curl_body"

# Some errors are expected. For example, to make our pipelines idempotent, we gracefully do nothing
# when a release already exists with the given name.
HANDLE_OUTPUT=''
RELEASE_ID=''
handle_error() {
    ERROR_OUTPUT="$1"
    exit_message=$(echo "$ERROR_OUTPUT" | jq -r --exit-status 'if .errors | length == 1 then .errors[0].code else null end')
    if [ "$exit_message" = "already_exists" ] ; then
        HANDLE_OUTPUT="Did not create GitHub release because it already exists at this version."
        RELEASE_ID="$(curl -L -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28" -H "Bearer $GITHUB_TOKEN" "https://api.github.com/repos/$GITHUB_REPOSITORY/releases/tags/$TAG" | jq --raw-output --exit-status '.id')"
    else
        echo "Unexpected error output from curl: $(cat curl_output.json)"
        echo "JQ output: $(exit_message)"
        exit 2
    fi
}

CURL_URL="https://api.github.com/repos/$GITHUB_REPOSITORY/releases"

echo "Creating release with curl: $CURL_URL"

if [ "$DRY_RUN" != 1 ] ; then
    if curl --fail-with-body -L -X POST -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GITHUB_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" "$CURL_URL" -d "$curl_body" > curl_output.json; then
        echo "Curl succeeded."
        RELEASE_ID="$(jq --raw-output --exit-status '.id' curl_output.json)"
    else
        handle_error "$(cat curl_output.json)"
        echo "$HANDLE_OUTPUT"
    fi
fi

# Upload the binary, if specified.
add_file_to_release() {
    RELEASE_NAME="$(basename "$1")"
    CURL_URL="https://uploads.github.com/repos/$GITHUB_REPOSITORY/releases/$RELEASE_ID/assets?name=$RELEASE_NAME"
    echo "Posting binary contents of $1 to $CURL_URL"

    curl -X POST \
        -H "Authorization: Bearer $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github+json" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        -H "Content-Type: application/octet-stream" \
        "$CURL_URL" \
        --data-binary "@$1"
}

if [ -n "$BINARY_CONTENTS" ] ; then
    echo "$BINARY_CONTENTS" | while IFS= read -r line; do
        add_file_to_release "$line"
    done
fi
