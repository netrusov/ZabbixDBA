## Configuration

Sample configuration file has the following syntax:

```
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
```

### zabbix

In this section you specify your Zabbix server address (hostname or IP), port, and connection timeout.

```
zabbix => {
    server  => '192.168.1.100',
    port    => 10051,
    timeout => 30,
}
```

### daemon

Here you can only specify one and only parameter - sleep. This will tell the main process how much should it sleep before starting new iteration (checks of dead connections, creating new thread, etc.).

```
daemon => {
    sleep => 120,
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
                                      
        sleep       => 30,            # specify how much thread should sleep
                                      # before starting new iteration (run queries against database)
                                      
        retry_count => 1              # number of iterations before connection will be restored after failure
    }
    list   => [ 'XXXPRD', 'XXXDEV' ], # list of database connections to use 
                                      # (you can exclude connections without deleting their configuration from file)
                                      
    XXXPRD => {                       # alias for your connection (will be used as host name to send to Zabbix)
    
        dsn              => 'DBI:Oracle:host=xxxdb11;port=1521;sid=XXXPRD',
                                      # database connection string
                                      # more information on https://metacpan.org/pod/DBI#parse_dsn
                                      
        extra_query_list => 'extra.query.props.pl'
                                      # file with queries that will be merged with main file
    }
}
```

**Values in default section will be overwritten by values in database section.**
