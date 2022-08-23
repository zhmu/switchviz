#!/usr/bin/perl -w

use strict;
package SwitchConfig;

use SwitchConfig::Config3Com;
use SwitchConfig::ConfigAlteon;
use SwitchConfig::ConfigCisco;
use SwitchConfig::ConfigHP;
use SwitchConfig::ConfigCatOS;
use SwitchConfig::ConfigXML;

sub load {
	my ($filename, $type, $numports) =  @_;
	my $obj;
	if ($type eq "3com") {
		$obj = new SwitchConfig::Config3Com;
	} elsif ($type eq "hp") {
		$obj = new SwitchConfig::ConfigHP;
	} elsif ($type eq "alteon") {
		$obj = new SwitchConfig::ConfigAlteon;
	} elsif ($type eq "cisco") {
		$obj = new SwitchConfig::ConfigCisco;
	} elsif ($type eq "catos") {
		$obj = new SwitchConfig::ConfigCatOS;
	} elsif ($type eq "xml") {
		$obj = new SwitchConfig::ConfigXML;
	} else {
		return undef;
	}
	return undef if $obj->read($filename, $numports) eq 0;
	return $obj;
}

sub getPorts {
	my ($this) = @_;
	return $this->{port};
}

sub getVLANs {
	my ($this) = @_;
	return $this->{vlan};
}

1;

=head1 NAME

SwitchConfig - class capable of parsing switch config files

=head1 SYNOPSIS

 use SwitchConfig;

 # initialization
 $obj = new SwitchConfig;
 $obj->load ($filename, $type, $numports) or die "Can't load file";

 # data gathering
 $ports = $obj->getPorts();
 $vlans = $obj->getVLANs();

=head1 DESCRIPTION

The SwitchConfig class is capable of reading switch configuration files and
extracting port interface and VLAN information.

=head2 Methods

=over 2

=item B<load>

$obj = SwitchConfig::load ($filename, $type, $numports)

Loads configuration file $filename. $type must be one of:

=over 4

=item *

3com

Tested with 3Com SuperStack II 9300 and 3Com CoreBuilder 3500 switches.

=item *

hp

Tested with HP Procurve 2524 and 2626 switches.

=item *

cisco

Tested with a Cisco Catalyst 2950C24-EI switch.

=item *

alteon

Tested with an Alteon 180 loadbalancer/switch.

=item *

catos

Tested with a Cisco Catalyst 2926 switch.

=back

This function will return <undef> on failure or an object on success. Currently,
only the 'hp' type requests the number of ports ($numports) to be set.

=item B<getPorts>

$ports = $obj->getPorts();

Returns a hash with all VLANs configured in the switch. Contents of the hash
can be found in the EXAMPLE.

=item B<getVLANs>

$vlans = $obj->getVLANs();

Returns a hash with all VLANs configured in the switch. Contents of the hash
can be found in the EXAMPLE.

=head1 EXAMPLE

$obj = SwitchConfig::load ("hp2626", "hp", 26) or die "Can't load config";

my %ports = %{ $obj->getPorts() };
foreach my $p (sort { $a <=> $b; } keys %ports) {
  my %p = %{ $ports{$p} };
  print "Port $p: " . $p{"label"} . ", link: " . $p{"link"} . "\n";
  print "Tagged in VLAN  :  " . join (", ", @{ $p{"tagged"} }) . "\n";
  print "Untagged in VLAN:  " . join (", ", @{ $p{"untagged"} }) . "\n";
  print "\n";
}

my %vlans = %{ obj->getVLANs() };
foreach my $v (sort { $a <=> $b; } keys %vlans) {
  my %v = %{ $vlans{$v} };

  my $vid = $v{"id"};
  print "Vlan $vid: " . $v{"label"} . "\n";
  print "Tagged in VLAN  :  " . join (", ", @{ $v{"tagged"} }) . "\n";
  print "Untagged in VLAN:  " . join (", ", @{ $v{"untagged"} }) . "\n";
  print "\n";
}

=head1 AUTHOR

 Rink Springer         mail@rink.nu

=cut

# vim:set ts=2 sw=2:
