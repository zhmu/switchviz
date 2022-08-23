#!/usr/bin/perl -w

use strict;
package SwitchConfig::Config3Com;
our @ISA = qw(SwitchConfig);

sub new {
	my ($class) = @_;
	my $this = { };

	$this->{port} = { };
	$this->{vlan} = { };

	bless $this, $class;
	return $this;
};

sub read {
	my ($self, $fname, $numports) = @_;

	open F, $fname or return 0;
	my $state = 0;
	while (<F>) {
		# sanitize the lines: no newlines, consolidate spaces and drop trailing
		# spaces
		chop; s/\s+$//; s/\s+/|/g;

		# blank line or just dashes indicate a new section
		if (($_ eq "") or ($_ =~ /^---/)) { $state = 0; next; } 

		# figure out the sections
		if (/port\|portLabel/) { $state = 1; next; }
		if (/port\|portState\|linkStatus/) { $state = 2; next; }
		if (/Index\|VID\|Type\|Origin/) { $state = 3; next; }
		if (/Index\|Name\|Ports/) { $state = 4; next; }
		if (/Index\|Port\|Tag\|Type/) { $state = 5; next; }

		if ($state eq 1) {
			# port|label
			my ($pnr, $label) = split (/\|/);
			$label = "" unless defined $label;
			$self->{port}{$pnr} = {
				"label" => $label,
				"link" => "?",
				"tagged" => [ ],
				"untagged" => [ ]
			};
		} elsif ($state eq 2) {
			# port|state|link
			my ($pnr, $state, $link) = split (/\|/);
			my $h = \%{ $self->{port}{$pnr} };
			$h->{"link"} = $link;
		} elsif ($state eq 3) {
			# vlanidx|vlan|type|orgin
			my ($vlanidx, $vlanid, $type, $orgin) = split (/\|/);
			$self->{vlan}{$vlanidx} = {
				"id" => $vlanid,
				"label" => "?",
				"type" => $type,
				"orgin" => $orgin,
				"tagged" => [ ],
				"untagged" => [ ]
			};
		} elsif ($state eq 4) {
			# vlanidx|label|ports
			my ($vlanidx, $label, $ports) = split (/\|/);
			my $h = \%{ $self->{vlan}{$vlanidx} };
			$h->{"label"} = $label;
			$h->{"ports"} = ();
			foreach my $port (split (/,/, $ports)) {
				if ($port =~ /(\d+)\-(\d+)/) {
					for (my $i = $1; $i < $2; $i++) {
						$h->{"ports"}[$i] = "unspec";
					}
				} else {
					$h->{"ports"}[$port] = "unspec";
				}
			}
		} elsif ($state eq 5) {
			# vlanidx|port|tag|type
			my ($vlanidx, $pnr,  $type) = split (/\|/);
			my $hv = \%{ $self->{vlan}{$vlanidx} };
			$hv->{"ports"}[$pnr] = $type;
			my $hp = \%{ $self->{port}{$pnr} };
			if ($type eq "none") {
				push (@{ $hp->{"untagged"} }, $hv->{"id"});
				push (@{ $hv->{"untagged"} }, $pnr);
			} elsif ($type eq "802.1Q") {
				push (@{ $hp->{"tagged"} }, $hv->{"id"});
				push (@{ $hv->{"tagged"} }, $pnr);
			} else {
				warn "Unknown VLAN type [$type]";
			}
		}
	}
	close F;

	return 1;
}

1;

# vim:set ts=2 sw=2:
