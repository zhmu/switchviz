#!/usr/bin/perl -w

use strict;

# if the system does not have XML::LibXML installed; do not provide XML
# services
eval "use XML::LibXML;";
return 1 if $@;

package SwitchConfig::ConfigXML;
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

	my $doc = XML::LibXML->new();
	my $tree = $doc->parse_file($fname);
	my $root = $tree->getDocumentElement;

	# handle VLAN's first
	my $vlans = ($root->getElementsByTagName('vlans'))[0];
	foreach my $vlan ($vlans->getElementsByTagName('vlan')) {
		my $id = $vlan->getAttribute('id');
		my $name = ($vlan->getElementsByTagName('name'))[0];
		$self->{vlan}{$id} = {
			"id" => $id,
			"label" => $name ? $name->textContent : "",
			"tagged" => [ ],
			"untagged" => [ ]
		};
	}

	# wade through the interfaces
	my $ifs = ($root->getElementsByTagName('interfaces'))[0];
	foreach my $if ($ifs->getElementsByTagName('interface')) {
		my $id = $if->getAttribute('index');
		my $alias = ($if->getElementsByTagName('alias'))[0];
		my $status = ($if->getElementsByTagName('status'))[0];

		$self->{port}{$id} = {
			"label" => $alias ? $alias->textContent : "",
			"link" =>  $status ? ($status->textContent eq 1 ? "enabled" : "disabled") : "?",
			"tagged" => [ ],
			"untagged" => [ ]
		};
		my $p = \%{ $self->{port}{$id} };

		# handle VLAN config
		$vlans = ($if->getElementsByTagName('vlans'))[0];
		foreach my $vlan ($vlans->getElementsByTagName('vlan')) {
			my $type = $vlan->getAttribute('type');
			my $vid = $vlan->getAttribute('id');
			my $v = \%{ $self->{vlan}{$vid} };

			push (@{ $p->{$type} }, $vid);
			push (@{ $v->{$type} }, $id);
		}
	}
	
	# XXX: this is a hack. Some switches seem to report the same VLAN as
	# both tagged and untagged. However; this seems wrong, so we bluntly
	# chunk it out
	foreach (keys %{ $self->{port} }) {
		my $p = \%{ $self->{port}{$_} }; my @n;
		foreach my $vid (@{ $p->{tagged} }) {
			push @n, $vid unless scalar grep { $_ eq $vid } @{ $p->{untagged} };
		}
		$p->{tagged} = [ @n ];
	}

	# XXX: repeat the same hack for VLANs as well
	foreach (keys %{ $self->{vlan} }) {
		my $v = \%{ $self->{vlan}{$_} }; my @n;
		foreach my $vid (@{ $v->{tagged} }) {
			push @n, $vid unless scalar grep { $_ eq $vid } @{ $v->{untagged} };
		}
		$v->{tagged} = [ @n ];
	}
	return 1;
}

1;

# vim:set ts=2 sw=2:
