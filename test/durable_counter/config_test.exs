defmodule DurableCounter.ConfigTest do
  use ExUnit.Case, async: true

  alias DurableCounter.Config

  describe "parse_string/1" do
    test "parses key=value pairs" do
      content = """
      NODE_NAME=durable_counter@10.0.0.100
      NODE_ROLE=primary
      EKV_DATA_DIR=/var/lib/ekv
      """

      assert %{
               "NODE_NAME" => "durable_counter@10.0.0.100",
               "NODE_ROLE" => "primary",
               "EKV_DATA_DIR" => "/var/lib/ekv"
             } = Config.parse_string(content)
    end

    test "skips blank lines and comments" do
      content = """
      # This is a comment
      NODE_ROLE=replica

      # Another comment
      DNS_CLUSTER_QUERY=10.0.0.100
      """

      result = Config.parse_string(content)
      assert result["NODE_ROLE"] == "replica"
      assert result["DNS_CLUSTER_QUERY"] == "10.0.0.100"
      assert map_size(result) == 2
    end

    test "splits on first = only, preserving values with =" do
      content = "ERLANG_COOKIE=secret=with=equals"
      assert %{"ERLANG_COOKIE" => "secret=with=equals"} = Config.parse_string(content)
    end

    test "trims whitespace from keys and values" do
      content = "  NODE_ROLE  =  replica  "
      assert %{"NODE_ROLE" => "replica"} = Config.parse_string(content)
    end
  end

  describe "role/1" do
    test "returns :primary by default" do
      assert :primary == Config.role(%{"NODE_ROLE" => nil})
      assert :primary == Config.role(%{"NODE_ROLE" => "primary"})
      assert :primary == Config.role(%{"NODE_ROLE" => "anything"})
    end

    test "returns :replica when configured" do
      assert :replica == Config.role(%{"NODE_ROLE" => "replica"})
    end
  end

  describe "node_name/1" do
    test "returns atom from string" do
      assert :"counter@10.0.0.1" == Config.node_name(%{"NODE_NAME" => "counter@10.0.0.1"})
    end

    test "returns nil when not set" do
      assert nil == Config.node_name(%{"NODE_NAME" => nil})
      assert nil == Config.node_name(%{"NODE_NAME" => ""})
    end
  end

  describe "cookie/1" do
    test "returns atom from string" do
      assert :my_secret == Config.cookie(%{"ERLANG_COOKIE" => "my_secret"})
    end

    test "returns nil when not set" do
      assert nil == Config.cookie(%{"ERLANG_COOKIE" => nil})
    end
  end

  describe "ekv_data_dir/1" do
    test "returns configured value" do
      assert "/custom/path" == Config.ekv_data_dir(%{"EKV_DATA_DIR" => "/custom/path"})
    end

    test "returns default when not set" do
      assert "./data/ekv_store" == Config.ekv_data_dir(%{"EKV_DATA_DIR" => nil})
    end
  end
end
