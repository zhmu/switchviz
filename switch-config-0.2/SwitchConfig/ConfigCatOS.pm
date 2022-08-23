#!/usr/bin/perl -w

use strict;
package SwitchConfig::ConfigCatOS;
our @ISA = qw(SwitchConfig);

sub new {
	my ($class) = @_;
	my $this = { };

	$this->{port} = { };
	$this->{vlan} = { };

	bless $this, $class;
	return $this;
};

sub 
getPort {
	my ($self, $portid) = @_;

	$self->{port}{$portid} = {
		"label" => "?",
		"link" => "?",
		"tagged" => [ ],
		"untagged" => [ ]
	} unless $self->{port}{$portid};

	return $self->{port}{$portid};
}

sub
getVLAN {
	my ($self, $vlanid) = @_;

	$self->{vlan}{$vlanid} = {
		id       => $vlanid,
		label    => "?",
		tagged   => [ ],
		untagged => [ ]
	} if not defined $self->{vlan}{$vlanid};

	return $self->{vlan}{$vlanid};
}

sub
processPortList {
	my ($l, $func, @ar) = @_;

	foreach (split(/(\s+)/, $l)) {
		# check for a module/port combo
		next if not /^\d\/\d/;

		# got it; now handle the individual ports or ranges in it
		foreach (split(/,/)) {
			if (/(\d+)\/(\d+)-(\d+)/) {
				# it's a range; process it
				for (my $i = $2; $i <= $3; $i++) {
					&$func("$1/$i", @ar);
				}
			} else {
				# simple single port
				&$func($_, @ar);
			}
		}
	}
}

sub read {
	my ($self, $fname, $numports) = @_;

	open F, $fname or return 0;
	my $state = 0;
	my ($curif, $curvlan) = undef;
	while (<F>) {
		# sanitize the lines: no newlines
		chop; s/^\s+//; s/\s+$//;

		if (/^set vlan (\d+)/) {
			my $vlanid = $1; my $name = undef;
			if (/name (\S+) /) { $name = $1; }

			if (not $self->{vlan}{$vlanid}) {
				# just create the VLAN
				my $p = \%{ &getVLAN($self, $vlanid) };
				$p->{label} = $name ? $name : "";
			} else {
				# this could be line involving port numbers to bind to the vlan!
				# wade through it ...
				s/set vlan \d+\s+//;
				&processPortList($_, sub {
					my ($p, $vlanid, $self) = @_;
					my %h = %{ &getVLAN($self, $vlanid) };
					my %p = %{ &getPort($self, $p) };
					push (@{ $h{"untagged"} }, $p);
					push (@{ $p{"untagged"} }, $vlanid);
				}, $vlanid, $self);
			}
			next;
		}

		if (/^set port (\S+)\s+(.+)/) {
			if ($1 eq "name") {
				$2 =~ /(\S+)((\s+)(\S+))?/ or next;

				&processPortList($1, sub {
					my ($p, $label, $self) = @_;
					$label = "" unless $label; # set empty label if undefined

					my $pt = \%{ &getPort($self, $p) };
					$pt->{label} = $label;
				}, $4, $self);
				next;
			} elsif (($1 eq "enable") or ($1 eq "disable")) {
				&processPortList($2, sub {
					my ($p, $en, $self) = @_;
					my $pt = \%{ &getPort($self, $p) };
					$pt->{link} = $en;
				}, ($1 eq "enable") ? "enabled" : "disabled", $self);
				next;
			}
		}

		if (/^set trunk (\d+\/\d+)\s+(.+)/) {
			my $portid = $1;
			my $p = \%{ &getPort($self, $portid); };
			$2 =~ /(\S+)\s+(\S+)/ or next;
			if ($1 eq "on") {
				# trunk is enabled; add all VLANs we know of
				if ($2 =~ /(\d+)-(\d+)/) {
					for (my $i = $1; $i <= $2; $i++) {
						# we only add vlans that we have knowledge about
						# XXX: is this correct?
						push (@{ $p->{tagged} }, $i) if $self->{vlan}{$i};
					}
				} else {
					# single vlan
					push (@{ $p->{tagged} }, $2);
				}
			}

			# XXX: this is very crude, but I think it's needed. if a port is in
			# a trunk, I'd expect everything to be tagged; remove all untagged
			# ports in such a case
			$p->{untagged} = [ ];
		}
	}
	close F;

	return 1;
}

1;

# vim:set ts=2 sw=2:
