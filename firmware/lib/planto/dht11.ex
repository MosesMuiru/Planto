defmodule Planto.DHT11 do
  @moduledoc """
  Reads a DHT11 temperature/humidity sensor on one GPIO (GPIO4 on Planto).

  The Nerves Pi 5 system does not ship the kernel `dht11` driver, so the
  protocol is decoded here from GPIO edge events. Linux timestamps every edge
  in the interrupt handler, so the pulse widths are accurate even though
  Elixir handles the messages a little later.

  Protocol: the Pi pulls the line low for ≥18 ms and releases it. The sensor
  answers with an 80 µs low / 80 µs high preamble and then 40 bits. Each bit
  is ~50 µs low followed by a high pulse of ~27 µs (0) or ~70 µs (1). The
  last 40 high pulses are the data, so a missed preamble does not matter.
  """

  import Bitwise

  # High pulses longer than this are 1 bits.
  @one_threshold_ns 48_000
  @start_low_ms 20
  @listen_ms 25

  @type result :: %{temperature_c: float(), humidity: float()}

  @doc "Trigger one measurement on an open GPIO handle and decode it."
  @spec read(Circuits.GPIO.Handle.t(), String.t()) :: {:ok, result()} | {:error, term()}
  def read(gpio, spec) do
    flush(spec)

    with :ok <- Circuits.GPIO.set_direction(gpio, :output),
         :ok <- Circuits.GPIO.write(gpio, 0),
         :ok <- Process.sleep(@start_low_ms),
         :ok <- Circuits.GPIO.set_direction(gpio, :input),
         :ok <- Circuits.GPIO.set_interrupts(gpio, :both) do
      events = collect(spec, System.monotonic_time(:millisecond) + @listen_ms, [])
      Circuits.GPIO.set_interrupts(gpio, :none)
      decode(events)
    end
  end

  @doc """
  Decode a list of `{timestamp_ns, value}` edge events into a reading.

  Exposed for testing.
  """
  @spec decode([{integer(), 0 | 1}]) :: {:ok, result()} | {:error, term()}
  def decode(events) do
    widths = high_pulse_widths(events)

    if length(widths) < 40 do
      {:error, {:too_few_pulses, length(widths)}}
    else
      bits = widths |> Enum.take(-40) |> Enum.map(&if(&1 > @one_threshold_ns, do: 1, else: 0))
      <<h_int, h_dec, t_int, t_dec, checksum>> = for bit <- bits, into: <<>>, do: <<bit::1>>

      if (h_int + h_dec + t_int + t_dec &&& 0xFF) == checksum do
        temperature = t_int + (t_dec &&& 0x7F) / 10
        temperature = if (t_dec &&& 0x80) != 0, do: -temperature, else: temperature
        {:ok, %{temperature_c: temperature, humidity: h_int + h_dec / 10}}
      else
        {:error, :checksum}
      end
    end
  end

  # Width of every high pulse: a rising edge followed by a falling edge.
  defp high_pulse_widths(events) do
    events
    |> Enum.chunk_every(2, 1, :discard)
    |> Enum.flat_map(fn
      [{t_rise, 1}, {t_fall, 0}] -> [t_fall - t_rise]
      _ -> []
    end)
  end

  defp collect(spec, deadline, acc) do
    timeout = max(deadline - System.monotonic_time(:millisecond), 0)

    receive do
      {:circuits_gpio, ^spec, timestamp, value} ->
        collect(spec, deadline, [{timestamp, value} | acc])
    after
      timeout -> Enum.reverse(acc)
    end
  end

  defp flush(spec) do
    receive do
      {:circuits_gpio, ^spec, _, _} -> flush(spec)
    after
      0 -> :ok
    end
  end
end
