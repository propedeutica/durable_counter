defmodule DurableCounterWeb.PageController do
  use DurableCounterWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
