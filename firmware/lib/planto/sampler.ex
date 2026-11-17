defmodule Planto.Sampler do
  @moduledoc """
  Reads all sensors every `interval_ms` and saves the result in `Planto.Store`.

  The sensor backend is chosen in config: `Planto.Sensors.Hardware` on the
  Pi, `Planto.Sensors.Simulated` on the host for development.
  """

  use GenServer
  require Logger

  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  @doc "Take a reading now (also used by the dashboard's refresh button)."
  def sample_now, do: GenServer.call(__MODULE__, :sample_now, 15_000)

  @impl GenServer
  def init(opts) do
    backend = Keyword.fetch!(opts, :backend)
    interval = Keyword.get(opts, :interval_ms, 30_000)
    {:ok, backend_state} = backend.init(opts)
    send(self(), :sample)
    {:ok, %{backend: backend, backend_state: backend_state, interval: interval}}
  end

  @impl GenServer
  def handle_info(:sample, state) do
    {_reading, state} = sample(state)
    Process.send_after(self(), :sample, state.interval)
    {:noreply, state}
  end

  # Late GPIO edge messages from a DHT11 read; nothing to do.
  def handle_info({:circuits_gpio, _spec, _timestamp, _value}, state), do: {:noreply, state}

  @impl GenServer
  def handle_call(:sample_now, _from, state) do
    {reading, state} = sample(state)
    {:reply, reading, state}
  end

  defp sample(state) do
    {fields, backend_state} = state.backend.read(state.backend_state)

    reading = Map.merge(%{at: System.system_time(:millisecond), errors: []}, fields)

    if reading.errors != [], do: Logger.warning("sensor errors: #{inspect(reading.errors)}")

    Planto.Store.put(reading)
    {reading, %{state | backend_state: backend_state}}
  end
end
