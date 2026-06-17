defmodule DurableCounter.ClusterTest do
  use ExUnit.Case, async: false

  @peer_opts %{connection: :standard, host: ~c"127.0.0.1", longnames: true}

  defp start_peer(name) do
    cookie = Node.get_cookie() |> Atom.to_charlist()

    {:ok, pid, node} =
      :peer.start(Map.merge(@peer_opts, %{name: name, args: [~c"-setcookie", cookie]}))

    :erpc.call(node, :code, :add_paths, [:code.get_path()])
    {:ok, _} = :erpc.call(node, Application, :ensure_all_started, [:elixir])
    {:ok, _} = :erpc.call(node, Application, :ensure_all_started, [:logger])

    {pid, node}
  end

  defp stop_peer(pid) do
    :peer.stop(pid)
  end

  describe "primary safety check" do
    test "raises when another primary responds on the same host" do
      cookie = Node.get_cookie() |> Atom.to_charlist()

      {:ok, peer, _node} =
        :peer.start(Map.merge(@peer_opts, %{name: :primary_node, args: [~c"-setcookie", cookie]}))

      on_exit(fn -> stop_peer(peer) end)

      config = %{
        "DNS_CLUSTER_QUERY" => "127.0.0.1",
        "NODE_NAME" => "other@127.0.0.1",
        "NODE_ROLE" => "primary",
        "ERLANG_COOKIE" => nil,
        "EKV_DATA_DIR" => nil
      }

      assert_raise RuntimeError, ~r/Another primary is already running/, fn ->
        DurableCounter.Application.verify_no_existing_primary(config)
      end
    end

    test "succeeds when no primary is running" do
      config = %{
        "DNS_CLUSTER_QUERY" => "192.0.2.99",
        "NODE_NAME" => "other@127.0.0.1",
        "NODE_ROLE" => "primary",
        "ERLANG_COOKIE" => nil,
        "EKV_DATA_DIR" => nil
      }

      assert :ok == DurableCounter.Application.verify_no_existing_primary(config)
    end
  end

  describe "supervision tree shape" do
    test "primary role includes Endpoint, EKV, and DurableServer" do
      config = %{
        "NODE_NAME" => nil,
        "ERLANG_COOKIE" => nil,
        "NODE_ROLE" => "primary",
        "EKV_DATA_DIR" => "./data/ekv_store",
        "DNS_CLUSTER_QUERY" => nil
      }

      children = DurableCounter.Application.children_for_role(config)
      child_modules = Enum.map(children, &child_module/1)

      assert DurableCounterWeb.Endpoint in child_modules
      assert EKV in child_modules
      assert DurableServer.Supervisor in child_modules
    end

    test "replica role includes EKV and NodeConnector but not Endpoint" do
      config = %{
        "NODE_NAME" => nil,
        "ERLANG_COOKIE" => nil,
        "NODE_ROLE" => "replica",
        "EKV_DATA_DIR" => "./data/ekv_replica",
        "DNS_CLUSTER_QUERY" => "10.0.0.100"
      }

      children = DurableCounter.Application.children_for_role(config)
      child_modules = Enum.map(children, &child_module/1)

      assert EKV in child_modules
      assert DurableCounter.NodeConnector in child_modules
      refute DurableCounterWeb.Endpoint in child_modules
      refute DurableServer.Supervisor in child_modules
    end
  end

  describe "node connector" do
    test "connects to a peer node" do
      {peer, peer_node} = start_peer(:connector_target)
      on_exit(fn -> stop_peer(peer) end)

      # Extract the host from the peer node name (e.g., connector_target@127.0.0.1)
      [_name, host] = peer_node |> Atom.to_string() |> String.split("@")

      {:ok, connector} =
        start_supervised(
          {DurableCounter.NodeConnector, primary_host: host, primary_node_name: peer_node}
        )

      # Give the connector time to connect
      :sys.get_state(connector)
      Process.sleep(100)

      assert peer_node in Node.list()
    end
  end

  defp child_module({module, _opts}) when is_atom(module), do: module
  defp child_module(%{start: {module, _, _}}), do: module
  defp child_module(module) when is_atom(module), do: module
end
