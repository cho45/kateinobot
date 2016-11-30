#!/usr/bin/env ruby

$LOAD_PATH << "../ruby-i2c-devices/lib"
require 'i2c'
require 'i2c/driver/i2c-dev'
require 'i2c/device/adt7410'

@driver = I2CDevice::Driver::I2CDev.new("/dev/i2c-1")
@adt7410 = I2CDevice::ADT7410.new(address: 0x48, driver: @driver)

temp = @adt7410.calculate_temperature

case
when temp < 25
	p system('/home/pi/bin/ir.rb', 'aircon_warm_on')
when temp > 30
	p system('/home/pi/bin/ir.rb', 'aircon_cool_on')
else
	warn "nothing to do"
	# nothing to do
end

