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
    Logger.info("Initializing DurableCounterState with counter: #{counter}")

    {:ok, Map.merge(state, %{session_counter: 0, started_at: DateTime.utc_now()}),
     permanent: true, auto_sync: true}
  end

  @impl true
  def load_state(_old_vsn, %{counter: counter} = _persisted_state), do: %{counter: counter}

  def incr() do
    Logger.debug("Finding server and calling increment on counter")

    {pid, _nil} = DurableServer.Supervisor.lookup(DurableCounterSup, topic())
    GenServer.call(pid, :increment)
  end

  def decr() do
    Logger.debug("Finding server and calling decrement on counter")

    {pid, _nil} = DurableServer.Supervisor.lookup(DurableCounterSup, topic())
    GenServer.call(pid, :decrement)
  end

  def current() do
    Logger.debug("Finding server and calling current counter")

    {pid, _nil} = DurableServer.Supervisor.lookup(DurableCounterSup, topic())
    GenServer.call(pid, :get_count)
  end

  # Implementation (runs on the GenServer process)

  @impl true
  def handle_call(:get_count, _from, state) do
    make_change(state)
  end

  @impl true
  def handle_call(:increment, _from, counter) do
    make_change(counter, +1)
  end

  @impl true
  def handle_call(:decrement, _from, counter) do
    make_change(counter, -1)
  end

  defp make_change(state) do
    PubSub.broadcast(DurableCounter.PubSub, topic(),
      counter: state.counter,
      session_counter: state.session_counter
    )

    {:reply, {state.counter, state.session_counter}, state}
  end

  defp make_change(state, change) do
    new_state = %{
      state
      | counter: state.counter + change,
        session_counter: state.session_counter + change
    }

    make_change(new_state)
  end
end
