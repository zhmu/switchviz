#!/usr/bin/perl -w

use strict;
package SwitchConfig::ConfigHP;
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
	my ($self, $curvlan, $range, $type) = @_;

	my $v = \%{ $self->{vlan}{$curvlan} };
	foreach (split (/,/, $range)) {
		if (/(\d+)-(\d+)/) {
			for (my $i = $1; $i <= $2; $i++) {
				my $p = \%{ $self->{port}{$i} };
				push (@{ $p->{$type} }, $curvlan);
				push (@{ $v->{$type} }, $i);
			}
		} else {
			my $p = \%{ $self->{port}{$_} };
			push (@{ $p->{$type} }, $curvlan);
			push (@{ $v->{$type} }, $_);
		}
	}
}

sub read {
	my ($self, $fname, $numports) = @_;

	for (my $i = 1; $i <= $numports; $i++) {
		$self->{port}{$i} = {
			"label" => "?",
			"link" => "enabled",
			"tagged" => [ ],
			"untagged" => [ ]
		};
	}

	open F, $fname or return 0;
	my $state = 0;
	my ($curif, $curvlan) = undef;
	while (<F>) {
		# sanitize the lines: no newlines
		chop; s/^\s+//; s/\s+$//;

		# exit indicates a new section
		if ($_ eq "exit") { $state = 0; next; } 

		# sections
		if (/interface (\d+)/) {
			$curif = $1; $state = 1;
			next;
		}
		if (/vlan (\d+)/) {
			$curvlan = $1; $state = 2;
			$self->{vlan}{$curvlan} = {
				"id" => $curvlan,
				"label" => "?",
				"tagged" => [ ],
				"untagged" => [ ]
			};
			next;
		}

		if ($state eq 1) {
			my $h = \%{ $self->{port}{$curif} };
			if (/name \"(.+)\"/) { $h->{"label"} = $1; next; }
			if (/disable/) { $h->{"link"} = "disabled"; next; }
			next;
		}
		if ($state eq 2) {
			my $v = \%{ $self->{vlan}{$curvlan} };
			if (/name \"(.+)\"/) { $v->{"label"} = $1; next; }
			if (/^tagged (.+)/) {
				&writeRange ($self, $curvlan, $1, "tagged");
				next;
			}
			if (/^untagged (.+)/) {
				&writeRange ($self, $curvlan, $1, "untagged");
				next;
			}
		}
	}
	close F;
	return 1;
}

1;

# vim:set ts=2 sw=2:
