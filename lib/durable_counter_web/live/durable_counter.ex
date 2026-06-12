defmodule DurableCounterWeb.Counter do
  use DurableCounterWeb, :live_view

  alias DurableCounterWeb.Endpoint
  alias DurableCounter.DurableCounterState

  @topic DurableCounterState.topic()

  def mount(_session, _params, socket) do
    DurableServer.Supervisor.ensure_started_child(
      DurableCounterSup,
      {DurableCounterState, key: @topic, initial_state: %{counter: 0}}
    )

    if connected?(socket) do
      # subscribe to the channel
      Endpoint.subscribe(@topic)
    end

    {counter, session_counter} = DurableCounterState.current()
    {:ok, assign(socket, counter: counter, session_counter: session_counter)}
  end

  @spec handle_event(<<_::24>>, any(), map()) :: {:noreply, map()}
  def handle_event("inc", _, socket) do
    {counter, session_counter} = DurableCounterState.incr()
    {:noreply, assign(socket, counter: counter, session_counter: session_counter)}
  end

  def handle_event("dec", _, socket) do
    {counter, session_counter} = DurableCounterState.decr()
    {:noreply, assign(socket, counter: counter, session_counter: session_counter)}
  end

  def handle_info([counter: counter, session_counter: session_counter], socket) do
    {:noreply, assign(socket, counter: counter, session_counter: session_counter)}
  end

  def render(assigns) do
    ~H"""
    <div class="text-center">
      <h1 class="text-4xl font-bold text-center">Counter: {@counter}</h1>
      <h2 class="text-xl">Session Counter: {@session_counter}</h2>
      <.button phx-click="dec" class="w-20 bg-red-500 hover:bg-red-600">-</.button>
      <.button phx-click="inc" class="w-20 bg-green-500 hover:bg-green-600">+</.button>
      <h2 class="text-center pt-2 text-xl">Server: {Node.self()}</h2>
    </div>
    """
  end
end
