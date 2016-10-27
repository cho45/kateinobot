#!/usr/bin/env ruby


$LOAD_PATH << "../ruby-i2c-devices/lib"
require 'i2c'
require 'i2c/driver/i2c-dev'
require 'i2c/device/adt7410'

@driver = I2CDevice::Driver::I2CDev.new("/dev/i2c-1")

adt7410 = I2CDevice::ADT7410.new(address: 0x48, driver: @driver)

p adt7410.calculate_temperature

