{
    zabbix_server_list => ['zabbix01'],
    zabbix01           => {
        zabbix01 => '192.168.1.100',
        port     => 10051
    },
    daemon => { sleep => 120 },
    database_list => [ 'XXXPRD', 'XXXDEV' ],
    default       => {
        user            => 'zabbix',
        password        => 'zabbix',
        query_list_file => './conf/query.props.pl'
    },
    XXXPRD => { dsn => 'DBI:Oracle:host=xxxdb11;port=1521;sid=XXXPRD', },
    XXXDEV => {
        dsn  => 'DBI:Oracle:host=xxxdb01;port=1521;sid=XXXDEV',
        user => 'c##zabbix'
    }
}
