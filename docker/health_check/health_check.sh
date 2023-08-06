#!/bin/bash

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <subgraph_url> <subgraph_name>"
    exit 1
fi

subgraph_url=$1
subgraph_name=$2
timestamp=$(date +"%Y-%m-%d %H:%M:%S")

get_subgraph_data() {
    local query="{ \"query\": \"{ indexingStatusesForSubgraphName(subgraphName: \\\"$subgraph_name\\\") { synced health chains { network chainHeadBlock { number } latestBlock { number } } } }\" }"

    response=$(curl -s -X POST -H 'Content-Type: application/json' -d "$query" "$subgraph_url")
    if [[ $? -ne 0 || -z $response ]]; then
        echo "Failed to fetch data from the subgraph API."
        exit 1
    fi

    indexing_data=$(echo "$response" | jq -r '.data.indexingStatusesForSubgraphName | length')
    network=$(echo "$response" | jq -r '.data.indexingStatusesForSubgraphName[0].chains[0].network')
    chainheadblock_number=$(echo "$response" | jq -r '.data.indexingStatusesForSubgraphName[0].chains[0].chainHeadBlock.number')
    latest_block_number=$(echo "$response" | jq -r '.data.indexingStatusesForSubgraphName[0].chains[0].latestBlock.number')


    if (( indexing_data == 0 )); then
        echo "$timestamp Error: healthcheck - Failed to retrieve complete data from the subgraph API. $response"
        exit 1
    fi
}

compare_block_numbers() {
    local chainhead_block=$1
    local latest_block=$2
    local network=$3

    if (( chainhead_block > latest_block + 100 )); then
        echo "$timestamp INFO: healthcheck - $network chainhead block is AHEAD of superfluid $network latest block."
        exit 1
    else
        echo "$timestamp INFO: healthcheck - $network chainhead block is IN SYNC with superfluid $network latest block."
    fi
}

main() {
    get_subgraph_data

    compare_block_numbers "$chainheadblock_number" "$latest_block_number" "$network"
}

main
