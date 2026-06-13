defmodule DurableCounterWeb.CounterLiveTest do
  use DurableCounterWeb.ConnCase, async: false

  import Phoenix.LiveViewTest

  alias DurableCounter.DurableCounterState

  @topic DurableCounterState.topic()

  setup do
    case DurableServer.Supervisor.lookup(DurableCounterSup, @topic) do
      {pid, _meta} ->
        DurableServer.Supervisor.terminate_and_delete_child(DurableCounterSup, pid)
        ref = Process.monitor(pid)
        assert_receive {:DOWN, ^ref, :process, ^pid, _reason}, 5_000

      nil ->
        :ok
    end

    :ok
  end

  describe "multiple sessions see same state" do
    test "two LiveViews see the same counter after increment", %{conn: conn} do
      {:ok, view1, html1} = live(conn, "/counter")
      assert html1 =~ "Counter: 0"
      assert html1 =~ "Session Counter: 0"

      {:ok, view2, _html2} = live(build_conn(), "/counter")

      view1 |> element("button", "+") |> render_click()
      assert render(view1) =~ "Counter: 1"
      assert render(view2) =~ "Counter: 1"
    end

    test "decrement is visible across sessions", %{conn: conn} do
      {:ok, view1, _html} = live(conn, "/counter")
      {:ok, view2, _html} = live(build_conn(), "/counter")

      view1 |> element("button", "+") |> render_click()
      view2 |> element("button", "-") |> render_click()

      assert render(view1) =~ "Counter: 0"
      assert render(view2) =~ "Counter: 0"
    end

    test "session counter is the same across all browser sessions", %{conn: conn} do
      {:ok, view1, _html} = live(conn, "/counter")
      {:ok, view2, _html} = live(build_conn(), "/counter")

      view1 |> element("button", "+") |> render_click()
      view1 |> element("button", "+") |> render_click()

      assert render(view1) =~ "Session Counter: 2"
      assert render(view2) =~ "Session Counter: 2"
    end
  end
end
