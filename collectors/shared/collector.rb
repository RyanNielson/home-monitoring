# frozen_string_literal: true

require 'influxdb-client'

$stdout.sync = true
$stderr.sync = true

module Collector
  INFLUXDB_URL    = ENV.fetch('INFLUXDB_URL', 'http://influxdb:8086')
  INFLUXDB_TOKEN  = ENV.fetch('INFLUXDB_TOKEN')
  INFLUXDB_ORG    = ENV.fetch('INFLUXDB_ORG', 'home')
  INFLUXDB_BUCKET = ENV.fetch('INFLUXDB_BUCKET', 'home_metrics')

  def self.log(msg)
    puts "[#{Time.now.strftime('%Y-%m-%d %H:%M:%S')}] #{msg}"
  end

  def self.influx_client
    InfluxDB2::Client.new(
      INFLUXDB_URL,
      INFLUXDB_TOKEN,
      org: INFLUXDB_ORG,
      bucket: INFLUXDB_BUCKET,
      precision: InfluxDB2::WritePrecision::SECOND,
      use_ssl: INFLUXDB_URL.start_with?('https')
    )
  end

  def self.run(interval:)
    write_api = influx_client.create_write_api

    loop do
      tick = Time.now
      yield write_api
      elapsed = Time.now - tick
      sleep [interval - elapsed, 0].max
    rescue => e
      warn "Error in collect loop: #{e.message}"
      sleep interval
    end
  end
end
