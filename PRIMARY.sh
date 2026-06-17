
#!/usr/bin/env bash

#    "NODE_ROLE", :primary (default), :replica
#    "NODE_NAME, :node_name
#    "ERLANG_COOKIE", :erlang_cookie,
#    "EKV_DATA_DIR", :ekv_data_dir
#    "DNS_CLUSTER_QUERY", :dns_cluster_query
NODE_NAME=primary_node EKV_DATA_DIR=./data/primary_ekv_store NODE_ROLE=primary DNS_CLUSTER_QUERY="${DNS_CLUSTER_QUERY:-127.0.0.1}" iex --name primary_node@127.0.0.1 -S mix phx.server "$@"
