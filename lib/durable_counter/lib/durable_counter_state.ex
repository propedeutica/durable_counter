defmodule DurableCounter.DurableCounterState do
  @moduledoc """
    Durable Counter State implements Durable Server. The counter is stored in a durable key-value store,
    so the server can recover from crashes without losing the counter state.
  """
  use DurableServer, vsn: 1
  alias Phoenix.PubSub
  require Logger

  def topic do
    "counter"
  end

  # Dump state filters the information that we want to maintain in the durable store.
  @impl true
  def dump_state(state), do: %{counter: state.counter}

  @impl true
  def init(%{counter: counter} = state) do
    Logger.info("Counter initialized", counter: counter)

    {:ok, Map.merge(state, %{session_counter: 0, started_at: DateTime.utc_now()}),
     permanent: true, auto_sync: true}
  end

  @impl true
  def load_state(_old_vsn, %{counter: counter} = _persisted_state), do: %{counter: counter}

  def incr do
    {pid, _meta} = DurableServer.Supervisor.lookup(DurableCounterSup, topic())
    GenServer.call(pid, :increment)
  end

  def decr do
    {pid, _meta} = DurableServer.Supervisor.lookup(DurableCounterSup, topic())
    GenServer.call(pid, :decrement)
  end

  def current do
    {pid, _meta} = DurableServer.Supervisor.lookup(DurableCounterSup, topic())
    GenServer.call(pid, :get_count)
  end

  @impl true
  def handle_call(:get_count, _from, state) do
    {:reply, state, state}
  end

  @impl true
  def handle_call(:increment, _from, state) do
    apply_change(state, +1)
  end

  @impl true
  def handle_call(:decrement, _from, state) do
    apply_change(state, -1)
  end

  defp apply_change(state, delta) do
    new_state = %{
      state
      | counter: state.counter + delta,
        session_counter: state.session_counter + delta
    }

    Logger.debug("Counter updated",
      counter: new_state.counter,
      session_counter: new_state.session_counter,
      delta: delta
    )

    broadcast_state(new_state)
    {:reply, new_state, new_state}
  end

  defp broadcast_state(state) do
    PubSub.broadcast(DurableCounter.PubSub, topic(), {:counter_state, state})
  end
end
