defmodule Planto do
  @moduledoc """
  Planto smart planter firmware.

  Reads the soil moisture sensor (through an ADS1115) and a DHT11 every
  30 seconds and serves a dashboard at http://planto.local.

  From an IEx session on the device:

      Planto.latest()      # newest reading
      Planto.read_now()    # take a reading immediately
  """

  defdelegate latest, to: Planto.Store
  defdelegate read_now, to: Planto.Sampler, as: :sample_now
end
