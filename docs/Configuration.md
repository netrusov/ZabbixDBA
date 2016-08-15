## Configuration

Sample configuration file has the following syntax:

```
{
    zabbix => {
        host    => '192.168.1.100',
        port    => 10051
    },
    db => {
        default => {
            user        => 'zabbix',
            password    => 'zabbix',
            query_list  => 'query.props.pl'
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
            dsn         => 'DBI:Pg:database=xxxtst;host=xxxdb02;port=5432',
        }
    }
}
```

### zabbix

In this section you specify your Zabbix server address (hostname or IP) and port.

```
zabbix => {
    host    => '192.168.1.100',
    port    => 10051
}
```

### db

And the main section is "db" where you configure connections to your databases.

```
db => {
    default => {
        user        => 'zabbix',      # database user name
        password    => 'zabbix',      # database user password
        
        query_list  => 'query.props.pl',
                                      # file with queries
    }
    list   => [ 'XXXPRD', 'XXXDEV' ], # list of database connections to use 
                                      # (you can exclude connections without deleting their configuration from file)
                                      
    XXXPRD => {                       # alias for your connection (will be used as host name to send to Zabbix)
    
        dsn              => 'DBI:Oracle:host=xxxdb11;port=1521;sid=XXXPRD',
                                      # database connection string
                                      # more information on https://metacpan.org/pod/DBI#parse_dsn
    }
}
```

**Values in default section will be overwritten by values in database section.**
