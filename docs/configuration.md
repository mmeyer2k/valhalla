# How to customize `config.yaml`

## `ip`
If `ip` this option is left commented out the vm will be given an internal ip and it will only be available to the host computer.
Giving the machine an `ip` will cause it to attempt to join your network.
Be sure to give provide an `ip` in the allowable dhcp range.

**Local IP addresses require administrative privileges to be able to forward port 53 back to host**

## `mode`
`[tight, loose, off]`

Defines the default build mode when running `valhalla build`.
Can always be overridden by passing a second parameter.

Read more about the build command [here](https://github.com/mmeyer2k/valhalla#build).

## `socks5`
Send all outgoing traffic through a socks5 proxy for extra privacy.
Leave line commented for direct connection to DNS servers.
Tor is installed by default and listening at `socks5://127.0.0.1:9050`.

## machine resources

### `mem`
Amount of memory given to vagrant.

### `cpu`
Number of cpu cores to give to vagrant.

### `cpuexecutioncap`
Limit the amount of CPU power available.
