# pimatic-bluebean
Pimatic Plugin that retrieves some sensor data from the LightBlue Bean

Configuration
-------------
If you don't have the pimatic-ble plugin add it to the plugin section:

    {
      "plugin": "ble"
    }

Then add the plugin to the plugin section:

    {
      "plugin": "bluebean"
    },

Then add the device entry for your device into the devices section:

    {
      "id": "bluebean",
      "class": "BlueBeanDevice",
      "name": "bluebean",
      "uuid": "01234567890a"
    }

Then you can add the items into the mobile frontend
