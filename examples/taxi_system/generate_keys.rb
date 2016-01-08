#!/usr/bin/env ruby
require_relative '../../lib/cztop'
require 'fileutils'
FileUtils.cd(File.dirname(__FILE__))
FileUtils.mkdir "public_keys"
FileUtils.mkdir "public_keys/drivers"
FileUtils.mkdir "secret_keys"
FileUtils.mkdir "secret_keys/drivers"
#FileUtils.mkdir "certs/drivers"

DRIVERS = %w[ driver1 driver2 driver3 ]

# broker certificate
cert = CZTop::Certificate.new
cert.save("secret_keys/broker")
cert.save_public("public_keys/broker")

# driver certificates
DRIVERS.each do |driver_name|
  cert = CZTop::Certificate.new
  cert["driver_name"] = driver_name
  cert.save "secret_keys/drivers/#{driver_name}"
  cert.save_public "public_keys/drivers/#{driver_name}"
end
