#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'shared/collector'
require 'net/http'
require 'json'
require 'uri'

ENPHASE_HOST     = ENV.fetch('SOLAR_ENPHASE_HOST')
ENPHASE_TOKEN    = ENV.fetch('SOLAR_ENPHASE_TOKEN')
COLLECT_INTERVAL = ENV.fetch('SOLAR_COLLECT_INTERVAL', '60').to_i

def fetch_production
  uri = URI("https://#{ENPHASE_HOST}/production.json")
  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = true
  http.verify_mode = OpenSSL::SSL::VERIFY_NONE
  http.open_timeout = 10
  http.read_timeout = 10

  request = Net::HTTP::Get.new(uri)
  request['Authorization'] = "Bearer #{ENPHASE_TOKEN}"

  response = http.request(request)
  raise "HTTP #{response.code}" unless response.code == '200'

  JSON.parse(response.body)
rescue => e
  warn "Failed to fetch production.json: #{e.message}"
  nil
end

def build_points(data)
  return [] unless data

  timestamp = Time.now.to_i
  points = []

  production = data['production']&.find { |p| p['type'] == 'eim' && p['measurementType'] == 'production' }
  production ||= data['production']&.find { |p| p['type'] == 'inverters' }

  if production
    points << InfluxDB2::Point.new(name: 'solar_production')
                              .add_field('watts_now', production['wNow'].to_f)
                              .add_field('wh_today', production['whToday'].to_f)
                              .add_field('wh_last_7_days', production['whLastSevenDays'].to_f)
                              .add_field('wh_lifetime', production['whLifetime'].to_f)
                              .add_field('active_inverters', production['activeCount'].to_i)
                              .time(timestamp, InfluxDB2::WritePrecision::SECOND)
  end

  total = data['consumption']&.find { |c| c['measurementType'] == 'total-consumption' }
  net   = data['consumption']&.find { |c| c['measurementType'] == 'net-consumption' }

  if total
    points << InfluxDB2::Point.new(name: 'solar_consumption')
                              .add_tag('type', 'total')
                              .add_field('watts_now', total['wNow'].to_f)
                              .add_field('wh_today', total['whToday'].to_f)
                              .add_field('wh_last_7_days', total['whLastSevenDays'].to_f)
                              .add_field('wh_lifetime', total['whLifetime'].to_f)
                              .time(timestamp, InfluxDB2::WritePrecision::SECOND)
  end

  if net
    # Negative = importing from grid, positive = exporting to grid
    points << InfluxDB2::Point.new(name: 'solar_consumption')
                              .add_tag('type', 'net')
                              .add_field('watts_now', net['wNow'].to_f)
                              .time(timestamp, InfluxDB2::WritePrecision::SECOND)
  end

  points
end

# ---------------------------------------------------------------------------

Collector.log "Starting solar collector | host=#{ENPHASE_HOST} interval=#{COLLECT_INTERVAL}s"

Collector.run(interval: COLLECT_INTERVAL) do |write_api|
  data   = fetch_production
  points = build_points(data)

  if points.any?
    write_api.write(data: points)
    watts = data['production']&.find { |p| p['type'] == 'eim' }&.dig('wNow')&.round
    Collector.log "Wrote #{points.size} points | #{watts}W production"
  else
    Collector.log 'No data this cycle'
  end
end
