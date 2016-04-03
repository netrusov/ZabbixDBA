{
    zabbix => {
        server  => '192.168.1.100',
        port    => 10051,
        timeout => 30,
    },
    daemon => {
        sleep       => 120,
        maxproc     => 20,
        retry_count => 1,
    },
    db => {
        default => {
            user       => 'zabbix',
            password   => 'zabbix',
            query_list => 'query.props.pl'
        },
        list   => [ 'XXXPRD', 'XXXDEV' ],
        XXXPRD => {
            dsn              => 'DBI:Oracle:host=xxxdb11;port=1521;sid=XXXPRD',
            extra_query_list => 'extra.query.props.pl',
            sleep            => 60,
        },
        XXXDEV => {
            dsn  => 'DBI:Oracle:host=xxxdb01;port=1521;sid=XXXDEV',
            user => 'c##zabbix',
        },
        XXXTST => {
            dsn         => 'DBI:Oracle:host=xxxdb02;port=1521;sid=XXXTST',
            retry_count => 2,
        }
    }
}
