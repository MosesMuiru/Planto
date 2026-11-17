defmodule Planto.Sensors.Hardware do
  @moduledoc """
  Real sensors on the Planto HAT / breadboard.

  * Soil AO  -> ADS1115 AIN0 on I2C bus `i2c-1` (GPIO2/3), address 0x48
  * Soil DO  -> GPIO27, LOW = wetter than the potentiometer threshold
  * Soil VCC -> switched by GPIO17 (LOW = on) through the P-FET on the HAT
  * DHT11    -> GPIO4, decoded from GPIO edge timestamps (see Planto.DHT11)

  Any part that is missing (for example no ADS1115 on a breadboard) is
  reported in `errors` and its fields are nil; the rest keep working.
  """

  require Logger
  alias Planto.{ADS1115, DHT11, Moisture}

  # Time for the sensor board to power up before reading.
  @power_settle_ms 50

  def init(_opts) do
    cfg = Application.get_all_env(:planto)
    pins = Keyword.fetch!(cfg, :pins)

    state = %{
      i2c: open(:i2c, fn -> Circuits.I2C.open(cfg[:i2c_bus]) end),
      adc_address: cfg[:adc_address],
      soil_power:
        open(:soil_power, fn ->
          Circuits.GPIO.open(pins[:soil_power], :output, initial_value: 1)
        end),
      soil_do: open(:soil_do, fn -> Circuits.GPIO.open(pins[:soil_do], :input) end),
      dht_spec: pins[:dht],
      dht: open(:dht, fn -> Circuits.GPIO.open(pins[:dht], :input) end),
      calibration: cfg[:soil_calibration]
    }

    {:ok, state}
  end

  def read(state) do
    set_soil_power(state, 0)
    Process.sleep(@power_settle_ms)
    soil_wet = read_soil_do(state)
    soil_mv = read_soil_mv(state)
    set_soil_power(state, 1)

    dht = read_dht(state, 3)

    errors =
      []
      |> add_error(soil_mv, "soil analog (ADS1115)")
      |> add_error(soil_wet, "soil digital (GPIO27)")
      |> add_error(dht, "DHT11")

    soil_mv = ok_or_nil(soil_mv)
    dht = ok_or_nil(dht) || %{}

    fields = %{
      soil_mv: soil_mv,
      soil_percent:
        soil_mv &&
          Moisture.percent(soil_mv, state.calibration[:dry_mv], state.calibration[:wet_mv]),
      soil_wet: ok_or_nil(soil_wet),
      temperature_c: dht[:temperature_c],
      humidity: dht[:humidity],
      errors: errors
    }

    {fields, state}
  end

  defp open(what, fun) do
    case fun.() do
      {:ok, ref} ->
        ref

      {:error, reason} ->
        Logger.error("could not open #{what}: #{inspect(reason)}")
        nil
    end
  end

  defp set_soil_power(%{soil_power: nil}, _value), do: :ok
  defp set_soil_power(%{soil_power: gpio}, value), do: Circuits.GPIO.write(gpio, value)

  defp read_soil_do(%{soil_do: nil}), do: {:error, :gpio_unavailable}
  defp read_soil_do(%{soil_do: gpio}), do: {:ok, Circuits.GPIO.read(gpio) == 0}

  defp read_soil_mv(%{i2c: nil}), do: {:error, :i2c_unavailable}

  defp read_soil_mv(%{i2c: bus, adc_address: address}),
    do: ADS1115.read_millivolts(bus, address, 0)

  defp read_dht(%{dht: nil}, _tries), do: {:error, :gpio_unavailable}

  defp read_dht(state, tries) do
    case DHT11.read(state.dht, state.dht_spec) do
      {:ok, _} = ok ->
        ok

      {:error, _} when tries > 1 ->
        # The DHT11 needs at least a second between measurements.
        Process.sleep(1_200)
        read_dht(state, tries - 1)

      error ->
        error
    end
  end

  defp ok_or_nil({:ok, value}), do: value
  defp ok_or_nil(_), do: nil

  defp add_error(errors, {:ok, _}, _label), do: errors
  defp add_error(errors, {:error, reason}, label), do: errors ++ ["#{label}: #{inspect(reason)}"]
end
