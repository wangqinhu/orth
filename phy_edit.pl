#!/usr/bin/perl

use strict;
use warnings;
use Bio::AlignIO;

#----------------------------------------------------------
# i/o setting
#----------------------------------------------------------
my $nal_dir = $ARGV[0] || "output/nal";
my $edit = $ARGV[1] || "data/nc.edit.id";
my $output_dir = $ARGV[2] || "output_dir";
my $num_flank_codon = 5;
my $pick_string = "Nc" || "Fg";
my @fungi = ();
if ($pick_string eq "Fg") {
	@fungi = qw(Fg Fv Fs Ac Uv Cg Vd Sa Mo Nc Nt Sm Sb Pm);
} elsif ($pick_string eq "Nc") {
	@fungi = qw(Nc Nt Sm Sb Pm Mo Fg Fv Fs Ac Uv Cg Vd Sa);
}

#----------------------------------------------------------
# global var
#----------------------------------------------------------
my %fungi = load_fungi();
my %codon_table = codon_table();
my %aa_list = aa_list();
my %edit = load_edit($edit);
my %phy = ();
my %phy_edit_nt = ();
my %phy_edit_aa = ();
my %phy_edit_aa_a2g = ();
my %phy_rna = ();
my %phy_aa = ();
my %nt_vt = ();
my %aa_vt = ();
my %aa_cs = ();

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
		# fg: origin stand for Fusarium graminearum (fg), now stand for the reference fungi gene (fg)
		my @fg = pick_fg(\%seq);
		next if @fg < 1;
		foreach my $fg_id (@fg) {
			if (has_edit_in_fg($fg_id)) {
				foreach my $pos (sort by_num keys $edit{$fg_id}) {
					my %seq_valid = %seq;
					%seq_valid = remove_redundancy(\%seq_valid, $fg_id);
					query_col($group, $fg_id, $pos, \%seq_valid);
				}
			}
		}
	}
	%nt_vt = nt_var();
	%aa_vt = aa_var();
	%aa_cs = aa_cs();
	analyze_phy_edit();
}

sub aa_cs {
	my %score = ();
	my $pwd = `pwd`;
	chomp $pwd;
	my $jsd_dir = $pwd . "/lib/score-conservation/scripts";
	my $aa_aln = "$output_dir/seq.aln";
	foreach my $grp_id (keys %phy_edit_nt) {
		foreach my $fg_id (keys $phy_edit_nt{$grp_id}) {
			foreach my $pos (keys $phy_edit_nt{$grp_id}{$fg_id}) {
				open (ALN, ">$aa_aln") or die "Cannot open file $aa_aln: $!\n";
				print ALN "CLUSTAL W\n";
				foreach my $seq_id (sort by_fungi keys $phy_edit_nt{$grp_id}{$fg_id}{$pos}) {
					print ALN substr($seq_id, 0, 2), "\t$phy_aa{$grp_id}{$fg_id}{$pos}{$seq_id}\n";
				}
				close ALN;
				my $jsd_out = `$jsd_dir/score_conservation.py -d $jsd_dir/distributions/blosum62.distribution -m $jsd_dir/matrix/blosum62.bla -w 0 $aa_aln`;
				my @jsd = split /\n/, $jsd_out;
				foreach my $line (@jsd) {
					next if $line =~ /^\#/;
					next if $line =~ /^\s*$/;
					my @w = split /\t/, $line;
					$score{$grp_id}{$fg_id}{$pos}{$w[0]} = $w[1];
				}
			}
		}
	}
	unlink "$aa_aln";
	return %score;
}

sub analyze_phy_edit {
	foreach my $grp_id (keys %phy_edit_nt) {
		foreach my $fg_id (keys $phy_edit_nt{$grp_id}) {
			foreach my $pos (keys $phy_edit_nt{$grp_id}{$fg_id}) {
				my ($fg, $fg_idc) = split /\|/, $fg_id;
				my $rel = sprintf "%2.2f", $edit{$fg_id}{$pos};
				my $cs_v = "";
				foreach my $item (sort by_num keys $aa_cs{$grp_id}{$fg_id}{$pos}) {
					$cs_v .= " " . $aa_cs{$grp_id}{$fg_id}{$pos}{$item};
				}
				print "# $grp_id $fg_idc $pos ";
				print "REL:$rel ";
				print "$nt_vt{$grp_id}{$fg_id}{$pos} ";
				print "$aa_vt{$grp_id}{$fg_id}{$pos} ";
				print "aa_cs:[$cs_v ]\n";
				foreach my $seq_id (sort by_fungi keys $phy_edit_nt{$grp_id}{$fg_id}{$pos}) {
					my ($tag, $seq_idc) = split /\|/, $seq_id;
					print "$tag\t";
					print "$phy_rna{$grp_id}{$fg_id}{$pos}{$seq_id}\t";
					print "$phy_aa{$grp_id}{$fg_id}{$pos}{$seq_id}\t";
					print "$seq_idc\n";
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
	my $tag = substr($fg_id, 0, 2);
	$once{$tag} = $fg_id;
	$seq{$fg_id} = $seqref->{$fg_id};
	foreach my $seq_id (keys $seqref) {
		$tag = substr($seq_id, 0, 2);
		if (!exists $once{$tag}) {
			$once{$tag} = $seq_id;
			$seq{$seq_id} = $seqref->{$seq_id};
		} else {
			my $sim_new = similarity($seqref->{$seq_id}, $seqref->{$fg_id});
			my $sim_old = similarity($seq{$once{$tag}}, $seqref->{$fg_id});
			if ($sim_new > $sim_old) {
				delete $seq{$once{$tag}};
				$once{$tag} = $seq_id;
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
	open (S1, ">$output_dir/seq1.fa") or die $!;
	print S1 ">a\n$seq1\n";
	close S1;
	open (S2, ">$output_dir/seq2.fa") or die $!;
	print S2 ">b\n$seq2\n";
	close S2;
	my $sw_align = `ssearch36 -3 -m 8 $output_dir/seq1.fa $output_dir/seq2.fa`;
	my @item = split /\s+/, $sw_align;
	my $sim = $item[2];
	unlink "$output_dir/seq1.fa";
	unlink "$output_dir/seq2.fa";
	return $sim;
}

sub pick_fg {
	my $hashref = shift;
	my @fg = ();
	foreach my $seq_id (keys $hashref) {
		if ($seq_id =~ /^$pick_string/) {
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
		$gene_id = "$pick_string|" . $gene_id;
		$edit{$gene_id}{$edit_site} = $w[6];
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
				$phy_edit_nt{$grp_id}{$fg_id}{$pos}{$seq_id} = $phy{$grp_id}{$fg_id}{$pos}{$seq_id}{$i};
			}
			$phy_rna{$grp_id}{$fg_id}{$pos}{$seq_id} .= $phy{$grp_id}{$fg_id}{$pos}{$seq_id}{$i};
		}
		$phy_aa{$grp_id}{$fg_id}{$pos}{$seq_id} = translate($phy_rna{$grp_id}{$fg_id}{$pos}{$seq_id});
		$phy_edit_aa{$grp_id}{$fg_id}{$pos}{$seq_id} = substr($phy_aa{$grp_id}{$fg_id}{$pos}{$seq_id}, $num_flank_codon, 1);
		if ($seq_id eq $fg_id) {
			my $aa_a2g = substr($phy_rna{$grp_id}{$fg_id}{$pos}{$seq_id}, 3 * $num_flank_codon, 3);
			$aa_a2g =~ s/A/G/;
			$aa_a2g = translate($aa_a2g);
			$phy_edit_aa_a2g{$grp_id}{$fg_id}{$pos} = $aa_a2g;
		}
	}
}

sub nt_var {
	my %type = ();
	foreach my $grp_id (keys %phy_edit_nt) {
		foreach my $fg_id (keys $phy_edit_nt{$grp_id}) {
			foreach my $pos (keys $phy_edit_nt{$grp_id}{$fg_id}) {
				my @phy_edit_nt = ();
				foreach my $seq_id (sort by_fungi keys $phy_edit_nt{$grp_id}{$fg_id}{$pos}) {
					push @phy_edit_nt, $phy_edit_nt{$grp_id}{$fg_id}{$pos}{$seq_id};
				}
				$type{$grp_id}{$fg_id}{$pos} = class_nt(@phy_edit_nt);
			}
		}
	}
	return %type;
}

sub aa_var {
	my %type = ();
	foreach my $grp_id (keys %phy_edit_aa) {
		foreach my $fg_id (keys $phy_edit_aa{$grp_id}) {
			foreach my $pos (keys $phy_edit_aa{$grp_id}{$fg_id}) {
				my @phy_edit_aa = ();
				foreach my $seq_id (sort by_fungi keys $phy_edit_aa{$grp_id}{$fg_id}{$pos}) {
					push @phy_edit_aa, $phy_edit_aa{$grp_id}{$fg_id}{$pos}{$seq_id};
				}
				my $aa_a2g = $phy_edit_aa_a2g{$grp_id}{$fg_id}{$pos};
				$type{$grp_id}{$fg_id}{$pos} = class_aa(\@phy_edit_aa, $aa_a2g);
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
	my $base = 'X';

	# refseq in FG, without gap
	my $fgseq0 = $seqref->{$fg_id};
	$fgseq0 =~ s/\-//g;
	my @fgseq0 = split //, $fgseq0;
	# refseq in FG, with gap
	my $fgseq = $seqref->{$fg_id};
	my @fgseq = split //, $fgseq;
	# cacualte gap number
	my $gap = 0;
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
		my $codon = substr($seq, $i, 3);
		if ($codon =~ /[A|T|C|G]{3}/) {
			$aa .= $codon_table{$codon};
		} else {
			$aa .= "-";
		}
	}
	return $aa;
}

sub class_nt {
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
	if ($a <= 1 && ($c + $t + $g == 0)) {
		$type = "NA";
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
	my $tot = $a+$t+$c+$g;
	$type .=  " ( A:$a G:$g C:$c T:$t / Total:$tot ) ";
	return "nt:$type";
}

sub aa_list {
	my %aa_list = ();
	my @aa = qw(A C D E F G H I K L M N P Q R S T V W Y);
	foreach my $aa (@aa) {
		$aa_list{$aa} = 1;
	}
	return %aa_list;
}

sub is_aa {
	my $char = shift;
	return 1 if exists $aa_list{$char};
	return 0;
}

sub class_aa {
	my $edit = shift;
	my @edit = @{$edit};
	my $aa_a2g = shift;
	my $aa_ref = $edit[0];
	my $type = "NA";

	return $type unless is_aa($aa_a2g);
	if ($aa_ref eq $aa_a2g) {
		$type = "syn";
		return "syn";
	} else {
		$type = "non";
	}

	my %edit = ($aa_ref => 0, $aa_a2g => 0, "other" => 0);
	foreach my $aa (@edit) {
		$aa = uc($aa);
		next unless is_aa($aa);
		if ($aa eq $aa_ref) {
			$edit{$aa_ref}++;
		} elsif ($aa eq $aa_a2g) {
			$edit{$aa_a2g}++;
		} else {
			$edit{"other"}++;
		}
	}

	if ($edit{$aa_ref} == 1 && $edit{$aa_a2g} == 0 && $edit{"other"} == 0) {
		$type = "NA";
	} elsif ($edit{$aa_ref} > 1 && $edit{$aa_a2g} == 0 && $edit{"other"} == 0) {
		$type = "conserved";
	} elsif ($edit{$aa_ref} >= 1 && $edit{$aa_a2g} >= 1 && $edit{"other"} == 0) {
		$type = "hardwired";
	} elsif ($edit{$aa_ref} >= 1 && $edit{$aa_a2g} == 0 && $edit{"other"} >= 1) {
		$type = "unfound";
	} elsif ($edit{$aa_ref} >= 1 && $edit{$aa_a2g} >= 1 && $edit{"other"} >= 1) {
		$type = "diversified";
	} else {
		$type = "unknown";
	}
	my $tot = $edit{$aa_ref}+$edit{$aa_a2g}+$edit{"other"};
	$type .=  " ( $aa_ref:$edit{$aa_ref} $aa_a2g:$edit{$aa_a2g} Other:$edit{'other'} / Total:$tot ) ";
	return "aa:$type";
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
    );
	return %table;
}
