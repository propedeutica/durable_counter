defmodule DurableCounter.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    ekv_config = [
      name: :durable_ekv,
      data_dir: "./data/ekv_store",
      cluster_size: 1,
      shards: 2
    ]

    children = [
      DurableCounterWeb.Telemetry,
      {DNSCluster, query: Application.get_env(:durable_counter, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: DurableCounter.PubSub},
      # Start a worker by calling: DurableCounter.Worker.start_link(arg)
      # {DurableCounter.Worker, arg},
      # Start to serve requests, typically the last entry
      DurableCounterWeb.Endpoint,
      # Start the App State,
      {EKV, ekv_config},
      {DurableServer.Supervisor,
       name: DurableCounterSup,
       prefix: "counter/",
       backend: {DurableServer.Backends.EKVStore, [name: ekv_config[:name], start: false]}}
    ]

    # See https://elixir.hexdocs.pm/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: DurableCounter.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    DurableCounterWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
