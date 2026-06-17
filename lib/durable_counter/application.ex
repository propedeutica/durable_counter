defmodule DurableCounter.Application do
  @moduledoc false

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    config = DurableCounter.Config.load()
    role = DurableCounter.Config.role(config)

    setup_distribution(config)

    if role == :primary do
      verify_no_existing_primary(config)
    end

    children = children_for_role(config)

    opts = [strategy: :one_for_one, name: DurableCounter.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @doc false
  def children_for_role(config) do
    role = DurableCounter.Config.role(config)
    common_children() ++ role_children(role, config)
  end

  @impl true
  def config_change(changed, _new, removed) do
    DurableCounterWeb.Endpoint.config_change(changed, removed)
    :ok
  end

  defp common_children do
    [
      DurableCounterWeb.Telemetry,
      {Phoenix.PubSub, name: DurableCounter.PubSub}
    ]
  end

  defp role_children(:primary, config) do
    ekv_config = ekv_config(config, :member)

    [
      {DNSCluster, query: Application.get_env(:durable_counter, :dns_cluster_query) || :ignore},
      DurableCounterWeb.Endpoint,
      {EKV, ekv_config},
      {DurableServer.Supervisor,
       name: DurableCounterSup,
       prefix: "counter/",
       backend: {DurableServer.Backends.EKVStore, [name: ekv_config[:name], start: false]}}
    ]
  end

  defp role_children(:replica, config) do
    ekv_config = ekv_config(config, :observer)

    [
      {EKV, ekv_config},
      {DurableCounter.NodeConnector, primary_host: DurableCounter.Config.primary_host(config)}
    ]
  end

  defp ekv_config(config, mode) do
    base = [
      name: :durable_ekv,
      data_dir: DurableCounter.Config.ekv_data_dir(config),
      cluster_size: 1,
      shards: 2
    ]

    case mode do
      :member -> base
      :observer -> base ++ [mode: :observer, region: "replica", region_routing: ["default"]]
    end
  end

  defp setup_distribution(config) do
    node_name = DurableCounter.Config.node_name(config)
    cookie = DurableCounter.Config.cookie(config)

    if node_name && Node.alive?() == false do
      case Node.start(node_name, :longnames) do
        {:ok, _pid} ->
          Logger.info("Started distribution as #{node_name}")

        {:error, reason} ->
          Logger.warning("Could not start distribution: #{inspect(reason)}")
      end
    end

    if cookie do
      Node.set_cookie(cookie)
    end
  end

  @doc false
  def verify_no_existing_primary(config) do
    primary_host = DurableCounter.Config.primary_host(config)

    with true <- primary_host != nil,
         true <- Node.alive?(),
         primary_node = :"primary_node@#{primary_host}",
         true <- primary_node != Node.self(),
         :pong <- :net_adm.ping(primary_node) do
      raise """
      Another primary is already running at #{primary_node}.
      Start this node in replica mode instead:

          NODE_ROLE=replica
      """
    else
      _ -> :ok
    end
  end
end
