package Blitz::API;

use strict;
use warnings;

use LWP;
use Data::Dump qw(dump);
use JSON::XS;
use MIME::Base64;

=head1 NAME

Blitz::API - Perl module for API access to Blitz

=cut

sub client {
    my $this = shift;
    my $creds = shift;
    my $self = {
        credentials => $creds,
        job_id => undef,
    };
    bless $self;
    return $self;
}

sub _make_url {
    my $self = shift;
    my $path = shift;
    my $url = "http://" . $self->{credentials}{host}; # fix for https later?
    $url .= ":$self->{credentials}{port}" if $self->{credentials}{port} != 80;
    $url .= $path if $path;
    return $url;
}

sub _http_get {
    my $self = shift;
    my $path = shift;
    my $browser = LWP::UserAgent->new;
    my $url = _make_url($self, $path);
    my $response = $browser->get($url,
        'X-API-User'   => $self->{credentials}{username},
        'X-API-Key'    => $self->{credentials}{api_key},
        'X-API-Client' => 'Perl',
    );
    
    return $response;
}

=head2 _decode_result

Decode the JSON result object from Blitz
Decode base64 response in content areas of request and response

=cut

sub _decode_response {
    my $self = shift;
    my $response = shift;
    my $return = {};
    if ( $response->{_rc} != 200 ) {
        $return->{error} = 'server';
        $return->{cause} = $response->code();
    }
    else {
        $return = decode_json($response->{_content});
        for my $key ('request', 'response') {
            if ($return->{result}) {
                if ($return->{result}{$key} && $return->{result}{$key}{content}) {
                    $return->{result}{$key}{content} = decode_base64($return->{result}{$key}{content});    
                }    
            }
        }
    }
# XXX for DEBUG
#    print STDERR "----\n";
#    Data::Dump::dump($return);
#    print STDERR "----\n";

    return $return;
}

sub login {
    my $self = shift;
    my $closure = shift;
    
    my $response = _http_get($self, '/login/api');
    my $result = _decode_response($self, $response);

    if ($closure) {
        &$closure($self, $result);
    }
    return $result;
}

sub job_id {
    my $self = shift;
    my $job_id = shift;
    $self->{job_id} = $job_id if $job_id;
    return $self->{job_id};
}

sub job_status {

    my $self = shift;
    my $job_id = $self->job_id;
    my $closure = $self->{callback};
    
    my $request = 'api/1/jobs' . $job_id . '/status';
    my $response = _http_get($self, $request);
    
    my $result = _decode_response($self, $response);

    if ($closure) {
        &$closure($self, $result);
    }
    return $result;
}

# client object getter/setter for api_key
# necessary?
sub api_key {
    my $self = shift;
    my $api_key = shift;
    if ($api_key) {
        $self->{credentials}{api_key} = $api_key;
    }
    return $self->{credentials}{api_key};
}

sub start_job {
    my $self = shift;
    my $data = shift;
    my $closure = $self->{callback};
    
    $data = encode_json($data);
    
    my $browser = LWP::UserAgent->new;
    my $url = _make_url($self, '/api/1/curl/execute');
    
    my $response = $browser->post($url,
        'X-API-User'     => $self->{credentials}{username},
        'X-API-Key'      => $self->{credentials}{api_key},
        'X-API-Client'   => 'Perl',
        'content-length' => length($data),
        Content          => $data,
    );

    my $result = _decode_response($self, $response);

    if ($closure) {
        &$closure($self, $result);
    }
    return $result;
}

sub abort {
    my $self = shift;
    my $job_id = shift;
    my $closure = shift;
    
    my $browser = LWP::UserAgent->new;
    
    my $path = '/api/1/jobs/' . $job_id . '/abort';
    my $url = _make_url($self, $path);
    
    # Create a request
    my $req = HTTP::Request->new(PUT => $url);
    
    # Pass request to the user agent and get a response back
    my $response = $browser->request($req);
    my $result = _decode_response($response);

    if ($closure) {
        &$closure($self, $result);
    }
    return $result;
}

return 1;
