#!/usr/bin/perl -w

use strict;

# do not restrict us to installations with SNMP; if this is lacking, just be
# gone with it.
eval "use SNMP;";
return 1 if @$;

&SNMP::initMib();
&SNMP::addMibFiles(
	'mibs/RMON2.MIB',
	'mibs/RFC1493.MIB',
	'mibs/draft2674ext.mib'
);

sub
backupSNMP {
	my ($switch, $file, $community) = @_;
	$community = "public" unless $community;

	open F,">$file" or die;

	my $session = new SNMP::Session(DestHost => $switch,
	                                Community => $community,
	                                Version => 1);
	die unless $session;
	my $vars;

	$vars = new SNMP::VarList(['ifIndex', 0, ''], ['ifName', 0, ''], ['ifAlias' ,0, ''], ['ifAdminStatus', 0,'']);
	my %iftab;
	while (my @if = $session->getnext($vars)) {
		last if $vars->[0]->tag ne "ifIndex";
		my ($index, $name, $alias, $status) = @if;
		$iftab{$index} = {
			index => $index,
			name => $name,
			alias => $alias,
			status => $status,
			tagged => [ ],
			untagged => [ ]
		};
	}

	$vars = new SNMP::VarList(['dot1qVlanStaticName'],['dot1qVlanStaticUntaggedPorts'],['dot1qVlanStaticEgressPorts']);
	my %vlantab;
	while (my @vlan = $session->getnext($vars)) {
		last if $vars->[0]->tag ne "dot1qVlanStaticName";
		my $vlanid = $vars->[0]->iid;
		my ($name, $untagged, $tagged) = @vlan;
		my $pno = 0;
		foreach (split(//,unpack("B*", $untagged))) {
			$pno++; next unless $_ eq 1;
			push @{ $iftab{$pno}{untagged} }, $vlanid;
		}
		$pno = 0;
		foreach (split(//,unpack("B*", $tagged))) {
			$pno++; next unless $_ eq 1;
			push @{ $iftab{$pno}{tagged} }, $vlanid;
		}
		$vlantab{$vlanid} = {
			name => $name
		};
	}

	print F "<?xml version=\"1.0\"?>\n";
	print F "<switchconfig>\n";
	print F " <vlans>\n";
	foreach (sort { $a <=> $b } keys %vlantab) {
		my %vlan = %{ $vlantab{$_}; };

		print F "  <vlan id=\"$_\">\n";
		print F "   <name>$vlan{name}</name>\n";
		print F "  </vlan>\n";
	}
	print F " </vlans>\n";
	print F " <interfaces>\n";
	foreach (sort { $a <=> $b } keys %iftab) {
		my %if = %{ $iftab{$_}; };

		print F "  <interface index=\"$if{index}\">\n";
		print F "   <name>$if{name}</name>\n" if $if{name};
		print F "   <alias>$if{alias}</alias>\n" if $if{alias};
		print F "   <status>$if{status}</status>\n" if $if{status};
		print F "   <vlans>\n";
		foreach (@{ $if{untagged} }) {
			print F "    <vlan type=\"untagged\" id=\"$_\" />\n";
		}
		foreach (@{ $if{tagged} }) {
			print F "    <vlan type=\"tagged\" id=\"$_\" />\n";
		}
		print F "   </vlans>\n";
		print F "  </interface>\n";
	}
	print F " </interfaces>\n";
	print F "</switchconfig>\n";
	close F;
}

1;
