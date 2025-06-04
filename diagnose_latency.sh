#!/bin/bash

echo "=== Network Latency Diagnosis for nachna.com ==="
echo

# 1. DNS Resolution Time
echo "1. DNS Resolution Time:"
dig nachna.com | grep "Query time"
echo

# 2. Ping Latency
echo "2. Ping Latency to 18.232.114.74:"
ping -c 5 18.232.114.74 | tail -n 1
echo

# 3. Traceroute
echo "3. Traceroute to nachna.com:"
traceroute -m 15 nachna.com
echo

# 4. HTTP Response Time Breakdown
echo "4. HTTP Response Time Breakdown:"
curl -w @- -o /dev/null -s "http://nachna.com/api/workshops?version=v2" <<'EOF'
    time_namelookup:  %{time_namelookup}s\n
       time_connect:  %{time_connect}s\n
    time_appconnect:  %{time_appconnect}s\n
   time_pretransfer:  %{time_pretransfer}s\n
      time_redirect:  %{time_redirect}s\n
 time_starttransfer:  %{time_starttransfer}s\n
                    ----------\n
         time_total:  %{time_total}s\n
EOF
echo

# 5. Multiple Request Test
echo "5. Multiple Request Test (10 requests):"
for i in {1..10}; do
    time=$(curl -o /dev/null -s -w '%{time_total}' "http://nachna.com/api/workshops?version=v2")
    echo "Request $i: ${time}s"
done
echo

# 6. Check MTU Size
echo "6. MTU Size Check:"
ping -c 1 -M do -s 1472 nachna.com
echo

# 7. Check for packet loss
echo "7. Packet Loss Test (20 packets):"
ping -c 20 nachna.com | grep "packet loss"
echo

echo "=== Diagnosis Complete ===" 