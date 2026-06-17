defmodule DurableCounter.ClusterHelper do
  @moduledoc false

  def start_ekv(ekv_config) do
    Process.flag(:trap_exit, true)
    {:ok, pid} = EKV.Supervisor.start_link(ekv_config)

    receive do
      {:EXIT, _, _} -> :ok
    after
      500 -> :ok
    end

    {:ok, pid}
  end
end
