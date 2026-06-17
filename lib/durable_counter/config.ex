defmodule DurableCounter.Config do
  @moduledoc """
  Reads configuration from a dotenv-style counter.conf file.

  Searches in order: `./counter.conf`, `/etc/counter.conf`.
  Falls back to environment variables if no file is found.

  The same file can be used as a systemd EnvironmentFile.
  """

  require Logger

  @config_paths ["./counter.conf", "/etc/counter.conf"]

  @keys [
    {"NODE_NAME", :node_name},
    {"ERLANG_COOKIE", :erlang_cookie},
    {"NODE_ROLE", :node_role},
    {"EKV_DATA_DIR", :ekv_data_dir},
    {"DNS_CLUSTER_QUERY", :dns_cluster_query}
  ]

  @doc """
  Loads configuration from the first counter.conf found, merged with env vars
  and Application config.

  Priority: counter.conf > env vars > Application.get_env(:durable_counter, key).
  Returns a map with string keys.
  """
  @spec load() :: %{String.t() => String.t()}
  def load do
    file_config =
      case find_config_file() do
        {:ok, path} ->
          Logger.info("Loading config from #{path}")
          parse_file(path)

        :none ->
          Logger.debug("No counter.conf found, using environment variables")
          %{}
      end

    Map.new(@keys, fn {env_key, app_key} ->
      value =
        Map.get(file_config, env_key) ||
          System.get_env(env_key) ||
          app_env_as_string(app_key)

      {env_key, value}
    end)
  end

  defp app_env_as_string(key) do
    case Application.get_env(:durable_counter, key) do
      nil -> nil
      val when is_binary(val) -> val
      val when is_atom(val) -> Atom.to_string(val)
      val -> to_string(val)
    end
  end

  @doc """
  Returns the role as an atom (`:primary` or `:replica`). Defaults to `:primary`.
  """
  @spec role(%{String.t() => String.t() | nil}) :: :primary | :replica
  def role(config) do
    case config["NODE_ROLE"] do
      "replica" -> :replica
      _ -> :primary
    end
  end

  @doc """
  Returns the node name as an atom, or `nil` if not configured.
  """
  @spec node_name(%{String.t() => String.t() | nil}) :: atom() | nil
  def node_name(config) do
    case config["NODE_NAME"] do
      nil -> nil
      "" -> nil
      name -> String.to_atom(name)
    end
  end

  @doc """
  Returns the Erlang cookie as an atom, or `nil` if not configured.
  """
  @spec cookie(%{String.t() => String.t() | nil}) :: atom() | nil
  def cookie(config) do
    case config["ERLANG_COOKIE"] do
      nil -> nil
      "" -> nil
      cookie -> String.to_atom(cookie)
    end
  end

  @doc """
  Returns the primary host string, or `nil` if not configured.
  """
  @spec primary_host(%{String.t() => String.t() | nil}) :: String.t() | nil
  def primary_host(config), do: config["DNS_CLUSTER_QUERY"]

  @doc """
  Returns the EKV data directory, with a default fallback.
  """
  @spec ekv_data_dir(%{String.t() => String.t() | nil}) :: String.t()
  def ekv_data_dir(config) do
    config["EKV_DATA_DIR"] || "./data/ekv_store"
  end

  defp find_config_file do
    Enum.find_value(@config_paths, :none, fn path ->
      if File.exists?(path), do: {:ok, path}
    end)
  end

  @doc false
  @spec parse_file(String.t()) :: %{String.t() => String.t()}
  def parse_file(path) do
    path
    |> File.read!()
    |> parse_string()
  end

  @doc false
  @spec parse_string(String.t()) :: %{String.t() => String.t()}
  def parse_string(content) do
    content
    |> String.split("\n")
    |> Enum.reduce(%{}, fn line, acc ->
      line = String.trim(line)

      case line do
        "" -> acc
        "#" <> _ -> acc
        _ -> parse_line(line, acc)
      end
    end)
  end

  defp parse_line(line, acc) do
    case String.split(line, "=", parts: 2) do
      [key, value] ->
        Map.put(acc, String.trim(key), String.trim(value))

      _ ->
        acc
    end
  end
end
