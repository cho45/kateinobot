$LOAD_PATH << "/home/pi/project/ruby-i2c-devices/lib"
require 'i2c'
require 'i2c/driver/i2c-dev'
require 'i2c/device/adt7410'

@driver = I2CDevice::Driver::I2CDev.new("/dev/i2c-1")
@adt7410 = I2CDevice::ADT7410.new(address: 0x48, driver: @driver)

on_text('室温') do
	temp = @adt7410.calculate_temperature
	reply_text('現在の室温は%.1f℃' % [temp])
end
