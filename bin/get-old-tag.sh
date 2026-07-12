#!/bin/bash
# Requires: curl, jq, GNU date
REPO="immauss/openvas"
CUTOFF="$(date -u -d '6 months ago' '+%Y-%m-%dT%H:%M:%SZ')"

url="https://hub.docker.com/v2/repositories/${REPO}/tags?page_size=100"
tags_json="[]"

while [ -n "$url" ] && [ "$url" != "null" ]; do
    page="$(curl -fsSL "$url")"
    tags_json="$(jq -s '.[0] + .[1].results' <(printf '%s\n' "$tags_json") <(printf '%s\n' "$page"))"
    url="$(jq -r '.next' <<< "$page")"
done

OLD_VERSION="$(
    jq -r --arg cutoff "$CUTOFF" '
        map(select(.last_updated <= $cutoff))
        | map(select(.name != "latest" and .name != "beta"))
        | sort_by(.last_updated)
        | reverse
        | .[0].name // empty
    ' <<< "$tags_json"
)"

if [ -z "$OLD_VERSION" ]; then
    echo "ERROR: No Docker Hub tag found for ${REPO} that is at least 6 months old." >&2
    exit 1
fi

#echo "OLD_VERSION=${OLD_VERSION}"
echo $OLD_VERSION