package FixMyStreet::Cobrand::Alcala;
use base 'FixMyStreet::Cobrand::Default';

use utf8;
use strict;
use warnings;

sub is_council {
    1;
}

sub is_es_council {
    1;
}

sub language_override { 'es' }

#mapit id for Alcalá
sub council_id { return 579300; }
 
sub council_area { return 'Alcalá de Henares'; }
sub council_name { return 'Ayto. de Alcalá de Henares'; }
sub council_lat { return '40.4820'; }
sub council_lon { return '-3.3635'; }
#sub council_url { return 'bromley'; }

#sub reports_ordering {
#    return { -desc => 'confirmed' };
#}

sub pin_colour {
    my ( $self, $p, $context ) = @_;
    return 'grey' if $p->state eq 'not responsible';
    return 'green' if $p->is_fixed || $p->is_closed;
    return 'red' if $p->state eq 'confirmed';
    return 'yellow';
}


1;
