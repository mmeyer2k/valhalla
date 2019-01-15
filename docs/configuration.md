# configuration of `valhalla.yaml`

## `ip`
if `ip` this option is left commented out the vm will be given an internal ip and it will only be available to the host computer.
giving the machine an `ip` will cause it to attempt to join your network.
be sure to give provide an `ip` in the allowable dhcp range.

## `mode`
`[tight, loose, off]`

defines the default build mode when running `valhalla build`.
can always be overridden by passing a second parameter.

read more about the build command [here](https://github.com/mmeyer2k/valhalla#build).

## vpn

### `vpnconf`

your `.ovpn` files will have `auth-user-pass` fixed on the fly.

### `vpnauth`

to use vpn servers which require authentication, create a file in `.openvpn.d/` with a `.auth` extension.
you can define many authentication files for all of your vpn providers and servers. 

```
username
password
```

## machine resources

## `mem`
amount of memory given to vagrant

## `cpu`
number of cpu cores to give to vagrant

## `cpuexecutioncap`
limit the amount of cpu power available