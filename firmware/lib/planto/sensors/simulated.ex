defmodule Planto.Sensors.Simulated do
  @moduledoc """
  Fake readings for running the dashboard on a laptop (`iex -S mix`).
  The soil slowly dries out and gets "watered" every so often; temperature
  and humidity drift in a daily-looking wave.
  """

  alias Planto.Moisture

  def init(_opts), do: {:ok, %{soil_mv: 1400}}

  def read(%{soil_mv: mv} = state) do
    cal = Application.fetch_env!(:planto, :soil_calibration)
    mv = if mv > 2700, do: 1100, else: mv + :rand.uniform(40)
    t = System.system_time(:second) / 600

    fields = %{
      soil_mv: mv,
      soil_percent: Moisture.percent(mv, cal[:dry_mv], cal[:wet_mv]),
      soil_wet: mv < 2200,
      temperature_c: Float.round(24 + 3 * :math.sin(t) + :rand.uniform() - 0.5, 1),
      humidity: Float.round(55 - 10 * :math.sin(t) + :rand.uniform(), 1),
      errors: []
    }

    {fields, %{state | soil_mv: mv}}
  end
end
