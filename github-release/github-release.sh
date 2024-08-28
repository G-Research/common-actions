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
handle_error() {
    ERROR_OUTPUT="$1"
    exit_message=$(echo "$ERROR_OUTPUT" | jq -r --exit-status 'if .errors | length == 1 then .errors[0].code else null end')
    if [ "$exit_message" = "already_exists" ] ; then
        HANDLE_OUTPUT="Did not create GitHub release because it already exists at this version."
    else
        echo "Unexpected error output from curl: $(cat curl_output.json)"
        echo "JQ output: $(exit_message)"
        exit 2
    fi
}

CURL_URL="https://api.github.com/repos/$GITHUB_REPOSITORY/releases"

echo "curl to: $CURL_URL"

if [ "$DRY_RUN" != 1 ] ; then
    if curl --fail-with-body -L -X POST -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GITHUB_TOKEN" -H "X-GitHub-Api-Version: 2022-11-28" "$CURL_URL" -d "$curl_body" > curl_output.json; then
        echo "Curl succeeded."
    else
        handle_error "$(cat curl_output.json)"
        echo "$HANDLE_OUTPUT"
    fi
fi
