#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'shared/collector'
require 'net/http'
require 'json'
require 'uri'

LATITUDE         = ENV.fetch('WEATHER_LATITUDE')
LONGITUDE        = ENV.fetch('WEATHER_LONGITUDE')
COLLECT_INTERVAL = ENV.fetch('WEATHER_COLLECT_INTERVAL', '300').to_i

CURRENT_PARAMS = %w[
  temperature_2m
  relative_humidity_2m
  apparent_temperature
  precipitation
  weather_code
  cloud_cover
  wind_speed_10m
  wind_direction_10m
  wind_gusts_10m
  shortwave_radiation
  direct_radiation
  diffuse_radiation
  sunshine_duration
].freeze

def fetch_weather
  params = URI.encode_www_form(
    latitude: LATITUDE,
    longitude: LONGITUDE,
    current: CURRENT_PARAMS.join(','),
    timezone: 'auto'
  )
  uri = URI("https://api.open-meteo.com/v1/forecast?#{params}")

  response = Net::HTTP.get_response(uri)
  raise "HTTP #{response.code}" unless response.code == '200'

  JSON.parse(response.body)
rescue => e
  warn "Failed to fetch weather: #{e.message}"
  nil
end

def build_point(data)
  return nil unless data

  current = data['current']
  return nil unless current

  InfluxDB2::Point.new(name: 'weather')
                  .add_field('temperature_c', current['temperature_2m'].to_f)
                  .add_field('relative_humidity', current['relative_humidity_2m'].to_f)
                  .add_field('apparent_temperature_c', current['apparent_temperature'].to_f)
                  .add_field('precipitation_mm', current['precipitation'].to_f)
                  .add_field('weather_code', current['weather_code'].to_i)
                  .add_field('cloud_cover_pct', current['cloud_cover'].to_f)
                  .add_field('wind_speed_kmh', current['wind_speed_10m'].to_f)
                  .add_field('wind_direction_deg', current['wind_direction_10m'].to_f)
                  .add_field('wind_gusts_kmh', current['wind_gusts_10m'].to_f)
                  .add_field('shortwave_radiation_wm2', current['shortwave_radiation'].to_f)
                  .add_field('direct_radiation_wm2', current['direct_radiation'].to_f)
                  .add_field('diffuse_radiation_wm2', current['diffuse_radiation'].to_f)
                  .add_field('sunshine_duration_s', current['sunshine_duration'].to_f)
                  .time(Time.now.to_i, InfluxDB2::WritePrecision::SECOND)
end

# ---------------------------------------------------------------------------

Collector.log "Starting weather collector | lat=#{LATITUDE} lon=#{LONGITUDE} interval=#{COLLECT_INTERVAL}s"

Collector.run(interval: COLLECT_INTERVAL) do |write_api|
  data  = fetch_weather
  point = build_point(data)

  if point
    write_api.write(data: point)
    temp  = data.dig('current', 'temperature_2m')
    cloud = data.dig('current', 'cloud_cover')
    Collector.log "Wrote weather point | #{temp}°C, #{cloud}% cloud cover"
  else
    Collector.log 'No data this cycle'
  end
end
