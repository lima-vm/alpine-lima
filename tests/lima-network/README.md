# lima-network test

This directory contains sample data files to manually test the
`lima-network.awk` script. Run it from the repo root:

```console
$ awk -f lima-network.awk tests/lima-network/*
set -eux
echo "Address 55:55:55:00:00:03 already assigned to 'net1', ignoring 'net2'"
ip link set eth8 name net8
echo "Address 55:55:55:00:00:0a not found, cannot assign to 'none'"
ip link set eth3 name net1
ip link set eth9 name itf0
ip link set eth4 name eth9
ip link set eth0 name itf1
ip link set eth1 name eth0
ip link set eth2 name eth1
ip link set itf1 name eth2
ip link set eth6 name itf1
ip link set eth7 name eth6
ip link set itf1 name eth7
```

The output may look a little different because `awk` iterates over arrays
in its internal hash order, so the execution is not quite deterministic.

If you make changes, don't forget to test on an Alpine Lima instance too,
as the busybox version of awk is *not* gawk, even though it has some of its
additional features, like `gensub`.
