# switchviz

As the network configuration at Dispuut Interlink was ever-changing, documentation was not. Therefore, a system was needed to provide an overview of the current switch configuration and layout.

As switch configuration backups were a requirement as well, I created some Perl modules which I simply refered to as switch config; these create backups of switch configurations and generate documentation based on them.

## Supported configuration files

 * 3Com CoreBuilder 3500 / SuperStack II 9300
 * Alteon 180
 * Cisco Catalyst 2950C24 (IOS)
 * HP ProCurve 24xx and 26xx series
 * Cisco Catalyst 2926 (CatOS) (only in 0.2)
 * SNMP-aware switches (only in 0.2)

## Dependencies

Output is generated using `Graphviz` and `HTML::Template`.

## Downloads

 * [Version 0.2](releases/switch-config-0.2.tar.bz2) (32KB)
 * [Version 0.1](releases/switch-config-0.1.tar.bz2) (32KB)
