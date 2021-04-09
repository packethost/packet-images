use strict;
use File::Rename ();

@ARGV = map glob, @ARGV if $^O =~ /Win/;

File::Rename::rename @ARGV, { _code => sub { $_ = lc }, verbose => 1 };

