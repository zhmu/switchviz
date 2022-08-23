#!/usr/bin/perl -w

use strict;
require "config.pl";

use HTML::Template;
use SwitchConfig;
use File::Temp qw/:mktemp/;
require "switches.pl";

sub generateIndex {
	my @switches; our %switches;
	our $HTML_DIR;

	my $swtpl = HTML::Template->new(filename => 'switch-list.tpl');
	foreach my $sw (keys %switches) { push (@switches, { NAME => $sw } ); }
	$swtpl->param(SWITCH => \@switches);

	my $tpl = HTML::Template->new(filename => 'layout.tpl');
	$tpl->param(CONTENT => $swtpl->output);

	open(F,"+>$HTML_DIR/index.html") or die "Can't create index.html: $!";
	print F $tpl->output;
	close F;
}

sub generateInterSwitch {
	our %switches;
	our $TMP_DIR; our $DOT; our $IMG_DIR;

	my $fname = mktemp("$TMP_DIR/swgraph.XXXXXXX");
	open (F,"+>$fname") or die "Can't create $fname: $!";

	print F "digraph G {\n";

	my %done;
	foreach my $swname (keys %switches) {
		my $sw = $switches{$swname};

		my %ports = %{ $sw->{obj}->getPorts() };
		foreach my $p (keys %ports) {
			next unless $ports{$p}->{"label"} =~ /(.+):(.+)/;
			my ($dev, $pno) = ($1, $2);
			# only handle ports which refer to a switch
			next unless scalar (grep { $_ eq $dev } keys %switches) eq 1;

			# ensure the link points back to us as well
			my $destports = $switches{$dev}->{obj}->getPorts();
			die "$swname:$p points to $dev:$pno, but the latter doesn't point back!" unless $destports->{$pno}->{"label"} eq "$swname:$p";

			# ensure the link is not already made
			next if defined $done{"$swname:$p^$dev:$pno"};
			next if defined $done{"$dev:$pno^$swname:$p"};
			$done{"$swname:$p^$dev:$pno"} = 1;

			# disabled links are dashed. they can be disabled on both ends
			my $style = "solid";
			$style = "dashed" if $ports{$p}->{"link"} ne "enabled";
			$style = "dashed" if $destports->{$pno}->{"link"} ne "enabled";

			# create the link
			print F "\t$swname -> $dev [ dir=both,color=black,style=$style,label=\"$p - $pno\" ]\n";
		}
	}

	print F "}\n";
	close F;

	`$DOT -Tpng -o $IMG_DIR/interswitch.png $fname 2>&1 >/dev/null`;

	unlink ($fname);
}

sub generateSwitches {
	our %switches;
	our $HTML_DIR;

	foreach my $swname (keys %switches) {
		my $switch = $switches{$swname};
		my $swtpl = HTML::Template->new(filename => 'switch-details.tpl');

		my @ports;
		my %ports = %{ $switch->{obj}->getPorts() };
		foreach my $p (sort { $a <=> $b; } keys %ports) {
			my %p = %{ $ports{$p} };
			my $vlans = "";
			foreach my $vl (@{ $p{"untagged"} }) {
				$vlans .= ", " if $vlans ne "";
				$vlans .= $vl;
			}
			$vlans .= ", " if $vlans ne "";
			$vlans .= "{";
			foreach my $vl (@{ $p{"tagged"} }) {
				$vlans .= ", " unless $vlans =~ /{$/;
				$vlans .= $vl;
			}
			$vlans .= "}";
			$vlans=~ s/(, )+\{\}//;

			my $disabled = ($p{"link"} eq "enabled") ? 0 : 1;
			
			if ($p{"label"} =~ /(.+):(.+)/) {
				if (scalar (grep { $_ eq $1} keys %switches) eq 1) {
					push (@ports, {
						PORT => $p,
						SWITCH => $1,
						PORTNUM => $2,
						VLAN => $vlans,
						DISABLED => $disabled
					});
					next;
				}
			}
			push (@ports, {
				PORT => $p,
				LABEL => $p{"label"},
				VLAN => $vlans,
				DISABLED => $disabled
			});
		}

		my @vlans;
		my %vlans = %{ $switch->{obj}->getVLANs() };
		foreach my $v (sort { $a <=> $b; } keys %vlans) {
			my %v = %{ $vlans{$v} };
			my $ports = "";
			foreach my $vl (@{ $v{"untagged"} }) {
				$ports .= ", " if $ports ne "";
				$ports .= $vl;
			}
			$ports .= ", " if $ports ne "";
			$ports .= "{";
			foreach my $vl (@{ $v{"tagged"} }) {
				$ports .= ", " unless $ports =~ /{$/;
				$ports .= $vl;
			}
			$ports .= "}";
			$ports =~ s/(, )+\{\}//;

			push (@vlans, {
				ID => $v{"id"},
				LABEL => $v{"label"},
				PORTS => $ports
			});
		}

		$swtpl->param(SWITCH => $swname, PORTS => \@ports, VLANS => \@vlans);

		my $tpl = HTML::Template->new(filename => 'layout.tpl');
		$tpl->param(CONTENT => $swtpl->output);
		open(F,"+>$HTML_DIR/$swname.html") or die "Can't create $swname.html: $!";
		print F $tpl->output;
		close F;
	}
}

sub generateSwitchGraphs {
	our %switches;
	our $TMP_DIR; our $DOT; our $IMG_DIR;

	foreach my $swname (keys %switches) {
		my $switch = $switches{$swname};
		my $swtpl = HTML::Template->new(filename => 'switch-details.tpl');

		my $fname = mktemp("$TMP_DIR/swgraph.XXXXXXX");
		open (F,"+>$fname") or die "Can't create $fname: $!";

		print F "digraph G {\n";
		my %ports = %{ $switch->{obj}->getPorts() };
		foreach my $p (keys %ports) {
			next unless $ports{$p}->{"label"} =~ /(.+):(.+)/;
			my ($dev, $pno) = ($1, $2);

			# disabled links are dashed. they can be disabled on both ends
			my $style = "solid";
			$style = "dashed" if $ports{$p}->{"link"} ne "enabled";

			# create the link
			$swname=~ s/-//g; $dev=~ s/-//g;
			print F "\t$swname -> $dev [ dir=both,color=black,style=$style,label=\"$p - $pno\",fontsize=6 ]\n";
		}
		print F "}\n";
		close F;

		`$DOT -Tpng -o $IMG_DIR/$swname.png $fname 2>&1 >/dev/null`;

		unlink ($fname);
	}
}

sub generateSwitchGraphAll {
	our %switches;
	our $TMP_DIR; our $DOT; our $IMG_DIR;

	my $fname = mktemp("$TMP_DIR/swgraph.XXXXXXX");
	open (F,"+>$fname") or die "Can't create $fname: $!";

	print F "digraph G {\n";
	#print F "\tranksep=.75; size = \"50,150\";\n";

	my %done;
	foreach my $swname (keys %switches) {
		my $sw = $switches{$swname};
	
		print F "\tsubgraph $swname {\n";
#		print F "\t\tnode[fontsize=8; ];\n";
		print F "\t\t$swname [ center=true; color=red; ];\n";

		my %ports = %{ $sw->{obj}->getPorts() };
		foreach my $p (keys %ports) {
			next unless $ports{$p}->{"label"} =~ /(.+):(.+)/;
			my ($dev, $pno) = ($1, $2);

			# ensure the link is not already made
			next if defined $done{"$swname:$p^$dev:$pno"};
			next if defined $done{"$dev:$pno^$swname:$p"};
			$done{"$swname:$p^$dev:$pno"} = 1;

			# disabled links are dashed. they can be disabled on both ends
			my $style = "solid";
			$style = "dashed" if $ports{$p}->{"link"} ne "enabled";

			# create the link
			$dev=~ s/-//g; # crude
			print F "\t\t$dev -> $swname [ dir=forward,color=black,style=$style,label=\"$p - $pno\" ];\n";
		}

		print F "\t}\n";
	}

	print F "}\n";
	close F;

	`$DOT -Tpng -o $IMG_DIR/all.png $fname 2>&1 >/dev/null`;

	unlink ($fname);
}

# generate all parts of the site
&generateIndex();
&generateInterSwitch();
&generateSwitches();
&generateSwitchGraphs();
&generateSwitchGraphAll();

# vim:set ts=2 sw=2:
