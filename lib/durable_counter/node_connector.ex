defmodule DurableCounter.NodeConnector do
  @moduledoc """
  Connects a replica node to the primary via Erlang distribution.

  Retries the connection periodically if the primary is not available at startup.
  Monitors the connection and logs if the primary disconnects.
  """

  use GenServer
  require Logger

  @retry_interval_ms 5_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(opts) do
    primary_host = Keyword.get(opts, :primary_host)
    primary_node = Keyword.get(opts, :primary_node_name)

    primary_node =
      cond do
        primary_node != nil -> primary_node
        primary_host != nil -> :"primary_node@#{primary_host}"
        true -> nil
      end

    if primary_node == nil do
      Logger.warning("No PRIMARY_HOST configured, NodeConnector will not connect")
      {:ok, %{primary_node: nil}}
    else
      {:ok, %{primary_node: primary_node}, {:continue, :connect}}
    end
  end

  @impl true
  def handle_continue(:connect, state) do
    attempt_connect(state)
    {:noreply, state}
  end

  @impl true
  def handle_info(:retry_connect, state) do
    attempt_connect(state)
    {:noreply, state}
  end

  def handle_info({:nodedown, node}, state) do
    Logger.warning("Primary node disconnected: #{node}")
    schedule_retry()
    {:noreply, state}
  end

  def handle_info(_msg, state) do
    {:noreply, state}
  end

  defp attempt_connect(%{primary_node: primary_node}) do
    case Node.connect(primary_node) do
      true ->
        Logger.info("Connected to primary: #{primary_node}")
        Node.monitor(primary_node, true)

      false ->
        Logger.warning(
          "Could not connect to primary: #{primary_node}, retrying in #{@retry_interval_ms}ms"
        )

        schedule_retry()

      :ignored ->
        Logger.warning("Node not alive, cannot connect to #{primary_node}")
    end
  end

  defp schedule_retry do
    Process.send_after(self(), :retry_connect, @retry_interval_ms)
  end
end
