package FixMyStreet::Email;

use mySociety::Random qw(random_bytes);
use Utils::Email;
use FixMyStreet;
use FixMyStreet::EmailSend;

sub test_dmarc {
    my $email = shift;
    return if FixMyStreet->test_mode;
    return Utils::Email::test_dmarc($email);
}

sub _is_abuser {
    my ($schema, $email) = @_;
    my ($domain) = $email =~ m{ @ (.*) \z }x;
    return $schema->resultset('Abuse')->search( { email => [ $email, $domain ] } )->first;
}

sub send_cron {
    my ( $schema, $params, $env_from, $nomail, $cobrand, $lang_code ) = @_;

    my $sender = FixMyStreet->config('DO_NOT_REPLY_EMAIL');
    $env_from ||= $sender;
    if (!$params->{From}) {
        my $sender_name = $cobrand->contact_name;
        $params->{From} = [ $sender, _($sender_name) ];
    }

    my $first_to;
    if (ref($params->{To}) eq 'ARRAY') {
        if (ref($params->{To}[0]) eq 'ARRAY') {
            $first_to = $params->{To}[0][0];
        } else {
            $first_to = $params->{To}[0];
        }
    } else {
        $first_to = $params->{To};
    }
    return 1 if _is_abuser($schema, $first_to);

    $params->{'Message-ID'} = sprintf('<fms-cron-%s-%s@%s>', time(),
        unpack('h*', random_bytes(5, 1)), FixMyStreet->config('EMAIL_DOMAIN')
    );

    # This is all to set the path for the templates processor so we can override
    # signature and site names in emails using templates in the old style emails.
    # It's a bit involved as not everywhere we use it knows about the cobrand so
    # we can't assume there will be one.
    my $include_path = FixMyStreet->path_to( 'templates', 'email', 'default' )->stringify;
    if ( $cobrand ) {
        $include_path =
            FixMyStreet->path_to( 'templates', 'email', $cobrand->moniker )->stringify . ':'
            . $include_path;
        if ( $lang_code ) {
            $include_path =
                FixMyStreet->path_to( 'templates', 'email', $cobrand->moniker, $lang_code )->stringify . ':'
                . $include_path;
        }
    }
    my $tt = Template->new({
        INCLUDE_PATH => $include_path
    });
    my ($sig, $site_name);
    $tt->process( 'signature.txt', $params, \$sig );
    $sig = Encode::decode('utf8', $sig);
    $params->{_parameters_}->{signature} = $sig;

    $tt->process( 'site-name.txt', $params, \$site_name );
    $site_name = Utils::trim_text(Encode::decode('utf8', $site_name));
    $params->{_parameters_}->{site_name} = $site_name;

    $params->{_line_indent} = '';
    my $email = mySociety::Locale::in_gb_locale { mySociety::Email::construct_email($params) };

    if ($nomail) {
        print $email;
        return 1; # Failure
    } else {
        my %model_args;
        if (!FixMyStreet->test_mode && $env_from eq FixMyStreet->config('CONTACT_EMAIL')) {
            $model_args{mailer} = 'FixMyStreet::EmailSend::ContactEmail';
        }
        my $result = FixMyStreet::EmailSend->new(%model_args)->send($email);
        return $result ? 0 : 1;
    }
}

1;
