#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'shared/collector'
require 'net/http'
require 'json'
require 'uri'
require 'resolv'
require 'socket'

COLLECT_INTERVAL    = ENV.fetch('NETWORK_COLLECT_INTERVAL', '60').to_i
SPEEDTEST_INTERVAL  = ENV.fetch('NETWORK_SPEEDTEST_INTERVAL', '3600').to_i
PING_TARGETS        = ENV.fetch('NETWORK_PING_TARGETS', '8.8.8.8,1.1.1.1').split(',').map(&:strip)
DNS_TEST_HOST       = ENV.fetch('NETWORK_DNS_TEST_HOST', 'google.com')
HTTP_TEST_URL       = ENV.fetch('NETWORK_HTTP_TEST_URL', 'https://www.google.com')

@last_speedtest = Time.at(0)

def measure_ping(host)
  output = `ping -c 3 -W 5 #{host} 2>&1`
  return nil unless $?.success?

  # Parse avg from "min/avg/max/stddev = 1.234/5.678/9.012/1.234 ms"
  if output =~ %r{= [\d.]+/([\d.]+)/[\d.]+/[\d.]+ ms}
    $1.to_f
  end
rescue => e
  warn "Ping #{host} failed: #{e.message}"
  nil
end

def measure_dns(host)
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  Resolv::DNS.open { |dns| dns.getaddress(host) }
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start
  (elapsed * 1000).round(2)
rescue => e
  warn "DNS lookup #{host} failed: #{e.message}"
  nil
end

def measure_http(url)
  uri = URI(url)
  start = Process.clock_gettime(Process::CLOCK_MONOTONIC)

  http = Net::HTTP.new(uri.host, uri.port)
  http.use_ssl = uri.scheme == 'https'
  http.open_timeout = 10
  http.read_timeout = 10

  response = http.request(Net::HTTP::Get.new(uri))
  elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start

  { time_ms: (elapsed * 1000).round(2), status: response.code.to_i }
rescue => e
  warn "HTTP #{url} failed: #{e.message}"
  nil
end

SPEEDTEST_SERVER = ENV.fetch('NETWORK_SPEEDTEST_SERVER', '').strip

def run_speedtest
  cmd = 'speedtest --format=json --accept-license --accept-gdpr'
  cmd += " --server-id=#{SPEEDTEST_SERVER}" unless SPEEDTEST_SERVER.empty?

  output = `#{cmd} 2>&1`
  return nil unless $?.success?

  # The first run prints a license notice before the JSON — find the JSON line.
  json_line = output.lines.find { |line| line.strip.start_with?('{') }
  return nil unless json_line

  JSON.parse(json_line)
rescue => e
  warn "Speedtest failed: #{e.message}"
  nil
end

def build_points(ping_results, dns_ms, http_result)
  timestamp = Time.now.to_i
  points = []

  ping_results.each do |host, ms|
    next unless ms

    points << InfluxDB2::Point.new(name: 'network_ping')
                              .add_tag('host', host)
                              .add_field('latency_ms', ms)
                              .time(timestamp, InfluxDB2::WritePrecision::SECOND)
  end

  if dns_ms
    points << InfluxDB2::Point.new(name: 'network_dns')
                              .add_tag('host', DNS_TEST_HOST)
                              .add_field('resolve_ms', dns_ms)
                              .time(timestamp, InfluxDB2::WritePrecision::SECOND)
  end

  if http_result
    points << InfluxDB2::Point.new(name: 'network_http')
                              .add_tag('url', HTTP_TEST_URL)
                              .add_field('response_ms', http_result[:time_ms])
                              .add_field('status_code', http_result[:status])
                              .time(timestamp, InfluxDB2::WritePrecision::SECOND)
  end

  points
end

def build_speedtest_point(data)
  return nil unless data

  InfluxDB2::Point.new(name: 'network_speedtest')
                  .add_field('download_mbps', (data.dig('download', 'bandwidth').to_f * 8 / 1_000_000).round(2))
                  .add_field('upload_mbps', (data.dig('upload', 'bandwidth').to_f * 8 / 1_000_000).round(2))
                  .add_field('ping_ms', data.dig('ping', 'latency').to_f)
                  .add_field('jitter_ms', data.dig('ping', 'jitter').to_f)
                  .add_field('server', data.dig('server', 'name').to_s)
                  .time(Time.now.to_i, InfluxDB2::WritePrecision::SECOND)
end

# ---------------------------------------------------------------------------

Collector.log "Starting network collector | interval=#{COLLECT_INTERVAL}s speedtest_interval=#{SPEEDTEST_INTERVAL}s"
Collector.log "Ping targets: #{PING_TARGETS.join(', ')}"

Collector.run(interval: COLLECT_INTERVAL) do |write_api|
  ping_results = PING_TARGETS.map { |host| [host, measure_ping(host)] }
  dns_ms       = measure_dns(DNS_TEST_HOST)
  http_result  = measure_http(HTTP_TEST_URL)
  points       = build_points(ping_results, dns_ms, http_result)

  if points.any?
    write_api.write(data: points)
    avg_ping = ping_results.map(&:last).compact.first&.round(1)
    Collector.log "Wrote #{points.size} points | ping=#{avg_ping}ms dns=#{dns_ms}ms http=#{http_result&.dig(:time_ms)}ms"
  else
    Collector.log 'No data this cycle'
  end

  # Speed test on a separate interval
  if Time.now - @last_speedtest >= SPEEDTEST_INTERVAL
    Collector.log 'Running speed test...'
    speedtest_data  = run_speedtest
    speedtest_point = build_speedtest_point(speedtest_data)

    if speedtest_point
      write_api.write(data: speedtest_point)
      down = (speedtest_data.dig('download', 'bandwidth').to_f * 8 / 1_000_000).round(1)
      up   = (speedtest_data.dig('upload', 'bandwidth').to_f * 8 / 1_000_000).round(1)
      Collector.log "Speedtest: #{down} Mbps down / #{up} Mbps up"
    else
      Collector.log 'Speedtest: no data'
    end

    @last_speedtest = Time.now
  end
end
