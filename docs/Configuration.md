## Configuration

Sample configuration file has the following syntax:

```perl
{
    zabbix => {
        host    => '192.168.1.100',
        port    => 10051,
        timeout => 30,
    },
    daemon => {
        sleep => 120,
        split_logs => 1,
    },
    db => {
        default => {
            user        => 'zabbix',
            pass        => 'zabbix',
            query_list  => 'query.props.pl',
            sleep       => 30,
            retry_step  => 1,
        },
        list   => [ 'XXXPRD', 'XXXDEV' ],
        XXXPRD => {
            dsn        => 'DBI:Oracle:host=xxxdb11;port=1521;sid=XXXPRD',
            query_list => [qw|query.props.pl extra.query.props.pl|],
            sleep      => 15,
        },
        XXXDEV => {
            dsn  => 'DBI:Oracle:host=xxxdb01;port=1521;sid=XXXDEV',
            user => 'c##zabbix',
        },
        XXXTST => {
            dsn        => 'DBI:Pg:database=xxxtst;host=xxxdb02;port=5432',
            retry_step => 2,
        }
    }
}
```

### zabbix

In this section you specify your Zabbix server address (hostname or IP), port, and connection timeout.

```perl
zabbix => {
    host    => '192.168.1.100',
    port    => 10051,
    timeout => 30,
}
```

### daemon

At `daemon` section you specify:
- `sleep` - this will tell the main process how much it should sleep before starting next iteration (checks of dead connections, creating new thread, etc.);
- `split_logs` - tell ZDBA to split logs by threads (one per each monitoring thread). See notes at [conf/log4perl.conf](../conf/log4perl.conf)

```perl
daemon => {
    sleep => 120,
    split_logs => 1,
}
```

### db

And the main section is "db" where you configure connections to your databases.

```perl
db => {
    default => {
        user        => 'zabbix',      # database user name
        pass        => 'zabbix',      # database user password

        query_list  => 'query.props.pl',
                                      # file with queries

        sleep       => 30,            # specify how much thread should sleep
                                      # before starting new iteration (run queries against database)

        retry_step  => 1              # number of iterations before connection will be restored after failure
    }
    list   => [ 'XXXPRD', 'XXXDEV' ], # list of database connections to use
                                      # (you can exclude connections without deleting their configuration from file)

    XXXPRD => {                       # alias for your connection (will be used as host name to send to Zabbix)

        dsn        => 'DBI:Oracle:host=xxxdb11;port=1521;sid=XXXPRD',
                                      # database connection string
                                      # more information on https://metacpan.org/pod/DBI#parse_dsn

        query_list => [qw|query.props.pl extra.query.props.pl|],
                                      # if you want to use additional query list
                                      # you can specify an array of files (paths are relative to config file)
    }
}
```

**Values in default section will be overwritten by values in database section.**
