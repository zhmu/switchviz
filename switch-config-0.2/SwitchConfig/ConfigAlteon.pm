#!/usr/bin/perl -w

use strict;
package SwitchConfig::ConfigAlteon;
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
	my ($curif, $curvlan) = undef;
	while (<F>) {
		# sanitize the lines: no newlines
		chop; s/^\s+//; s/\s+$//;

		# sections
		if (/\/cfg\/port (\d+)$/) {
			$curif = $1;
			$state = 1;
			$self->{port}{$curif} = {
				"label" => "?",
				"link" => "disabled",
				"tagged" => [ ],
				"untagged" => [ ]
			};
			next;
		}
		if (/\/cfg\/vlan (\d+)$/) {
			$curvlan = $1;
			$state = 2;
			$self->{vlan}{$curvlan} = {
				"id" => $curvlan,
				"label" => "?",
				"tagged" => [ ],
				"untagged" => [ ]
			} unless defined $self->{vlan}{$curvlan};
			next;
		}
		if (/\/cfg\/port/) { $state = 0; next; }
		if ($state eq 1) {
			my $h = \%{ $self->{port}{$curif} };
			if (/^ena$/) { $h->{"link"} = "enabled"; next; }
			if (/^name (\S+)$/) { $h->{"label"} = $1; next; }
			if (/^pvid (\d+)$/) {
				push (@{ $h->{"untagged"} }, $1);
				$self->{vlan}{$1} = {
					"id" => $1,
					"label" => "?",
					"tagged" => [ ],
					"untagged" => [ ]
				} unless defined $self->{vlan}{$1};
				my $hv = \%{ $self->{vlan}{$1} };
				push (@{ $hv->{"untagged"} }, $curif);
				next;
			}
			next;
		}
		if ($state eq 2) {
			if (/\//) { $state = 0; next; }
			my $v = \%{ $self->{vlan}{$curvlan} };
			if (/^name "(\S+)"$/) { $v->{"label"} = $1; next; }
			if (/^def (.+)$/) {
				foreach my $n (split (/ /, $1)) {
					# Alteons have the annoying fact that this list doesn't destinguish
					# between tagged and untagged. Untagged can be found using the pvid $n
					# line, so we can skip it in that case
					my $p = \%{ $self->{port}{$n} };
					if (scalar (grep { $_ eq $curvlan } @{ $p->{"untagged"} }) eq 0) {
						push (@{ $p->{"tagged"} }, $curvlan);
						push (@{ $v->{"tagged"} }, $n);
					}
				}
				next;
			}
			next;
		}
	}
	close F;
	return 1;
}

1;

# vim:set ts=2 sw=2:
