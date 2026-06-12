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

    {:ok, assign(socket, :counter, DurableCounterState.current())}
  end

  def handle_event("inc", _, socket) do
    {:noreply, assign(socket, :counter, DurableCounterState.incr())}
  end

  def handle_event("dec", _, socket) do
    {:noreply, assign(socket, :counter, DurableCounterState.decr())}
  end

  def handle_info({:counter, count}, socket) do
    {:noreply, assign(socket, :counter, count)}
  end

  def render(assigns) do
    ~H"""
    <div class="text-center">
      <h1 class="text-4xl font-bold text-center">Counter: {@counter}</h1>
      <.button phx-click="dec" class="w-20 bg-red-500 hover:bg-red-600">-</.button>
      <.button phx-click="inc" class="w-20 bg-green-500 hover:bg-green-600">+</.button>
      <h2 class="text-center pt-2 text-xl">Server: {Node.self()}</h2>
    </div>
    """
  end
end
