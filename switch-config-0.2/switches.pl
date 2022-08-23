#!/usr/bin/perl -w

use strict;
use SwitchConfig;

# all switches we monitor; only HP needs the number of ports
our %switches = (
	marduk => { type => "3com", file => "/tftpboot/marduk" },
	olympus => { type => "hp", ports => 26, file => "/tftpboot/olympus" },
	poseidon => { type => "alteon", file => "/tftpboot/poseidon" },
	elysium => { type => "cisco", file => "/tftpboot/elysium" },
	asgard => { type => "hp", ports => 14, file => "/tftpboot/asgard" },
	svarga => { type => "catos", file => "/tftpboot/svarga" },
	gehenna => { type => "xml", file => "/home/rink/mib/gehenna.xml" },
);

# read all switch files
foreach my $swname (keys %switches) {
	my $sw = $switches{$swname};
	if (not defined $ENV{"SKIP_CONFIGS"}) {
		$sw->{obj} = SwitchConfig::load($sw->{file}, $sw->{type}, $sw->{ports});
		die "Cannot read switchconfig for $swname" unless defined $sw->{obj};
	}
}

1;

# vim:set ts=2 sw=2:
