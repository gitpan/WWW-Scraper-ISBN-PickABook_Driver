package WWW::Scraper::ISBN::PickABook_Driver;

use strict;
use warnings;

use vars qw($VERSION @ISA);
$VERSION = '0.02';

#--------------------------------------------------------------------------

=head1 NAME

WWW::Scraper::ISBN::PickABook_Driver - Search driver for the Pick-A-Book online book catalog.

=head1 SYNOPSIS

See parent class documentation (L<WWW::Scraper::ISBN::Driver>)

=head1 DESCRIPTION

Searches for book information from the Pick-A-Book online book catalog.

=cut

#--------------------------------------------------------------------------

###########################################################################
# Inheritence

use base qw(WWW::Scraper::ISBN::Driver);

###########################################################################
# Modules

use WWW::Mechanize;

###########################################################################
# Constants

use constant	REFERER	=> 'http://www.pickabook.co.uk/';
use constant	SEARCH	=> 'http://www.pickabook.co.uk/%s.aspx?ToSearch=TRUE';
my ($URL1,$URL2) = ('http://www.PickABook.co.uk/book/','/[^?]+\?b=\-3\&amp;t=\-26\#Bibliographicdata\-26');

#--------------------------------------------------------------------------

###########################################################################
# Public Interface

=head1 METHODS

=over 4

=item C<search()>

Creates a query string, then passes the appropriate form fields to the 
Book Depository server.

The returned page should be the correct catalog page for that ISBN. If not the
function returns zero and allows the next driver in the chain to have a go. If
a valid page is returned, the following fields are returned via the book hash:

  isbn          (now returns isbn13)
  isbn10        
  isbn13
  ean13         (industry name)
  author
  title
  book_link
  image_link
  thumb_link
  description
  pubdate
  publisher
  binding       (if known)
  pages         (if known)

The book_link, image_link and thumb_link all refer back to the Pick-A-Book
website.

=cut

sub search {
	my $self = shift;
	my $isbn = shift;
	$self->found(0);
	$self->book(undef);

    # validate and convert into EAN13 format
    my $ean = $self->convert_to_ean13($isbn);
    return $self->handler("Invalid ISBN specified")   
        if(!$ean || (length $isbn == 13 && $isbn ne $ean)
                 || (length $isbn == 10 && $isbn ne $self->convert_to_isbn10($ean)));

	my $mech = WWW::Mechanize->new();
    $mech->agent_alias( 'Windows IE 6' );
    $mech->add_header( 'Accept-Encoding' => undef );
    $mech->add_header( 'Referer' => REFERER );

    my $search = sprintf SEARCH , $ean;
#print STDERR "\n# search=[$search]\n";

    eval { $mech->get( $search ) };
    return $self->handler("The Pick-A-Book website appears to be unavailable.")
	    if($@ || !$mech->success() || !$mech->content());

	# The Book page
    my $html = $mech->content();

	return $self->handler("Failed to find that book on the Pick-A-Book website. [$isbn]")
		if(!$html || $html =~ m!Your search for "[^"]+" has produced 0 results.!si);
    
    $html =~ s/&amp;/&/g;
#print STDERR "\n# content2=[\n$html\n]\n";

    my $data;
    ($data->{author},$data->{title})    
                            = $html =~ m!<span id="lblbooktitlevalue" title="([^"]+)"[^>]*>([^<]+)</span>!si;
    ($data->{binding})      = $html =~ m!<span id="lblbindingvalue"[^>]*>([^<]+)</span>!si;
    ($data->{isbn13})       = $html =~ m!<span id="lblisbn13"[^>]*>([^<]+)</span>!si;
    ($data->{isbn10})       = $html =~ m!<span id="lblISBNvalue"[^>]*>([^<]+)</span>!si;
    ($data->{publisher})    = $html =~ m!<span id="lblpublishervalue"[^>]*>([^<]+)</span>!si;
    ($data->{pubdate})      = $html =~ m!<span id="lblpublishdatevalue"[^>]*>([^<]+)</span>!si;
    ($data->{pages})        = $html =~ m!<span id="lblpagesvalue"[^>]*>([^<]+)</span>!si;
    ($data->{description})  = $html =~ m!<span id="lbldescriptionvalue"[^>]*>([^<]+)</span>!si;
    ($data->{isbn10})       = $html =~ m!<span id="lblISBNvalue"[^>]*>([^<]+)</span>!si;
    ($data->{image})        = $html =~ m!<input type="image" name="imgbook" id="imgbook" title="[^"]+" src="([^"]+)"[^>]*>!si;

    if($data->{image}) {
        $data->{image} = REFERER . $data->{image};
        $data->{thumb} = $data->{image};
    }
    $data->{author} =~ s/.*?\s+by\s+//      if($data->{author});
    $data->{publisher} =~ s/&#0?39;/'/g     if($data->{publisher});
    for(qw(title author publisher)) {
        next    unless($data->{$_});
        $data->{$_} =~ s/([\w']+)/\u\L$1/g;
    }

#use Data::Dumper;
#print STDERR "\n# " . Dumper($data);

	return $self->handler("Could not extract data from the Pick-A-Book result page.")
		unless(defined $data);

	# trim top and tail
	foreach (keys %$data) { 
        next unless(defined $data->{$_});
        $data->{$_} =~ s!&nbsp;! !g;
        $data->{$_} =~ s/^\s+//;
        $data->{$_} =~ s/\s+$//;
    }

    my $url = $mech->uri();

	my $bk = {
		'ean13'		    => $data->{isbn13},
		'isbn13'		=> $data->{isbn13},
		'isbn10'		=> $data->{isbn10},
		'isbn'			=> $data->{isbn13},
		'author'		=> $data->{author},
		'title'			=> $data->{title},
		'book_link'		=> $url,
		'image_link'	=> $data->{image},
		'thumb_link'	=> $data->{thumb},
		'description'	=> $data->{description},
		'pubdate'		=> $data->{pubdate},
		'publisher'		=> $data->{publisher},
		'binding'	    => $data->{binding},
		'pages'		    => $data->{pages},
	};

#use Data::Dumper;
#print STDERR "\n# book=".Dumper($bk);

    $self->book($bk);
	$self->found(1);
	return $self->book;
}

=item C<convert_to_ean13()>

Given a 10/13 character ISBN, this function will return the correct 13 digit
ISBN, also known as EAN13.

=item C<convert_to_isbn10()>

Given a 10/13 character ISBN, this function will return the correct 10 digit 
ISBN.

=back

=cut

sub convert_to_ean13 {
	my $self = shift;
    my $isbn = shift;
    my $prefix;

    return  unless(length $isbn == 10 || length $isbn == 13);

    if(length $isbn == 13) {
        return  if($isbn !~ /^(978|979)(\d{10})$/);
        ($prefix,$isbn) = ($1,$2);
    } else {
        return  if($isbn !~ /^(\d{10}|\d{9}X)$/);
        $prefix = '978';
    }

    my $isbn13 = '978' . $isbn;
    chop($isbn13);
    my @isbn = split(//,$isbn13);
    my ($lsum,$hsum) = (0,0);
    while(@isbn) {
        $hsum += shift @isbn;
        $lsum += shift @isbn;
    }

    my $csum = ($lsum * 3) + $hsum;
    $csum %= 10;
    $csum = 10 - $csum  if($csum != 0);

    return $isbn13 . $csum;
}

sub convert_to_isbn10 {
	my $self = shift;
    my $ean  = shift;
    my ($isbn,$isbn10);

    return  unless(length $ean == 10 || length $ean == 13);

    if(length $ean == 13) {
        return  if($ean !~ /^(?:978|979)(\d{9})\d$/);
        ($isbn,$isbn10) = ($1,$1);
    } else {
        return  if($ean !~ /^(\d{9})[\dX]$/);
        ($isbn,$isbn10) = ($1,$1);
    }

	return  if($isbn < 0 or $isbn > 999999999);

	my ($csum, $pos, $digit) = (0, 0, 0);
    for ($pos = 9; $pos > 0; $pos--) {
        $digit = $isbn % 10;
        $isbn /= 10;             # Decimal shift ISBN for next time 
        $csum += ($pos * $digit);
    }
    $csum %= 11;
    $csum = 'X'   if ($csum == 10);
    return $isbn10 . $csum;
}

1;

__END__

=head1 REQUIRES

Requires the following modules be installed:

L<WWW::Scraper::ISBN::Driver>,
L<WWW::Mechanize>

=head1 SEE ALSO

L<WWW::Scraper::ISBN>,
L<WWW::Scraper::ISBN::Record>,
L<WWW::Scraper::ISBN::Driver>

=head1 BUGS, PATCHES & FIXES

There are no known bugs at the time of this release. However, if you spot a
bug or are experiencing difficulties that are not explained within the POD
documentation, please send an email to barbie@cpan.org or submit a bug to the
RT system (http://rt.cpan.org/Public/Dist/Display.html?Name=WWW-Scraper-ISBN-PickABook_Driver).
However, it would help greatly if you are able to pinpoint problems or even
supply a patch.

Fixes are dependant upon their severity and my availablity. Should a fix not
be forthcoming, please feel free to (politely) remind me.

=head1 AUTHOR

  Barbie, <barbie@cpan.org>
  Miss Barbell Productions, <http://www.missbarbell.co.uk/>

=head1 COPYRIGHT & LICENSE

  Copyright (C) 2010,2011 Barbie for Miss Barbell Productions

  This module is free software; you can redistribute it and/or
  modify it under the Artistic Licence v2.

=cut
