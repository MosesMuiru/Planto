# This file is responsible for configuring your application and its
# dependencies.
#
# This configuration file is loaded before any dependency and is restricted to
# this project.
import Config

# Enable the Nerves integration with Mix
Application.start(:nerves_bootstrap)

# Customize non-Elixir parts of the firmware. See
# https://nerves.hexdocs.pm/advanced-configuration.html for details.

config :nerves, :firmware, rootfs_overlay: "rootfs_overlay"

# Set the SOURCE_DATE_EPOCH date for reproducible builds.
# See https://reproducible-builds.org/docs/source-date-epoch/ for more information

config :nerves, source_date_epoch: "1794924278"

# Planto sensor settings (shared by host and target).
config :planto,
  sample_interval_ms: 30_000,
  # 24 h of history at one reading every 30 s
  history_size: 2880,
  i2c_bus: "i2c-1",
  adc_address: 0x48,
  # true  = read the soil sensor's AO through an ADS1115 (moisture %)
  # false = digital only: the DO pin gives wet/dry (no ADC needed)
  soil_analog: false,
  pins: [soil_power: "GPIO17", soil_do: "GPIO27", dht: "GPIO4"],
  # Soil sensor calibration in millivolts at 3.3 V supply. Measure your own:
  # dry_mv = probe in dry soil/air, wet_mv = probe in water.
  soil_calibration: [dry_mv: 3200, wet_mv: 900]

if Mix.target() == :host do
  import_config "host.exs"
else
  import_config "target.exs"
end
