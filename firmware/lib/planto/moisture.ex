defmodule Planto.Moisture do
  @moduledoc """
  Turns the soil sensor's analog voltage into a 0–100 % moisture figure.

  The SSR1025 output rises as soil dries. `dry_mv` is the reading in dry
  air/soil and `wet_mv` the reading with the probe in water; both are set
  in `config :planto, :soil_calibration` and should be measured on your own
  sensor and soil.
  """

  @spec percent(integer(), integer(), integer()) :: integer()
  def percent(millivolts, dry_mv, wet_mv) when dry_mv > wet_mv do
    ((dry_mv - millivolts) * 100 / (dry_mv - wet_mv))
    |> round()
    |> max(0)
    |> min(100)
  end
end
