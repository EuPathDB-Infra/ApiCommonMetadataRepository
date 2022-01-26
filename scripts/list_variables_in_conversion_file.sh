perl -MText::CSV=csv -E '
die "Usage: $0 <csv" unless @ARGV;
my ($aoah, @aoa) = @{csv(in => shift @ARGV)};
die "Third column should be a variable!" unless $aoah->[2] eq "variable"; 
say for grep {$_} map {$_->[2]} @aoa

' "$@" | sort
