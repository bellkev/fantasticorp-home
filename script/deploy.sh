#!/usr/bin/env bash

set -e
set -u
set -o pipefail

# more bash-friendly output for jq
_jq() {
    jq --raw-output --exit-status "$@"
}

# args: $tag
# stdout: task def json
task_definition() {
    tag="$1"
    cat <<EOF
[
    {
        "name": "uwsgi",
        "image": "/fantasticorp-home-uwsgi:$tag",
        "essential": true,
        "memory": 200,
        "cpu": 10
    },
    {
        "name": "nginx",
        "links": [
            "uwsgi"
        ],
        "image": "/fantasticorp-home-nginx:$tag",
        "portMappings": [
            {
                "containerPort": 8000,
                "hostPort": 80
            }
        ],
        "cpu": 10,
        "memory": 200,
        "essential": true
    }
]
EOF
}

# args: $family $task_def
# stdout: task definition revision ARN
register_definition() {
    family="$1"
    task_def="$2"
    if revision="$(aws ecs register-task-definition --container-definitions "$task_def" --family "$family" | _jq '.taskDefinition.taskDefinitionArn')"; then
        echo "Created task def revision: $revision" 1>&2
    else
        echo "Failed to register task definition" 1>&2
        return 1
    fi
    echo "$revision"
}

# args: $service
deploy() {
    service="$1"
    family="fantasticorp-home"
    cluster="fantasticorp-home"
    tag="${CIRCLE_SHA1}"
    task_def="$(task_definition "$tag")"
    revision="$(register_definition "$family" "$task_def")"
    if [[ $(aws ecs update-service --cluster "$cluster" --service "$service" --task-definition "$revision" | _jq '.service.taskDefinition') != $revision ]]; then
        echo "Error updating service." 1>&2
        return 1
    fi
}

case "$1" in
    staging) deploy "fantasticorp-home-staging" ;;
    prod) deploy "fantasticorp-home" ;;
esac
