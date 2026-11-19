#!/usr/bin/perl
# Divide um script GDScript grande numa cadeia de herança em camadas (refatoração mecânica).
# Uso: perl tools/split_gd.pl scripts/x.gd plano.txt
# plano.txt — uma camada por linha, da base pro topo:
#   arquivo.gd|extends da base (só na 1ª linha)|doc da camada|func1 func2 ...
# Regras: const/var/static var/signal/enum vão TODOS pra 1ª camada (a base); cada função vai
# pra camada listada; o que não estiver listado fica no arquivo original, que passa a
# estender a última camada. Comentários "##"/"#" colados acima de um item vão junto com ele.
use strict; use warnings;
my ($src, $plan) = @ARGV;
open my $fh, '<:raw', $src or die "sem $src"; my @L = <$fh>; close $fh;
open my $ph, '<:raw', $plan or die "sem $plan"; my @P = grep { /\S/ } <$ph>; close $ph;

my @decl;  # índices de linhas de declaração de topo
for my $i (0..$#L) {
	my $l = $L[$i];
	# só declarações de topo (o "]" que fecha uma constante de várias linhas não conta)
	next unless $l =~ /^(?:\@\w+\s+)*(?:static\s+)?(?:func|var|const|signal|enum)\b/;
	push @decl, $i;
}
die "nada pra dividir" unless @decl;
# início de cada bloco = sobe pelos comentários/linhas vazias de coluna 0 logo acima
my @start;
for my $d (@decl) {
	my $s = $d;
	while ($s > 0 && ($L[$s-1] =~ /^#/ || $L[$s-1] =~ /^\r?\n$/)) { $s--; }
	push @start, $s;
}
# o cabeçalho (extends + doc) termina no 1º bloco; os comentários de seção logo acima do 1º item
# ficam no bloco
my $hdr_end = $start[0];
my @blocks;
for my $k (0..$#decl) {
	my $s = $start[$k];
	$s = $decl[$k] if $k == 0 && $s < $hdr_end;
	my $e = $k < $#decl ? $start[$k+1] - 1 : $#L;
	my $line = $L[$decl[$k]];
	my ($kind, $name) = ('other', '');
	if ($line =~ /^(?:static\s+)?func\s+(\w+)/) { ($kind, $name) = ('func', $1); }
	elsif ($line =~ /^(?:\@\w+\s+)*(?:static\s+)?(?:var|const|signal|enum)\b\s*(\w*)/) { ($kind, $name) = ('data', $1); }
	push @blocks, { kind => $kind, name => $name, text => join('', @L[$s..$e]) };
}
my @layers;
for my $p (@P) {
	chomp $p; $p =~ s/\r//;
	my ($file, $ext, $doc, $names) = split /\|/, $p, 4;
	push @layers, { file => $file, ext => $ext, doc => $doc, names => { map { $_ => 1 } split ' ', ($names // '') }, out => '' };
}
my $rest = '';
for my $b (@blocks) {
	if ($b->{kind} eq 'data') { $layers[0]{out} .= $b->{text}; next; }
	my $placed = 0;
	for my $ly (@layers) { if ($ly->{names}{$b->{name}}) { $ly->{out} .= $b->{text}; $placed = 1; last; } }
	$rest .= $b->{text} unless $placed;
}
my $dir = $src; $dir =~ s{[^/]+$}{};
my $prev = '';
for my $i (0..$#layers) {
	my $ly = $layers[$i];
	my $ext = $i == 0 ? $ly->{ext} : "\"res://$dir$prev\"";  # caminho relativo à pasta do original
	my $sub = "$dir$ly->{file}"; $sub =~ s{[^/]+$}{};
	mkdir $sub unless -d $sub;
	my $txt = "extends $ext\n## $ly->{doc}\n## (camada de " . ($src =~ s{.*/}{}r) . " — ver o topo de " . ($src =~ s{.*/}{}r) . ")\n\n" . $ly->{out};
	$txt =~ s/\n{3,}/\n\n\n/g;
	open my $o, '>:raw', "$dir$ly->{file}" or die; print $o $txt; close $o;
	$prev = $ly->{file};
}
# arquivo original: cabeçalho com o novo extends + o que sobrou
my $head = join('', @L[0..$hdr_end-1]);
$head =~ s/^extends .*$/extends "res:\/\/$dir$prev"/m;
open my $o, '>:raw', $src or die; print $o $head . $rest; close $o;
printf "%s: %d blocos; camadas: %s\n", $src, scalar(@blocks), join(', ', map { $_->{file} } @layers);
