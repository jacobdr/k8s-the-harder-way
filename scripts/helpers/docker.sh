#!/usr/bin/env bash

function docker_get_bridge_container_ips() {
    docker network inspect bridge | jq '.[0].Containers[] | {Name,IPv4Address}'
}

export -f docker_get_bridge_container_ips
