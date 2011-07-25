use 5.010;
use strict;
use warnings;
use utf8;
use autodie;


use Data::Dumper;
my $comment = qr{^\s*(?:\#.*)?$};

open my $f, '<:encoding(UTF-8)', 'features.txt';
my %abbr_name;
my %abbr_index;
my $index = 0;
my $in_abbr_section;
my @sections;

while (<$f>) {
    chomp;
    next if $_ ~~ $comment;
    if (/^=\s+(.*)/) {
        my $title = $1;
        if ($title eq 'ABBREVIATIONS') {
            $in_abbr_section = 1;
        } else {
            $in_abbr_section = 0;
            push @sections, [$title];
        }
    }
    else {
        if ($in_abbr_section) {
            my ($abbr, $name)  = split /\s+/, $_, 2;
            $abbr_name{$abbr}  = $name;
            $abbr_index{$abbr} = ++$index;
        }
        else {
            my ($name, $rest) = split /:\s*/, $_, 2;
            push @{$sections[-1]}, [$name];
            while ($rest =~ m/(\w+)([+-]+)\s*(?:\(([^()]+)\)\s*)?/g) {
                my ($abbr, $rating, $comment) = ($1, $2, $3);
                die "Unknown abbreviation '$abbr'"
                    unless exists $abbr_name{$abbr};
                my $i = $abbr_index{$abbr};
                die "Multiple data points for abbr '$abbr' at line $. -- possible typo?"
                    if $sections[-1][-1][$i];
                # TODO: don't throw away the comments;
                $sections[-1][-1][$i] = $rating;
            }
        }
    }
}

close $f;
write_html();

sub write_html {
    require HTML::Template::Compiled;
    my $t = HTML::Template::Compiled->new(
        filename        => 'template.html',
        open_mode       => ':encoding(UTF-8)',
        default_escape  => 'HTML',
        global_vars     => 1,
    );
    my @compilers;
    for (keys %abbr_index) {
        $compilers[$abbr_index{$_}] = {name => $abbr_name{$_}};
    }
    shift @compilers;
    $t->param(compilers => \@compilers);
    $t->param(columns   => 1 + @compilers);

    my %status_map = (
        '+'     => 'implemented',
        '+-'    => 'partial',
        '-'     => 'missing',
        ''      => 'unknown',
    );

    my @rows;
    for my $s (@sections) {
        my @sec = @$s;
        push @rows, {section => shift @sec};
        for (@sec) {
            my %ht_row;
            my @row = @$_;
            $ht_row{feature}  = shift @row;
            $ht_row{compilers} = [ map {
                {
                    status => $row[$_] // '',
                    class  => $status_map{$row[$_] // ''},
                }
            } 0..($index - 1) ];
            push @rows, \%ht_row;
        }
    }
    $t->param(rows => \@rows);
    say $t->output;
}
