#!/usr/bin/env bash

if bluetoothctl show | grep -q "Powered: yes"; then
    bluetoothctl power off
    bluetoothctl discoverable off
    bluetoothctl pairable off
else
    bluetoothctl power on
    bluetoothctl discoverable on
    bluetoothctl pairable on
fi

