#!/usr/bin/env perl

use strict;
use warnings;
use English qw(-no_match_vars);
use Carp qw(confess);

use File::Basename qw(dirname basename);
use File::Spec::Functions qw(catfile);
use WWW::Mechanize;
use MIME::Lite;

my $user = 'Admin';
my $pass = 's3cr3t';
my $url  = 'http://zabbix01/zabbix';

my ( $to, $subject, $body ) = @ARGV;

my ($item_id) = $body =~ m#<td id="item_id">(\d+)</td>#xms;
my ($status)  = $body =~ m#<th id="status">(\w+)</th>#xms;

if ($status) {
    my $style = 'background-color: forestgreen; color: white;';
    if ( $status ne 'OK' ) {
        $style = 'background-color: red;';
    }
    $body =~ s#<tr id="top">#<tr id="top" style="${style}">#xms;
}

my $message = <<"EOF";
<!DOCTYPE html>
<html>
<head lang="en">
    <meta charset="UTF-8">
</head>
<body>
    <table id="info">
    ${body}
    </table>
<br>
EOF

my ( $graph_url, $graph_png );

if ($item_id) {
    $graph_url = sprintf q{%s/chart.php?itemids[]=%d}, $url, $item_id;
    $graph_png = catfile( dirname($PROGRAM_NAME),
        sprintf( 'chart%d.png', $item_id ) );

    if ( -f $graph_png ) {
        unlink $graph_png;
    }

    my $a = WWW::Mechanize->new();
    $a->get($url);

    $a->submit_form(
        form_number => 1,
        fields      => {
            name     => $user,
            password => $pass,
        },
        button => 'enter',
    );

    $a->get( $graph_url, ':content_file' => $graph_png, );
    $message .= sprintf q{<img src="cid:%s">}, basename($graph_png);
}

$message .= q{</body></html>};

my $msg = MIME::Lite->new(
    Encoding => '8bit',
    Type     => 'text/html; charset=UTF-8',
    To       => $to,
    Subject  => $subject,
    Data     => $message,
);

if ($item_id) {
    $msg->attach(
        Type => 'image/png',
        Path => $graph_png,
        Id   => basename($graph_png),
    );
}

$msg->send;

if ($item_id) {
    unlink $graph_png;
}
