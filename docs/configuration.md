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

## vpn

### `vpnconf`

Your `.ovpn` files will have `auth-user-pass` fixed on the fly.

### `vpnauth`

To use vpn servers which require authentication, create a file in `.openvpn.d/` with a `.auth` extension.
You can define many authentication files for all of your vpn providers and servers. 

```
username
password
```
### `vpnlock`

## machine resources

## `mem`
amount of memory given to vagrant

## `cpu`
number of cpu cores to give to vagrant

## `cpuexecutioncap`
limit the amount of cpu power available
