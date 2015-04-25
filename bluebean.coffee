module.exports = (env) ->
  Promise = env.require 'bluebird'
  convict = env.require "convict"
  assert = env.require 'cassert'
  
  Bean = require "ble-bean"
  ieee754 = require "ieee754"
  events = require "events"

  class BlueBeanPlugin extends env.plugins.Plugin
    init: (app, @framework, @config) =>
      deviceConfigDef = require("./device-config-schema")
      @devices = []

      @framework.deviceManager.registerDeviceClass("BlueBeanDevice", {
        configDef: deviceConfigDef.BlueBeanDevice,
        createCallback: (config) =>
          @devices.push config.uuid
          new BlueBeanDevice(config)
      })
      
      @framework.on "after init", =>
        @ble = @framework.pluginManager.getPlugin 'ble'
        if @ble?
          @ble.registerName 'Bean'
          (@ble.addOnScan device for device in @devices)
          @ble.on("discover", (peripheral) =>
            @emit "discover-"+peripheral.uuid, peripheral
          )
        else
          env.logger.warn "bluebean could not find ble. It will not be able to discover devices"

    addOnScan: (uuid) =>
      env.logger.debug "Adding device "+uuid
      @ble.addOnScan uuid

    removeFromScan: (uuid) =>
      env.logger.debug "Removing device "+uuid
      @ble.removeFromScan uuid

  class BlueBeanDevice extends env.devices.Sensor
    attributes:
      temperature:
        description: "the measured temperature"
        type: "number"
        unit: '°C'
      battery:
        description: "the measured battery"
        type: "number"
        unit: 'V'
      current:
        description: "The instantaneous current"
        type: "number"
        unit: 'A'
      power:
        description: "The apparent power"
        type: "number"
        unit: 'W'
      consumption:
        description: "Consumption over last hour"
        type: "number"
        unit: "Wh"

    temperature: 0.0
    battery: 0.0
    current: 0.0
    power: 0.0
    consumption: 0.0

    constructor: (@config) ->
      @id = config.id
      @name = config.name
      @uuid = config.uuid
      @peripheral = null
      @connected = false
      super()
      plugin.on("discover-#{@uuid}", (peripheral) =>
        env.logger.debug "device #{@name} found"
        if not @connected
          @connected = true
          @connect peripheral
      )

    connect: (peripheral) =>
      @peripheral = peripheral
      blueBean = new Bean(peripheral)
      blueBean.on 'disconnect', =>
        env.logger.debug "device #{@name} disconnected"
        plugin.addOnScan @uuid
        @connected = false
      blueBean.connect =>
        env.logger.debug "device #{@name} connected"
        plugin.removeFromScan peripheral.uuid
        blueBean.discoverServicesAndCharacteristics =>
          env.logger.debug "configuring device #{@name}"
          blueBean.notifyOne((data) =>
            value = data[1]<<8 || (data[0])
            @emit "temperature", Number value
          )
          blueBean.notifyTwo((data) =>
            value = data[1]<<8 || (data[0])
            @emit "battery", Number (value/1000).toFixed(3)
          )
          blueBean.notifyThree((data) =>
            value = ieee754.read(data, 0, true, 23, 4)
            @emit "current", Number value.toFixed(1)
          )
          blueBean.notifyFour((data) =>
            value = ieee754.read(data, 0, true, 23, 4)
            @emit "power", Number value.toFixed(1)
          ) 
          blueBean.notifyFive((data) =>
            value = ieee754.read(data, 0, true, 23, 4)
            @emit "consumption", Number value.toFixed(1)
          )

    getTemperature: -> Promise.resolve @temperature
    getBattery: -> Promise.resolve @battery
    getCurrent: -> Promise.resolve @current
    getPower: -> Promise.resolve @power
    getConsumption: -> Promise.resolve @consumption

  plugin = new BlueBeanPlugin
  return plugin
