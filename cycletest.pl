#!/usr/bin/perl -w

use strict;

my %pdeps = (
  a => [qw/c b/],
  b => [qw/c/],
  c => [qw/a/],
);

my $prj = shift @ARGV;
if ($prj) {
  open(F, '<', "output/$prj/dep1") || die "$!\n";
  eval(join('', <F>));
  die if $@;
  close F;
}

use Dfs;
my $self = new Dfs(\%pdeps);
$self->startrdfs('a');

use Data::Dumper;

my %cycles = $self->findcycles(@ARGV);
print STDERR Dumper(\%cycles);

print "strict digraph pkgdeps {\n";
for my $c (reverse sort(keys %cycles)) {
  my @c = @{$cycles{$c}};
  print "# $c\n";
  print '"', join('" -> "', @c), "\"\n";
  printf ("\"%s\" -> \"%s\";\n", $c[-1], $c[0]);
}
print "}\n";
