defmodule Planto.ADS1115 do
  @moduledoc """
  Minimal single-shot driver for the TI ADS1115 16-bit I2C ADC.

  Uses the ±4.096 V range (125 µV per count), which covers a 3.3 V sensor
  output, at 128 samples per second.
  """

  import Bitwise

  @reg_conversion 0x00
  @reg_config 0x01

  # ±4.096 V full scale / 32768 counts = 125 µV per count
  @microvolts_per_count 125

  @doc """
  Config register value that starts one conversion of `channel` (AINx vs GND).

      iex> Planto.ADS1115.config_word(0)
      0xC383
  """
  @spec config_word(0..3) :: non_neg_integer()
  def config_word(channel) when channel in 0..3 do
    start_conversion = 1 <<< 15
    mux_single_ended = (4 + channel) <<< 12
    pga_4_096v = 1 <<< 9
    single_shot = 1 <<< 8
    rate_128sps = 4 <<< 5
    comparator_off = 0b11

    start_conversion ||| mux_single_ended ||| pga_4_096v ||| single_shot ||| rate_128sps |||
      comparator_off
  end

  @doc """
  Convert a signed conversion result to millivolts.

      iex> Planto.ADS1115.counts_to_millivolts(26_400)
      3300
  """
  @spec counts_to_millivolts(integer()) :: integer()
  def counts_to_millivolts(counts), do: div(counts * @microvolts_per_count, 1000)

  @doc "Run one conversion on `channel` and return the input voltage in millivolts."
  @spec read_millivolts(Circuits.I2C.Bus.t(), 0..0x7F, 0..3) ::
          {:ok, integer()} | {:error, term()}
  def read_millivolts(bus, address, channel) do
    with :ok <- Circuits.I2C.write(bus, address, <<@reg_config, config_word(channel)::16>>),
         :ok <- wait_for_conversion(bus, address, 25),
         {:ok, <<counts::signed-16>>} <-
           Circuits.I2C.write_read(bus, address, <<@reg_conversion>>, 2) do
      {:ok, counts_to_millivolts(counts)}
    end
  end

  # Bit 15 of the config register reads 1 once the conversion has finished.
  defp wait_for_conversion(_bus, _address, 0), do: {:error, :conversion_timeout}

  defp wait_for_conversion(bus, address, tries) do
    Process.sleep(2)

    case Circuits.I2C.write_read(bus, address, <<@reg_config>>, 2) do
      {:ok, <<1::1, _::15>>} -> :ok
      {:ok, _busy} -> wait_for_conversion(bus, address, tries - 1)
      error -> error
    end
  end
end
