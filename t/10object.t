#!/usr/bin/perl -w
use strict;

use lib './t';
use Test::More tests => 49;
use WWW::Scraper::ISBN;

###########################################################

my $DRIVER          = 'PickABook';
my $CHECK_DOMAIN    = 'www.google.com';

my %tests = (
    '1558607013' => [
        [ 'is',     'isbn',         '9781558607019'     ],
        [ 'is',     'isbn10',       '1558607013'        ],
        [ 'is',     'isbn13',       '9781558607019'     ],
        [ 'is',     'ean13',        '9781558607019'     ],
        [ 'is',     'title',        'Higher-Order Perl' ],
        [ 'is',     'author',       'Mark Jason Dominus'            ],
        [ 'is',     'publisher',    'Elsevier Science & Technology' ],
        [ 'is',     'pubdate',      '10 December, 2004' ],
        [ 'is',     'binding',      'Paperback'         ],
        [ 'is',     'pages',        '600'               ],
        [ 'is',     'image_link',   'http://www.pickabook.co.uk/CoverImages/2008_2_22_41\9781558607019.jpg' ],
        [ 'is',     'thumb_link',   'http://www.pickabook.co.uk/CoverImages/2008_2_22_41\9781558607019.jpg' ],
        [ 'like',   'description',  qr|Most Perl programmers were originally trained as C and Unix programmers,| ],
        [ 'is',     'book_link',    'http://www.pickabook.co.uk/9781558607019.aspx?ToSearch=TRUE' ]
    ],
    '0552557803' => [
        [ 'is',     'isbn',         '9780552557801'     ],
        [ 'is',     'isbn10',       '0552557803'        ],
        [ 'is',     'isbn13',       '9780552557801'     ],
        [ 'is',     'ean13',        '9780552557801'     ],
        [ 'is',     'title',        'Nation'            ],
        [ 'is',     'author',       'Terry Pratchett'   ],
        [ 'is',     'publisher',    'Random House Children\'s Books'    ],
        [ 'is',     'pubdate',      '1 October, 2020'   ],
        [ 'is',     'binding',      'Paperback'         ],
        [ 'is',     'image_link',   'http://www.pickabook.co.uk/CoverImages/nojacket.gif' ],
        [ 'is',     'thumb_link',   'http://www.pickabook.co.uk/CoverImages/nojacket.gif' ],
        [ 'like',   'description',  qr|Finding himself alone on a desert island| ],
        [ 'is',     'book_link',    'http://www.pickabook.co.uk/9780552557801.aspx?ToSearch=TRUE' ]
    ],
    '9780571239566' => [
        [ 'is',     'isbn',         '9780571239566'     ],
        [ 'is',     'isbn10',       '0571239560'        ],
        [ 'is',     'isbn13',       '9780571239566'     ],
        [ 'is',     'ean13',        '9780571239566'     ],
        [ 'is',     'title',        'Touching From A Distance'  ],
        [ 'is',     'author',       'Deborah Curtis'    ],
        [ 'is',     'publisher',    'Faber And Faber'   ],
        [ 'is',     'pubdate',      '4 October, 2007'   ],
        [ 'is',     'binding',      'Paperback'         ],
        [ 'is',     'pages',        240                 ],
        [ 'is',     'image_link',   'http://www.pickabook.co.uk/CoverImages/2008_2_22_67\9780571239566.jpg' ],
        [ 'is',     'thumb_link',   'http://www.pickabook.co.uk/CoverImages/2008_2_22_67\9780571239566.jpg' ],
        [ 'like',   'description',  qr|Ian Curtis left behind a legacy rich in artistic genius| ],
        [ 'is',     'book_link',    'http://www.pickabook.co.uk/9780571239566.aspx?ToSearch=TRUE' ]
    ],
);

my $tests = 0;
for my $isbn (keys %tests) { $tests += scalar( @{ $tests{$isbn} } ) + 2 }

###########################################################

my $scraper = WWW::Scraper::ISBN->new();
isa_ok($scraper,'WWW::Scraper::ISBN');

SKIP: {
	skip "Can't see a network connection", $tests+1   if(pingtest($CHECK_DOMAIN));

	$scraper->drivers($DRIVER);

    # this ISBN doesn't exist
	my $isbn = "098765432X";
    my $record;
    eval { $record = $scraper->search($isbn); };
    if($@) {
        like($@,qr/Invalid ISBN specified/);
    }
    elsif($record->found) {
        ok(0,'Unexpectedly found a non-existent book');
    } else {
		like($record->error,qr/Invalid ISBN specified|Failed to find that book|website appears to be unavailable/);
    }

    for my $isbn (keys %tests) {
        $record = $scraper->search($isbn);
        my $error  = $record->error || '';

        SKIP: {
            skip "Website unavailable", scalar(@{ $tests{$isbn} }) + 2   
                if($error =~ /website appears to be unavailable/);
            skip "Book unavailable", scalar(@{ $tests{$isbn} }) + 2   
                if($error =~ /Failed to find that book/ || !$record->found);

            unless($record->found) {
                diag($record->error);
            }

            is($record->found,1);
            is($record->found_in,$DRIVER);

            my $book = $record->book;
            for my $test (@{ $tests{$isbn} }) {
                if($test->[0] eq 'ok')          { ok(       $book->{$test->[1]},             ".. '$test->[1]' found [$isbn]"); } 
                elsif($test->[0] eq 'is')       { is(       $book->{$test->[1]}, $test->[2], ".. '$test->[1]' found [$isbn]"); } 
                elsif($test->[0] eq 'isnt')     { isnt(     $book->{$test->[1]}, $test->[2], ".. '$test->[1]' found [$isbn]"); } 
                elsif($test->[0] eq 'like')     { like(     $book->{$test->[1]}, $test->[2], ".. '$test->[1]' found [$isbn]"); } 
                elsif($test->[0] eq 'unlike')   { unlike(   $book->{$test->[1]}, $test->[2], ".. '$test->[1]' found [$isbn]"); }

            }

            #use Data::Dumper;
            #diag("book=[".Dumper($book)."]");
        }
    }
}

###########################################################

# crude, but it'll hopefully do ;)
sub pingtest {
    my $domain = shift or return 0;
    my $cmd =   $^O =~ /solaris/i                           ? "ping -s $domain 56 1" :
                $^O =~ /dos|os2|mswin32|netware|cygwin/i    ? "ping -n 1 $domain "
                                                            : "ping -c 1 $domain >/dev/null 2>&1";

    eval { system($cmd) }; 
    if($@) {                # can't find ping, or wrong arguments?
        diag();
        return 1;
    }

    my $retcode = $? >> 8;  # ping returns 1 if unable to connect
    return $retcode;
}
