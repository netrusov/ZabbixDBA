{
    zabbix => {
        server  => '192.168.1.100',
        port    => 10051,
    },
    db => {
        default => {
            user        => 'zabbix',
            password    => 'zabbix',
            query_list  => 'query.props.pl',
        },
        list   => [ 'XXXPRD', 'XXXDEV' ],
        XXXPRD => {
            dsn => 'DBI:Oracle:host=xxxdb11;port=1521;sid=XXXPRD',
        },
        XXXDEV => {
            dsn  => 'DBI:Oracle:host=xxxdb01;port=1521;sid=XXXDEV',
            user => 'c##zabbix',
        },
        XXXTST => {
            dsn => 'DBI:Pg:database=xxxtst;host=xxxdb02;port=5432',
        }
    }
}
