defmodule Planto.Store do
  @moduledoc """
  Keeps the most recent sensor readings in memory (a fixed-size ring).

  With the default 30 s sample interval and 2880 entries this is 24 hours
  of history. History is lost on reboot.
  """

  use GenServer

  @type reading :: %{
          at: integer(),
          soil_mv: integer() | nil,
          soil_percent: integer() | nil,
          soil_wet: boolean() | nil,
          temperature_c: float() | nil,
          humidity: float() | nil,
          errors: [String.t()]
        }

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: Keyword.get(opts, :name, __MODULE__))
  end

  @spec put(GenServer.server(), reading()) :: :ok
  def put(server \\ __MODULE__, reading), do: GenServer.cast(server, {:put, reading})

  @spec latest(GenServer.server()) :: reading() | nil
  def latest(server \\ __MODULE__), do: GenServer.call(server, :latest)

  @doc "All stored readings, oldest first."
  @spec history(GenServer.server()) :: [reading()]
  def history(server \\ __MODULE__), do: GenServer.call(server, {:history, nil})

  @doc "Readings from the last `window_ms` milliseconds, oldest first."
  @spec recent(GenServer.server(), non_neg_integer()) :: [reading()]
  def recent(server \\ __MODULE__, window_ms), do: GenServer.call(server, {:history, window_ms})

  @impl GenServer
  def init(opts) do
    {:ok, %{max: Keyword.get(opts, :max_entries, 2880), size: 0, queue: :queue.new()}}
  end

  @impl GenServer
  def handle_cast({:put, reading}, %{size: size, max: max} = state) when size >= max do
    {_, queue} = :queue.out(state.queue)
    {:noreply, %{state | queue: :queue.in(reading, queue)}}
  end

  def handle_cast({:put, reading}, state) do
    {:noreply, %{state | queue: :queue.in(reading, state.queue), size: state.size + 1}}
  end

  @impl GenServer
  def handle_call(:latest, _from, state) do
    latest =
      case :queue.peek_r(state.queue) do
        {:value, reading} -> reading
        :empty -> nil
      end

    {:reply, latest, state}
  end

  def handle_call({:history, nil}, _from, state), do: {:reply, :queue.to_list(state.queue), state}

  def handle_call({:history, since_ms}, _from, state) do
    cutoff = System.system_time(:millisecond) - since_ms
    {:reply, Enum.filter(:queue.to_list(state.queue), &(&1.at >= cutoff)), state}
  end
end
