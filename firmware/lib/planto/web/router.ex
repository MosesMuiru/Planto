defmodule Planto.Web.Router do
  @moduledoc """
  Dashboard and JSON API.

  * `GET /`                      – dashboard page
  * `GET /api/latest`            – newest reading
  * `GET /api/history?hours=N`   – readings from the last N hours (default 24)
  * `POST /api/sample`           – take a reading now and return it
  """

  use Plug.Router

  plug(Plug.Static, at: "/static", from: {:planto, "priv/static"})
  plug(:match)
  plug(:dispatch)

  get "/" do
    conn
    |> put_resp_content_type("text/html")
    |> send_file(200, Application.app_dir(:planto, "priv/static/index.html"))
  end

  get "/api/latest" do
    json(conn, %{reading: Planto.Store.latest()})
  end

  get "/api/history" do
    conn = fetch_query_params(conn)

    hours =
      case Integer.parse(conn.query_params["hours"] || "24") do
        {h, _} when h > 0 and h <= 168 -> h
        _ -> 24
      end

    json(conn, %{
      readings: Planto.Store.recent(hours * 3_600_000),
      interval_ms: Application.get_env(:planto, :sample_interval_ms)
    })
  end

  post "/api/sample" do
    json(conn, %{reading: Planto.Sampler.sample_now()})
  end

  match _ do
    send_resp(conn, 404, "not found")
  end

  defp json(conn, data) do
    conn
    |> put_resp_content_type("application/json")
    |> put_resp_header("cache-control", "no-store")
    |> send_resp(200, JSON.encode!(data))
  end
end
