defmodule PlantoTest do
  use ExUnit.Case, async: true

  doctest Planto.ADS1115

  describe "ADS1115" do
    test "config word selects the right input for each channel" do
      import Bitwise

      for ch <- 0..3 do
        mux = Planto.ADS1115.config_word(ch) >>> 12 &&& 0b111
        assert mux == 4 + ch
      end
    end

    test "negative counts convert to negative millivolts" do
      assert Planto.ADS1115.counts_to_millivolts(-8000) == -1000
    end
  end

  describe "Moisture.percent/3" do
    test "maps dry to 0 % and wet to 100 %" do
      assert Planto.Moisture.percent(3200, 3200, 900) == 0
      assert Planto.Moisture.percent(900, 3200, 900) == 100
      assert Planto.Moisture.percent(2050, 3200, 900) == 50
    end

    test "clamps readings outside the calibration range" do
      assert Planto.Moisture.percent(3300, 3200, 900) == 0
      assert Planto.Moisture.percent(400, 3200, 900) == 100
    end
  end

  describe "DHT11.decode/1" do
    # Build the edge events a DHT11 sends for these 5 bytes, starting with
    # the 80 µs low / 80 µs high preamble.
    defp dht_events(bytes) do
      bits = for <<bit::1 <- :binary.list_to_bin(bytes)>>, do: bit

      {events, t} =
        Enum.reduce(bits, {[{0, 0}, {80_000, 1}], 160_000}, fn bit, {acc, t} ->
          high = if bit == 1, do: 70_000, else: 27_000
          {acc ++ [{t, 0}, {t + 50_000, 1}], t + 50_000 + high}
        end)

      events ++ [{t, 0}, {t + 50_000, 1}]
    end

    test "decodes humidity and temperature" do
      bytes = [61, 0, 23, 4]
      events = dht_events(bytes ++ [Enum.sum(bytes)])
      assert {:ok, %{humidity: 61.0, temperature_c: 23.4}} = Planto.DHT11.decode(events)
    end

    test "still decodes when the preamble edges were missed" do
      bytes = [45, 0, 19, 0]
      events = bytes |> Kernel.++([Enum.sum(bytes)]) |> dht_events() |> Enum.drop(3)
      assert {:ok, %{humidity: 45.0, temperature_c: 19.0}} = Planto.DHT11.decode(events)
    end

    test "rejects a bad checksum" do
      assert {:error, :checksum} = Planto.DHT11.decode(dht_events([61, 0, 23, 4, 0]))
    end

    test "reports too few pulses" do
      assert {:error, {:too_few_pulses, _}} = Planto.DHT11.decode([{0, 1}, {30_000, 0}])
    end
  end

  describe "Store" do
    test "keeps only the newest entries" do
      store = start_supervised!({Planto.Store, name: :test_store, max_entries: 3})

      for i <- 1..5, do: Planto.Store.put(store, %{at: i, value: i})

      assert Enum.map(Planto.Store.history(store), & &1.value) == [3, 4, 5]
      assert Planto.Store.latest(store).value == 5
    end
  end
end
