# claymore-munin
Munin plugin for claymore miner stats

There are 2 components: the poller itself (minerpoll.sh -- which can be used for other purposes too, and even has a nice "cache" effect) and the plugin wrapper script (miner_).

The poller code should be self-explanatory: it telnets to the miner host on port 3333 and parses the Json returned by claymore.

The munin script must be symlinked from /etc/munin/plugins, with the hostname after the '_' (e.g. miner_miner5, where "miner5" should be a valid hostname on your network).

Todo: a whole lot. This is just the first PoC hacked together in about a day.
