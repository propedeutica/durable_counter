#!/usr/bin/env bash

#    "NODE_ROLE", :primary, :replica
#    "NODE_NAME, :node_name
#    "ERLANG_COOKIE", :erlang_cookie,
#    "EKV_DATA_DIR", :ekv_data_dir
#    "DNS_CLUSTER_QUERY", :dns_cluster_query
NODE_NAME=primary_node PORT=4002 EKV_DATA_DIR=./data/replica_ekv_store NODE_ROLE=primary DNS_CLUSTER_QUERY="${DNS_CLUSTER_QUERY:-127.0.0.1}" iex --name primary_node@127.0.0.1 -S mix phx.server "$@"