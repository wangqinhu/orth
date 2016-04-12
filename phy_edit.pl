#!/usr/bin/perl

use strict;
use warnings;
use Bio::AlignIO;

#----------------------------------------------------------
# file and directory setting
#----------------------------------------------------------
my $nal_dir = "output_test/nal";
my $edit = "data/fg.edit.txt";
my $output_dir = "output_dir";

#----------------------------------------------------------
# global var
#----------------------------------------------------------
my %phy = ();
my %edit = load_edit($edit);
my %fungi = load_fungi();
my $num_flank_codon = 5;
my %codon_table = codon_table();
my %phy_edit = ();
my %phy_rna = ();
my %phy_aa = ();
my %phy_vt = ();

#----------------------------------------------------------
# main
#----------------------------------------------------------
phy_edit();

#----------------------------------------------------------
# subroutine
#----------------------------------------------------------
sub phy_edit {
	create_dir();
	my @nals = load_nal($nal_dir);
	foreach my $nal (@nals) {
		my @fn = split /\//, $nal;
		my $group = $fn[-1];
		$group =~ s/\.codon.aln//;
		my $fas = "$output_dir/fas/$group.fa";
		my %seq = nal2fasta($nal, $fas);
		next unless %seq;
		my @fg = pick_fg(\%seq);
		next if @fg < 1;
		foreach my $fg_id (@fg) {
			if (has_edit_in_fg($fg_id)) {
				foreach my $edit_i (sort by_num keys $edit{$fg_id}) {
					my $pos = $edit{$fg_id}{$edit_i};
					%seq = remove_redundancy(\%seq, $fg_id);
					query_col($group, $fg_id, $pos, \%seq);
				}
			}
		}
	}
	%phy_vt = phy_var();
	analyze_phy_edit();
}

sub analyze_phy_edit {
	foreach my $grp_id (keys %phy_edit) {
		foreach my $fg_id (keys $phy_edit{$grp_id}) {
			foreach my $pos (keys $phy_edit{$grp_id}{$fg_id}) {
				print "# $grp_id\t$fg_id\t$pos\t$phy_vt{$grp_id}{$fg_id}{$pos}\n";
				foreach my $seq_id (sort by_fungi keys $phy_edit{$grp_id}{$fg_id}{$pos}) {
					print "\t\t\t";
					print substr($seq_id, 0, 2), "\t";
					print "$phy_rna{$grp_id}{$fg_id}{$pos}{$seq_id}\t";
					print "$phy_aa{$grp_id}{$fg_id}{$pos}{$seq_id}\t";
					print "$seq_id\n";
				}
			}
		}
	}
}

sub remove_redundancy {
	my $seqref = shift;
	my $fg_id = shift;
	my %seq = ();
	my %once = ();
	foreach my $seq_id (keys $seqref) {
		my $tag = substr($seq_id, 0, 2);
		if (!exists $once{$tag}) {
			$once{$tag} = $seq_id;
			$seq{$seq_id} = $seqref->{$seq_id};
		} else {
			my $sim_new = similarity($seqref->{$seq_id}, $seqref->{$fg_id});
			my $sim_old = similarity($seq{$once{$tag}}, $seqref->{$fg_id});
			if ($sim_new > $sim_old) {
				$seq{$seq_id} = $seqref->{$seq_id};
			}
		}
	}
	return %seq;
}

sub similarity {
	my $seq1 = shift;
	my $seq2 = shift;
	$seq1 =~ s/\-//g;
	$seq2 =~ s/\-//g;
	open (S1, ">seq1.fa") or die $!;
	print S1 ">a\n$seq1\n";
	close S1;
	open (S2, ">seq2.fa") or die $!;
	print S2 ">b\n$seq2\n";
	close S2;
	my $sw_align = `ssearch36 -3 -m 8 seq1.fa seq2.fa`;
	my @item = split /\s+/, $sw_align;
	my $sim = $item[2];
	unlink "seq1.fa";
	unlink "seq2.fa";
	return $sim;
}

sub pick_fg {
	my $hashref = shift;
	my @fg = ();
	foreach my $seq_id (keys $hashref) {
		if ($seq_id =~ /^Fg/) {
			push @fg, $seq_id;
		}
	}
	return @fg;
}

sub has_edit_in_fg {
	my $fg_id = shift;
	if (exists $edit{$fg_id}) {
		return 1;
	} else {
		return 0;
	}
}

sub create_dir {
	system("rm -rf $output_dir");
	system("mkdir -p $output_dir");
	system("mkdir -p $output_dir/fas");
}

sub load_edit {
	my $file = shift;
	my %edit = ();
	my %site_num = ();
	open (IN, $file) or die "Cannot open file $file: $!\n";
	while (<IN>) {
		chomp;
		next if /^\#/;
		next if /^Chromosome/;
		next if /^\s*$/;
		my @w = split /\t/;
		my $gene_info = $w[7];
		my $gene_id = undef;
		my $edit_site = undef;
		$gene_info =~ s/\[//g;
		$gene_info =~ s/\]//g;
		if ($gene_info =~ /(\S+)\:\S\.(\d+)A\>G/) {
			$gene_id = $1;
			$edit_site = $2;
		} else {
			warn "invlaid edit site found in $_\n";
		}
		next unless (defined $gene_id);
		$gene_id = "Fg|" . $gene_id;
		if (! exists $site_num{$gene_id}) {
			$site_num{$gene_id} = 1;
		} else {
			$site_num{$gene_id}++;
		}
		$edit{$gene_id}{$site_num{$gene_id}} = $edit_site;
	}
	close IN;
	return %edit;
}

sub load_nal {
	my $dir = shift;
	my @nals = ();
	opendir(DIR, $dir) or die "Cannot open file $dir: $!\n";
	foreach my $file (readdir DIR) {
		next unless $file =~ /.aln$/;
		$file = $dir . "/" . $file; 
		push @nals, $file;
	}
	closedir DIR;
	return @nals;
}

sub nal2fasta {
	my $nal = shift;
	my $fas = shift;
	my %seq = ();
	return %seq if (-z $nal);
	my $in  = Bio::AlignIO->new(-file => $nal, -format => 'clustalw');
	my $out = Bio::AlignIO->new(-file => ">$fas", -format => 'fasta');
	my $aln = $in->next_aln();
	$out->write_aln($aln);
	%seq = load_fasta($fas);
	return %seq;
}

sub load_fasta {
	my $file = shift;
	my %seq = ();
	my $id = undef;
	open (FASTA, $file) or die $!;
	while (<FASTA>) {
		chomp;
		if (/^\>(\S+)\//) {
			$id = $1;
		} else {
			$seq{$id} .= $_;
		}
	}
	return %seq;
}

sub load_fungi {
	my %fungi = ();
	my @fungi = qw(Fg Fv Fs Ac Uv Cg Vd Sa Mo Nc Nt Sm Sb Pm Bc Ss Pp An Tr Ci Ep Pt Pn Dh Po Ca Sc Yl Sp Cn Pg Um);
	my $i = 0;
	foreach my $id (@fungi) {
		$fungi{$id} = $i;
		$i++;
	}
	return %fungi;
}

sub query_col {
	my $grp_id = shift;
	my $fg_id = shift;
	my $pos = shift;
	my $seqref = shift;
	# query bases
	foreach my $seq_id (sort by_fungi keys $seqref) {
		my $left = $num_flank_codon * 3 + ($pos+2) % 3;
		my $right = 2 - ($pos+2) % 3 + $num_flank_codon * 3;
		$phy_rna{$grp_id}{$fg_id}{$pos}{$seq_id} = "";
		for (my $i = $pos - $left; $i <= $pos + $right; $i++) {
			$phy{$grp_id}{$fg_id}{$pos}{$seq_id}{$i} = base_in_aln($seqref, $seq_id, $i, $fg_id);
			if ($i != $pos) {
				$phy{$grp_id}{$fg_id}{$pos}{$seq_id}{$i} = lc($phy{$grp_id}{$fg_id}{$pos}{$seq_id}{$i});
			} else {
				$phy_edit{$grp_id}{$fg_id}{$pos}{$seq_id} = $phy{$grp_id}{$fg_id}{$pos}{$seq_id}{$i};
			}
			$phy_rna{$grp_id}{$fg_id}{$pos}{$seq_id} .= $phy{$grp_id}{$fg_id}{$pos}{$seq_id}{$i};
		}
		$phy_aa{$grp_id}{$fg_id}{$pos}{$seq_id} = translate($phy_rna{$grp_id}{$fg_id}{$pos}{$seq_id});
	}
}

sub phy_var {
	my %type = ();
	foreach my $grp_id (keys %phy_edit) {
		foreach my $fg_id (keys $phy_edit{$grp_id}) {
			foreach my $pos (keys $phy_edit{$grp_id}{$fg_id}) {
				my @phy_edit = ();
				foreach my $seq_id (sort by_fungi keys $phy_edit{$grp_id}{$fg_id}{$pos}) {
					push @phy_edit, $phy_edit{$grp_id}{$fg_id}{$pos}{$seq_id};
				}
				$type{$grp_id}{$fg_id}{$pos} = classphy(@phy_edit);
			}
		}
	}
	return %type;
}

sub base_in_aln {
	my $seqref = shift;
	my $seq_id = shift;
	my $pos = shift;
	my $fg_id = shift;

	# refseq in FG, without gap
	my $fgseq0 = $seqref->{$fg_id};
	$fgseq0 =~ s/\-//g;
	my @fgseq0 = split //, $fgseq0;
	# refseq in FG, with gap
	my $fgseq = $seqref->{$fg_id};
	my @fgseq = split //, $fgseq;
	# cacualte gap number
	my $gap = 0;
	my $base = 'X';
	return $base if $pos >= @fgseq;
	for (my $i = 0; $i < $pos; $i++) {
		return $base if $i >= @fgseq0;
		if ($fgseq0[$i] ne $fgseq[$i+$gap]) {
			$gap++;
			$i--;
		}
	}
	my $pos_aln = $pos + $gap;
	my $seq = $seqref->{$seq_id};
	my @seq = split //, $seq;
	$base = $seq[$pos_aln -1];
	return $base;
}

sub by_num {
	$a <=> $b;
}

sub by_fungi {
	$fungi{substr($a,0,2)} <=> $fungi{substr($b,0,2)};
}

sub translate {
	my $seq = uc(shift);
	my $len = length $seq;
	my $aa = undef;
	for (my $i = 0; $i < $len; $i += 3) {
		$aa .= $codon_table{substr($seq, $i, 3)};
	}
	return $aa;
}

sub codon_table {
	my %table = (
    'TCA' => 'S',
    'TCC' => 'S',
    'TCG' => 'S',
    'TCT' => 'S',
    'TTC' => 'F',
    'TTT' => 'F',
    'TTA' => 'L',
    'TTG' => 'L',
    'TAC' => 'Y',
    'TAT' => 'Y',
    'TAA' => '*',
    'TAG' => '*',
    'TGC' => 'C',
    'TGT' => 'C',
    'TGA' => '*',
    'TGG' => 'W',
    'CTA' => 'L',
    'CTC' => 'L',
    'CTG' => 'L',
    'CTT' => 'L',
    'CCA' => 'P',
    'CCC' => 'P',
    'CCG' => 'P',
    'CCT' => 'P',
    'CAC' => 'H',
    'CAT' => 'H',
    'CAA' => 'Q',
    'CAG' => 'Q',
    'CGA' => 'R',
    'CGC' => 'R',
    'CGG' => 'R',
    'CGT' => 'R',
    'ATA' => 'I',
    'ATC' => 'I',
    'ATT' => 'I',
    'ATG' => 'M',
    'ACA' => 'T',
    'ACC' => 'T',
    'ACG' => 'T',
    'ACT' => 'T',
    'AAC' => 'N',
    'AAT' => 'N',
    'AAA' => 'K',
    'AAG' => 'K',
    'AGC' => 'S',
    'AGT' => 'S',
    'AGA' => 'R',
    'AGG' => 'R',
    'GTA' => 'V',
    'GTC' => 'V',
    'GTG' => 'V',
    'GTT' => 'V',
    'GCA' => 'A',
    'GCC' => 'A',
    'GCG' => 'A',
    'GCT' => 'A',
    'GAC' => 'D',
    'GAT' => 'D',
    'GAA' => 'E',
    'GAG' => 'E',
    'GGA' => 'G',
    'GGC' => 'G',
    'GGG' => 'G',
    'GGT' => 'G',
	'XXX' => '_',
	'---' => '-',
    );
	return %table;
}

sub classphy {
	my @edit = @_;
	my $type = "";
	my ($a, $t, $c, $g) = (0, 0, 0, 0);
	foreach my $base (@edit) {
		$base = uc($base);
		$a++ if $base eq 'A';
		$t++ if $base eq 'T';
		$c++ if $base eq 'C';
		$g++ if $base eq 'G';
	}
	if ($a + $c + $t + $g == 0) {
		$type = "unknown";
	} elsif ($a > 0 && $t == 0 && $c == 0 && $g == 0) {
		$type = "conserved";
	} elsif ($a > 0 && $t == 0 && $c == 0 && $g > 0) {
		$type = "hardwired";
	} elsif ($a > 0 && ($t > 0 or $c > 0) && $g == 0) {
		$type = "unfound";
	} elsif ($a > 0 && ($t > 0 or $c > 0) && $g > 0) {
		$type = "diversified";
	} else {
		$type = "unknown";
	}
	return $type;
}
