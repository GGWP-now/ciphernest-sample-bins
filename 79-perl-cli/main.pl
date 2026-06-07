#!/usr/bin/perl
# Perl CLI Victim -- Prime Sieve + Fibonacci
# Run: perl main.pl [limit]
use strict;
use warnings;
use integer;

sub fib {
    my ($n) = @_;
    return $n if $n <= 1;
    my ($a, $b) = (0, 1);
    for (2 .. $n) {
        ($a, $b) = ($b, $a + $b);
    }
    return $b;
}

my $limit = 100;
if (@ARGV && $ARGV[0] =~ /^\d+$/) {
    $limit = $ARGV[0];
    $limit = 10 if $limit < 10;
}

print "Perl CLI Victim -- Prime Sieve + Fibonacci\n";
print "Limit: $limit\n\n";
print "Fibonacci($limit) = ", fib($limit), "\n";

my @buf = (0) x ($limit + 1);
for (my $i = 2; $i * $i <= $limit; $i++) {
    next if $buf[$i];
    for (my $j = $i * $i; $j <= $limit; $j += $i) {
        $buf[$j] = 1;
    }
}

my $count   = 0;
my $largest = 0;
my $hash    = 5381;
for my $n (2 .. $limit) {
    next if $buf[$n];
    $count++;
    $largest = $n;
    # use integer => native 64-bit wraparound, matching the other victims
    $hash = ($hash << 5) + $hash + $n;
}

print "Primes up to $limit: $count\n";
print "Largest prime: $largest\n" if $count > 0;

my $fname = "perl_cli_test.txt";
if (open(my $fh, '>', $fname)) {
    print $fh "Perl CLI Victim -- $count primes up to $limit\n";
    close($fh);
    if (open(my $rh, '<', $fname)) {
        my $line = <$rh>;
        close($rh);
        print "File I/O: $line";
    }
    unlink($fname);
}

printf "Checksum: 0x%016X\n", $hash;
