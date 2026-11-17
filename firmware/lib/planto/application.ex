defmodule Planto.Application do
  # See https://elixir.hexdocs.pm/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    cfg = Application.get_all_env(:planto)

    children = [
      {Planto.Store, max_entries: cfg[:history_size]},
      {Planto.Sampler, backend: cfg[:sensor_backend], interval_ms: cfg[:sample_interval_ms]},
      {Bandit, plug: Planto.Web.Router, port: cfg[:web_port]}
    ]

    opts = [strategy: :one_for_one, name: Planto.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
