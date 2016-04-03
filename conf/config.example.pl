{
    zabbix => {
        server  => '192.168.1.100',
        port    => 10051,
        timeout => 30,
    },
    daemon => {
        sleep => 120,
    },
    db => {
        default => {
            user        => 'zabbix',
            password    => 'zabbix',
            query_list  => 'query.props.pl',
            sleep       => 30,
            retry_count => 1,
        },
        list   => [ 'XXXPRD', 'XXXDEV' ],
        XXXPRD => {
            dsn              => 'DBI:Oracle:host=xxxdb11;port=1521;sid=XXXPRD',
            extra_query_list => 'extra.query.props.pl',
            sleep            => 15,
        },
        XXXDEV => {
            dsn  => 'DBI:Oracle:host=xxxdb01;port=1521;sid=XXXDEV',
            user => 'c##zabbix',
        },
        XXXTST => {
            dsn         => 'DBI:Pg:database=xxxtst;host=xxxdb02;port=5432',
            retry_count => 2,
        }
    }
}
