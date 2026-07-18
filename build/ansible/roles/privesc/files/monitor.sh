#!/bin/bash

grep "error\|failed\|warning" /var/log/syslog | grep -v "daemon" > /var/log/critical_events.log

echo "Last check: $(date)" >> /var/log/critical_events.log
