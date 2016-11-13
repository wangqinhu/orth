#!/usr/bin/perl

use strict;
use warnings;

my $group = $ARGV[0];
my $pep   = "data/pep.fa";
my $cds = "data/cds.fa";
my $list = "data/nc.edit.id";
my $output_dir = $ARGV[1];

my %group = load_group($group);
my %pep = load_seq($pep);
my %cds = load_seq($cds);
my @list = load_list($list);

group2nal();

# subroutine
sub group2nal {
	create_dir();
	foreach my $group_id (sort keys %group) {
		next unless group_has_id($group_id);
		my $pep_file = extract_pep_seq($group_id);
		my $pal_file = pep_align($group_id, $pep_file);
		pal2nal($group_id, $pal_file);
	}
}

sub create_dir {
	system("rm -rf $output_dir");
	system("mkdir -p $output_dir/pep");
	system("mkdir -p $output_dir/cds");
	system("mkdir -p $output_dir/pal");
	system("mkdir -p $output_dir/nal");
}

sub extract_pep_seq {
	my $group_id = shift;
	my @pep_id = split /\s+/, $group{$group_id};
	my $buffer = undef;
	# seq to buffer
	foreach my $seq_id (@pep_id) {
		next if $seq_id =~ /^\s*$/;
		if (! exists $pep{$seq_id}) {
			warn "$seq_id is not found in $pep.\n";
		} else {
			$buffer .= ">$seq_id\n$pep{$seq_id}\n";	
		}
	}
	# write buffer
	my $out_file = "$output_dir/pep/$group_id.fa";
	open (OUT, ">$out_file") or die "Cannot open file $out_file: $!\n";
	print OUT $buffer;
	close OUT;
	return $out_file;	
}

sub	pep_align {
	my $group_id = shift;
	my $pep_file = shift;
	my $pal_file = "$output_dir/pal/$group_id.aln";
	system("muscle -in $pep_file -clwstrict -out $pal_file");
	return $pal_file;
}

sub pal2nal {
	my $group_id = shift;
	my $pal_file = shift;
	my $nal_file = "$output_dir/nal/$group_id.codon.aln";
	my $nuc_file = extract_nt_seq($group_id);
	system("pal2nal.pl $pal_file $nuc_file > $nal_file");
}

sub extract_nt_seq {
	my $group_id = shift;
	my @pep_id = split /\s+/, $group{$group_id};
	my $buffer = undef;
	# seq to buffer
	foreach my $seq_id (@pep_id) {
		next if $seq_id =~ /^\s*$/;
		if (! exists $cds{$seq_id}) {
			warn "$seq_id is not found in $cds.\n";
		} else {
			$buffer .= ">$seq_id\n$cds{$seq_id}\n";	
		}
	}
	# write buffer
	my $out_file = "$output_dir/cds/$group_id.fa";
	open (OUT, ">$out_file") or die "Cannot open file $out_file: $!\n";
	print OUT $buffer;
	close OUT;
	return $out_file;	
}

sub load_group {
	my $group = shift;
	my %group = ();
	open (IN, $group) or die "Cannot open file $group: $!\n";
	while (<IN>) {
		chomp;
		next if /^\#/;
		next if /^\s*$/;
		my ($group_id, $pep_id) = split /\:/, $_, 2;
		$group{$group_id} = $pep_id;
	}
	close IN;
	return %group;

}

sub load_seq {
	my $seq = shift;
	my %seq = ();
	open (IN, $seq) or die "Cannot open file $seq: $!\n";
	my $seq_id = undef;
	while (<IN>) {
		if (/^\>(\S+)/) {
			$seq_id = $1;
		} else {
			$seq{$seq_id} .= $_;
		}
	}
	close IN;
	return %seq;
}

sub group_has_id {
	my $group_id = shift;
	foreach my $list (@list) {
		return 1 if $group{$group_id} =~ /$list/;
	}
	return 0;
}

sub load_list {
	my $list = shift;
	my @list = ();
	open (IN, $list) or die "Cannot open file $list: $!\n";
	while (<IN>) {
		chomp;
		next if /^\s*$/;
		push @list, $_;
	}
	close IN;
	return @list;
}
