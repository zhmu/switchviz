#!/usr/bin/perl -w

use strict;
package SwitchConfig::ConfigCisco;
our @ISA = qw(SwitchConfig);

sub new {
	my ($class) = @_;
	my $this = { };

	$this->{port} = { };
	$this->{vlan} = { };

	bless $this, $class;
	return $this;
};

sub writeRange {
	my ($self, $range, $if, $type) = @_;

	my $p = \%{ $self->{port}{$if} };
	foreach (split (/,/, $range)) {
		if (/(\d+)-(\d+)/) {
			for (my $i = $1; $i <= $2; $i++) {
				$self->{vlan}{$i} = {
					id       => $i,
					label    => "?",
					tagged   => [ ],
					untagged => [ ]
				} if not defined $self->{vlan}{$i};
				my $v = \%{ $self->{vlan}{$i} };
				push (@{ $p->{$type} }, $i);
				push (@{ $v->{$type} }, $if);
			}
		} else {
			$self->{vlan}{$_} = {
			  id       => $_,
				label    => "?",
				tagged   => [ ],
				untagged => [ ]
			} if not defined $self->{vlan}{$_};
			my $v = \%{ $self->{vlan}{$_} };
			push (@{ $p->{$type} }, $_);
			push (@{ $v->{$type} }, $if);
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

		# sections
		if (/^interface (.+)\d\/(\d+)$/) {
			$curif = "$1$2"; $state = 1;
			# XXX: This would be nice. However, it makes sorting harder, and we don't
			# have any ge interfaces anyway, so be blunt
			#$curif=~ s/FastEthernet/fe/; $curif=~ s/GigabitEthernet/ge/;
			$curif=~ s/FastEthernet//;
			$self->{port}{$curif} = {
				"label" => "?",
				"link" => "enabled",
				"tagged" => [ ],
				"untagged" => [ ],
				"_avlan" => 1,
				"_tnvlan" => 1,
				"_tavlan" => 1,
				"_mode" => "access"
			};
			next;
		}
		if (/\!/) { $state = 0; next; }
		if ($state eq 1) {
			my $h = \%{ $self->{port}{$curif} };
			if (/description (.+)/) { $h->{"label"} = $1; next; }
			if (/switchport access vlan (\d+)/) { $h->{"_avlan"} = $1; next; }
			if (/switchport trunk native vlan (.+)/) { $h->{"_tnvlan"} = $1; next; }
			if (/switchport trunk allowed vlan (.+)/) { $h->{"_tavlan"} = $1; next; }
			if (/switchport mode (\S+)/) { $h->{"_mode"} = $1; next; }
			if (/shutdown/) { $h->{"link"} = "disabled"; next; }
			next;
		}
	}
	close F;

	# Cisco IOS makes it very hard to know if a port has multiple VLAN's or not
	# if you don't have the complete config. This is why we simply first grab
	# everything and dissect it now.
	foreach my $p (keys %{ $self->{port} }) {
		my %p = %{ $self->{port}{$p} };
		if ($p{"_mode"} eq "access") {
			&writeRange ($self, $p{"_avlan"}, $p, "untagged");
		} elsif ($p{"_mode"} eq "trunk") {
			&writeRange ($self, $p{"_tnvlan"}, $p, "untagged");
			&writeRange ($self, $p{"_tavlan"}, $p, "tagged");
		} else {
			warn "port $p has unknown trunk mode";
		}
	}
	return 1;
}

1;

# vim:set ts=2 sw=2:
