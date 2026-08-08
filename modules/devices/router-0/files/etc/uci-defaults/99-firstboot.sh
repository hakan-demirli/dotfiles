#!/bin/sh

wifi reload > /dev/null 2>&1 || /sbin/wifi || true
/etc/init.d/network reload > /dev/null 2>&1 || true
/etc/init.d/firewall reload > /dev/null 2>&1 || true

exit 0
