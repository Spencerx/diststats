#!/usr/bin/perl -w
# print dot file

use strict;

my $firstcycle = '';

my $printreversed = 0;
my $parenttreeonly = 1;
my $colorizeparenttree = 1;
my $printloops = 0;
my $printranks = 1;
my $loopsonly = 0;

sub hhmm {
  my $t = shift || 0;
  $t /= 60;
  return sprintf("%02d:%02d", int($t / 60), $t % 60);
}

print STDERR "start dfs\n";

my %prereqs;
my %depors;

my $dist = shift @ARGV;

die("No dist specified!\n") unless $dist && $dist ne '';
my $ddir = $dist;
$ddir =~ s,/,_,g;
$ddir = "output/$ddir";

my $packalias = {};
my %buildtime;
my %pdeps;
my @packs_to_setup;

# change to dep1 here to use graph that still has cycles
open(IN, '<', "$ddir/deps") || die "$!";
while (<IN>) {
    chomp;
    my @a = split(/ /);
    if ($a[0] eq 'a') {
	$packalias->{$a[1]} = $a[2];
    } elsif ($a[0] eq 'b') {
	$buildtime{$a[1]} = $a[2];
	$pdeps{$a[1]} = [@a[3 .. $#a]];
	push @packs_to_setup, $a[1] unless $a[1] =~ /,/;
    }
}
close IN;

my %finished;
{
    my $numpacks;
    my %nbuild;
    my %nwait;
    my %needed;
    my $file = "$ddir/simul";

    if (open(IN, '<', $file)) {
	while (<IN>) {
	    chomp;
	    my @a = split(/ /);
	    if ($a[0] eq 'n') {
		$numpacks = $a[1];
	    } elsif ($a[0] eq 't') {
		$nbuild{$a[1]} = $a[2];
		$nwait{$a[1]} = $a[3];
	    } elsif ($a[0] eq 'f') {
		$finished{$a[1]} = $a[2];
	    }
	}
	close IN;
    } else {
	warn "$file: $!\n";
    }
}

my @ipackages = splice @ARGV;
use Dfs;
$Dfs::warnings = 0;
my $self = new Dfs(\%pdeps);
$self->starttarjan(@ipackages);
my %cycles = $self->findcycles();
# print STDERR Dumper(\%cycles);
for my $c (keys %cycles) {
    printf STDERR "cycle %d: %s\n", $c, join(',', sort(@{$cycles{$c}}));
    for my $p (@{$cycles{$c}}) {
	$cycles{$p} = 1;
    }
    delete $cycles{$c};
}

$self->startrdfs(@ipackages);

#exit (0);

my %highlight;
if (0) {
    my @list = reverse qw/gcc45 bison gpm ncurses perl perl-gettext help2man texinfo/;
    for (my $i=0; $i < @list; ++$i) {
	$highlight{$list[$i]} = $list[($i+1)%@list];
    }
}


my $alias = {};
$alias->{$firstcycle} = 'basepacks';

use Data::Dumper;
#print STDERR Dumper($self->{'parent'});

print "digraph pkgdeps {\n";
#print "rankdir=LR\n";
my @addnodes;
for (@ipackages)
{
    print "\"$_\" [style=filled, color=green]\n";
    if(!exists $self->{'parent'}->{$_})
    {
	push @addnodes,$_;
    }
}

if ($printreversed == 0)
{
    for my $node (keys %{$self->{'parent'}}, @addnodes)
    {
	next if ($loopsonly && !$cycles{$node});
	{
	    my $nn = $node;
	    $nn = $alias->{$nn} if exists $alias->{$nn};
	    #$nn .= sprintf '\n%d/%d', $self->{'begintime'}->{$node}, $self->{'endtime'}->{$node};
	    if (exists $finished{$node}) {
		$nn .= '\n'.hhmm($finished{$node});
	    }
	    print "\"$node\" [label=\"$nn\"]\n";
	}
	if($parenttreeonly==0)
	{
	    for my $node2 (@{$self->{'nodes'}->{$node}})
	    {
		next if ($loopsonly && !$cycles{$node2});
		print "\"$node\" -> \"",$node2,"\"";
		if($colorizeparenttree==1)
		{
		    print " [color=";
		    if(exists $self->{'parent'}->{$node2} && $self->{'parent'}->{$node2} eq $node)
		    {
			print "red";
		    }
		    else
		    {
			print "black";
			if( exists $self->{'endtime'}->{$node2} && $self->{'endtime'}->{$node2} > $self->{'endtime'}->{$node} )
			{
			    print ", style=dotted";
#			print STDERR "loop detected $node -> $node2\n";
			}
		    }
		    if ($highlight{$node} && $highlight{$node} eq $node2) {
			print ", style=bold";
		    }
		    if(exists $depors{$node})
		    {
			my $num = scalar grep {($node2 eq $_)} @{$depors{$node}};
			if ($num > 0)
			{
			    print ", style=dashed";
			}
		    }
		    if(exists $prereqs{$node} && 0 < grep {($node2 eq $_)} @{$prereqs{$node}} )
		    {
			print ", style=dotted";
		    }

		    print "]";
		}
		print "\n";
	    }
	}
	# need to check since ipackages are not in %parent
	elsif (exists $self->{'parent'}->{$node})
	{
	    my $node2=$self->{'parent'}->{$node};
	    next if ($loopsonly && !$cycles{$node2});
	    print "\"$node2\" -> \"",$node,"\"";
	    if(exists $depors{$node2})
	    {
		my $num = scalar grep {($node eq $_)} @{$depors{$node2}};
		if ($num > 0)
		{
		    print "[ style=dashed ]";
		}
	    }
	    print "\n";
	}
	if ($parenttreeonly && $printloops && exists $self->{'backwardedges'}->{$node})
	{
	    for my $node2 (@{$self->{'backwardedges'}->{$node}}) {
		next if ($loopsonly && !$cycles{$node2});
		print "\"$node\" -> \"",$node2,"\" [ style=dashed ]\n";
	    }
	}
    }
}
else
{
    for my $node (keys %{$self->{'reverseorder'}})
    {
	my $nn = $node;
	$nn = $alias->{$nn} if exists $alias->{$nn};
	print "\"$node\" [label=\"$nn\\n",$self->{'reverseorder'}->{$node},"\"]\n";
    }
    for my $node (keys %{$self->{'reversedgraph'}})
    {
	for my $node2 (@{$self->{'reversedgraph'}->{$node}})
	{
	    print "\"$node\" -> \"",$node2,"\"\n";
	}
    }
}

if (@{$self->{'topsorted'}}) {
    print STDERR "Topsort\n";
    for (@{$self->{'topsorted'}})
    {
	print STDERR " $_";
    }
    print STDERR "\n";
}

print STDERR "\nLeaf search\n";
#print STDERR Dumper($self->{'reversedgraph'});
my @nodestoinspect;
for my $node (keys %{$self->{'reverseorder'}})
{
    if($self->{'reverseorder'}->{$node}==0)
    {
	push @nodestoinspect, $node;
    }
}
while (@nodestoinspect)
{
    my $line = [];
    for my $node (splice @nodestoinspect)
    {
	my $nn = $node;
	$nn = $alias->{$nn} if exists $alias->{$nn};
	push @$line, $nn;
	for my $depnode (@{$self->{'reversedgraph'}->{$node}})
	{
	    $self->{'reverseorder'}->{$depnode}--;
	    push @nodestoinspect, $depnode if $self->{'reverseorder'}->{$depnode} == 0;
	}
	delete $self->{'reverseorder'}->{$node};
    }
    if ($printranks && @$line > 1) {
	print '{rank=same; "', join('" "', @$line), "\"}\n";
    }
    print STDERR '  ',join(' ', @$line),"\n";
}
print STDERR "\n";

print "}\n";

# vim:sw=4
