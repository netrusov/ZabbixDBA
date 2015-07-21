#!/usr/bin/env perl

use strict;
use warnings;
use English qw(-no_match_vars);
use Carp qw(confess);

use File::Basename qw(dirname basename);
use File::Spec::Functions qw(catfile);
use WWW::Mechanize;
use MIME::Lite;

my $user      = 'Admin';
my $pass      = 's3cr3t';
my $login_url = 'http://zabbix01/zabbix';

my ( $to, $subject, $body ) = @ARGV;

my ($item_ids)
    = $body =~ m#<span style="display:none;" id="item_ids">(.*)</span>#ms;
my ($status) = $body =~ m#<th id="status">(\w+)</th>#ms;

if ($status) {
    my $style = 'background-color: forestgreen; color: white;';
    if ( $status ne 'OK' ) {
        $style = 'background-color: red;';
    }
    $body =~ s#<tr id="top">#<tr id="top" style="${style}">#ms;
}

my $message = <<"EOF";
<!DOCTYPE html>
<html>
<head lang="en">
    <meta charset="UTF-8">
</head>
<body>
    ${body}
    <br>
EOF

my ( $graph_url, $graph_png );

my @items = grep { !m/UNKNOWN/ms } split m/,/ms, $item_ids;

if (@items) {
    $graph_url = sprintf q{%s/chart.php?%s}, $login_url, join q{&},
        map { sprintf 'itemids[]=%d', $_ } @items;

    $graph_png = catfile( dirname($PROGRAM_NAME),
        sprintf( '.chart%d.png', $PROCESS_ID ) );

    if ( -f $graph_png ) {
        unlink $graph_png;
    }

    my $a = WWW::Mechanize->new();
    $a->get($login_url);

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

if ($graph_png) {
    $msg->attach(
        Type => 'image/png',
        Path => $graph_png,
        Id   => basename($graph_png),
    );
}

$msg->send;

if ($graph_png) {
    unlink $graph_png;
}
