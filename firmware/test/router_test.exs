defmodule Planto.Web.RouterTest do
  use ExUnit.Case
  import Plug.Test

  alias Planto.Web.Router

  setup do
    Planto.Store.put(%{at: System.system_time(:millisecond), soil_percent: 42, errors: []})
    # Let the cast land before reading.
    _ = Planto.Store.latest()
    :ok
  end

  test "GET / serves the dashboard" do
    conn = Router.call(conn(:get, "/"), [])
    assert conn.status == 200
    assert conn.resp_body =~ "<title>Planto</title>"
  end

  test "GET /api/history returns recent readings as JSON" do
    conn = Router.call(conn(:get, "/api/history?hours=1"), [])
    assert conn.status == 200
    assert %{"readings" => [_ | _]} = JSON.decode!(conn.resp_body)
  end

  test "GET /api/latest returns the newest reading" do
    conn = Router.call(conn(:get, "/api/latest"), [])
    assert %{"reading" => %{"at" => _}} = JSON.decode!(conn.resp_body)
  end

  test "POST /api/sample takes a reading" do
    conn = Router.call(conn(:post, "/api/sample"), [])
    assert %{"reading" => %{"soil_percent" => _}} = JSON.decode!(conn.resp_body)
  end
end
