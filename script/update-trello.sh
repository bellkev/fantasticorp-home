#!/bin/bash

set -e
set -o pipefail

# requires $TRELLO_KEY $TRELLO_TOKEN $CIRCLE_PR_NUMBER

pr_list="$TRELLO_PR_LIST"
deployed_list="$TRELLO_DEPLOY_LIST"

# args: $method $resource $value
api_call() {
    method="$1"
    resource="$2"
    value="$3"
    curl -sS -X "$method" "https://api.trello.com/1/$resource?key=$TRELLO_KEY&token=$TRELLO_TOKEN&value=$value"
}

if pr_cards=($(api_call GET "lists/$pr_list/cards" | jq -e -r '.[].id')); then
    for card in "${pr_cards[@]}"; do
        for url in "$(api_call GET "cards/$card/attachments" | jq -e -r '.[].url')"; do
            # if https://github.com/bellkev/fantasticorp-home/123 = Merge pull request #123 from ...
            if [[ $(grep -oP '\d+$' <<<"$url") = $(git log --format=%B -n 1 HEAD |grep -oP '#\K\d+') ]]; then
                api_call PUT "cards/$card/idList" "$deployed_list"
            fi
        done
    done
fi
