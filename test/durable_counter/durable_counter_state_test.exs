defmodule DurableCounter.DurableCounterStateTest do
  use ExUnit.Case, async: false

  alias DurableCounter.DurableCounterState

  @topic DurableCounterState.topic()

  defp terminate_counter do
    case DurableServer.Supervisor.lookup(DurableCounterSup, @topic) do
      {pid, _meta} ->
        DurableServer.Supervisor.terminate_child_permanent(DurableCounterSup, pid)
        ref = Process.monitor(pid)
        assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 5_000

      nil ->
        :ok
    end
  end

  defp delete_counter do
    case DurableServer.Supervisor.lookup(DurableCounterSup, @topic) do
      {pid, _meta} ->
        DurableServer.Supervisor.terminate_and_delete_child(DurableCounterSup, pid)
        ref = Process.monitor(pid)
        assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 5_000

      nil ->
        :ok
    end
  end

  defp start_counter do
    DurableServer.Supervisor.ensure_started_child(
      DurableCounterSup,
      {DurableCounterState, key: @topic, initial_state: %{counter: 0}}
    )
  end

  describe "initial state without existing data" do
    setup do
      delete_counter()
      :ok
    end

    test "starts with counter 0 and session_counter 0" do
      start_counter()
      assert %{counter: 0, session_counter: 0} = DurableCounterState.current()
    end
  end

  describe "persistence across process restarts" do
    setup do
      delete_counter()
      :ok
    end

    test "counter persists but session_counter resets on process restart" do
      start_counter()

      DurableCounterState.incr()
      DurableCounterState.incr()
      DurableCounterState.incr()
      assert %{counter: 3, session_counter: 3} = DurableCounterState.current()

      terminate_counter()
      start_counter()

      assert %{counter: 3, session_counter: 0} = DurableCounterState.current()

      DurableCounterState.incr()
      assert %{counter: 4, session_counter: 1} = DurableCounterState.current()
      DurableCounterState.decr()
      assert %{counter: 3, session_counter: 0} = DurableCounterState.current()
    end
  end
end
