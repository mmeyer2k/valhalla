# valhalla - a highly configurable dns caching tunneling proxy virtual server

![command line interface](https://github.com/mmeyer2k/valhalla/blob/master/docs/img/topology.png?raw=true)

are you sitting down?
valhalla combines a range of technologies to provide an amazing increase in the privacy and security of your entire local network.
at its core, the primary functions of valhalla are:
- to provide a lan accessable dns server with highly customizable white and black lists
- to use dnscrypt to securely forward dns queries over https
- to (optionally) forward all internet-bound traffic from the vm through a vpn server for extra privacy
- to present an open http proxy that any computer can use, which allows them to take advantage of the dns rules and vpn tunnel (if used)
- to use continuously updated copies of the very good blocklists at [notracking/hosts-blocklists](https://github.com/notracking/hosts-blocklists) to block spam, ads, malware, telemetry and tons of other garbage
- to be able to quickly switch between three ruleset strictness modes
- to be able to run as a minimalist virtual machine for portability
- to provide a robust commandline interface to control the system
- to support IPv6

the core technology stack is: ubuntu + dnsmasq + dnscrypt + dnssec + openvpn + squid + vagrant

## how to get started with valhalla

this project is my personal dns server builder.
it is written for my own situation and preferences.
if you want to use this for yourself, start by making your own fork/clone.

**valhalla is meant to be run on your local network and not exposed to the internet, as it would act as an open dns resolver and open http proxy!**

### creating rules

#### `lists.d` directory

yaml formatted rules files can be placed into this folder. 
any file with a `.yaml` extension will be parsed in lexical order and its options will be merged.
each file can contain any of the following arrays: `whitelist`, `blacklist` and `raw`.

raw dnsmasq options can be add by placing them into a `raw` array.
raw rules are followed in either `tight` or `loose` mode.
any dnsmasq config parameters can be used here so you might want to read the [manual](http://www.thekelleys.org.uk/dnsmasq/docs/dnsmasq-man.html).

dnsmasq's default behavior is that **more specific entries take precidence over less specific entries**.
```
blacklist:
  - example.com
  - tld
whitelist:
  - sub.example.com
raw:
  - address=/custom.com/1.2.3.4
```

#### `hosts.d` directory

additional hosts files can be loaded into dnsmasq at start up by putting them in this folder.

### basic configuration

very general settings are stored in `vagrant.yaml`.
the settings in this file are described [here](https://github.com/mmeyer2k/valhalla/blob/master/docs/configuration.md).


### starting the vm
run `vagrant up`.

### now what?
you can set your router to use the vm for its default dhcp dns.
you can set your computer(s) to use the vm for dns.
you can set your os(es) to use the http proxy on port `8888`.

## command line interface
for the sake of simplicity, valhalla is command-line focused.
once booted, use `vagrant ssh` to log in to the vm then `valhalla` to view options.

please note, interchangeable aliases for the `valhalla` executable are available: `v` and `va`.
additionally, all parameters can be accessed by their first one or two characters.
for example `valhalla log squid`, `v l s` and `va lo sq` are identical.

![command line interface](https://github.com/mmeyer2k/valhalla/blob/master/docs/img/cli.png?raw=true)

### `log`
`usage: valhalla log [dnsmasq, squid, clear, rotate] [past]`

use `log` to tail log files.
second parameter is optional and determines which program's log to watch.
default is `dnsmasq`.

optional `past` parameter will decompress and display logs that have already been rotated.

`clear` will clear out the logs of `dnsmasq` and `squid` along with all rotated histories.
`rotate` will force the logs to rotate.

### `build`
`usage: valhalla build [tight, loose, off]`

`build` quickly and easily deploys ruleset changes.
three build modes are supported. 
these modes do not affect items in the `hosts.d` directory or third-party rule sets.

- `tight` - obey whist and black lists while discarding anything that does not match any list
- `loose` - only obey blacklist but allow everything else
- `off` - disable all dns filtering

### `vpn`
`usage: valhalla vpn [config] [auth]`

`vpn` will switch your vpn connection with a single command based on configuration files in your `openvpn.d/` folder.

`vpn` takes two parameters `conf` and `auth`
leave both options blank to view a numerical list of configs and auths.
if server does not require authentication then auth argument can be omitted.
either the numerical list number or the file name can be used on the command line.

![command line interface](https://github.com/mmeyer2k/valhalla/blob/master/docs/img/cli-vpn.png?raw=true)

### `digest`
`usage: valhalla digest [allowed, denied, queried, clients] [past]`

outputs reports with frequency counts about important dns metrics.

- `allowed` - queries sent to upstream dns (including cache)
- `denied` - queries sent to black hole
- `queried` - total queries inbound
- `clients` - counts number of queries per client ip

logrotate will automatically shuffle this log every day for 30 days.
to analyze the denied log from 2 days ago use `valhalla digest denied 2`.

sometimes these lists can be long, easily scroll output with `less` or `more`.

```bash
valhalla digest queried | less
```

![digest denied](https://github.com/mmeyer2k/valhalla/blob/master/docs/img/cli-digest.png?raw=true)

### `3p`
`usage: valhalla 3p`

redownloads third-party blocklists and restarts dnsmasq.
automatically runs once per day.

### `stress`
`usage: valhalla stress`

generate random dns queries that are likely to be forwarded.
helpful when checking network stack.

## why did i do this?
i love windows 10 but hate how it phones home and updates/restarts your computer without warning.
this problem drove me in search of the optimal solution to being in complete control of my dns.
i had already heard about pihole, but pihole has lots of limitations and a large code base.
it does not support dnscrypt automatically and requires many extra steps to enable.

so why use valhalla?
- literally zero configuration out of the box if not using vpn
- docker is hip but vagrant works just fine you freakin' hipsters
- allows you to easily exclude entire swaths of the internet by [**only** allowing tlds you need](https://github.com/mmeyer2k/valhalla/blob/master/lists.d/tlds.yaml)
- simple to configure and switch vpn servers
- uses dnscrypt and dnssec without extra steps
- all you need is virtualbox + vagrant
- very small project well suited for forking
- hate windows update? hate cortana? nuke all microsoft related domains [like i do](https://github.com/mmeyer2k/valhalla/blob/master/lists.d/microsoft.yaml)
- don't need to trust client software from shady vpn companies, just use their openvpn config files
- revision control your dns rules instead of sticking them in your pihole
- pihole does not allow raw dnsmasq entries

## monitoring
![NORAD bunker](https://github.com/mmeyer2k/valhalla/blob/master/docs/img/command-bunker.png?raw=true)

who needs a fancy dashboard when you have `byobu`?

valhalla ships with a lot of popular monitoring tools so you can easily visualize your network traffic.
- nload
- iftop / htop
- tcptrack

you will find that many things you use will break when you apply strict dns rules.
it is helpful to be able to quickly determine if your dns packets are being dropped.
