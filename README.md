## ZabbixDBA
ZabbixDBA is fast, flexible, and continuously developing plugin to monitor your RDBMS.

ZabbixDBA uses threading of DBI connections which is good for monitoring of multiple database instances simultaneously. Just configure it, run daemon and it will do all the job.
Currently there are template and query set only for Oracle database, but Perl DBI supports any type of RDBMS:
- Oracle
- MySQL
- MS SQL
- PostgreSQL
- DB2, etc.

You can find full list of DBD modules here: https://metacpan.org/search?q=DBD

This plugin tested with Oracle, PostgreSQL, and MySQL, and it's 100% compatible with them (but be sure to install appropriate drivers and `DBD::...` module)

Feel free to fork and contribute!

## WARNING
This is new rewritten version of an application.
Please carefully read changelog at [release](https://github.com/anetrusov/ZabbixDBA/releases) tab.
To update to the newest version you must do the following:
```
git fetch
git reset --hard origin/master
```

#### Installation
Copy project source to desired directory.
**If path will differ from default (`/opt/zdba`) be sure to change it in startup script.**

- Open **[init.d/zdba](init.d/zdba)** file and carefully check all paths.
- Put this scrip to `/etc/init.d` directory and allow ZabbixDBA to run automatically on system startup
```
cp init.d/zdba /etc/init.d
chmod +x /etc/init.d/zdba
/sbin/chkconfig zdba on     # enable automatic startup/shutdown
```

To install all Perl requirements execute the following in plugin directory:
```
cpanm --installdeps /opt/zdba
```

#### Usage
```
/sbin/service zdba {start|stop|restart|reload|status}
```
After service startup you can monitor logfiles:
- `log/zdba.log` - main logfile
- `log/zdba.err` - errors that were not caught by logger

You can also enable `DEBUG` log mode at `conf/log4perl.conf`

#### Configuration
1. Create user `ZABBIX` (or whatever you want) in database.
2. Grant him privileges regarding your privacy policy.
3. Add your database credentials just like described in **[conf/config.example.pl](conf/config.example.pl)** (see more [here](docs/Configuration.md)).

#### Features

- [Discovery Rules](docs/DiscoveryRules.md)
- [Bind Values](https://metacpan.org/pod/DBI#Placeholders-and-Bind-Values)
- [Log4perl](https://metacpan.org/pod/Log::Log4perl)



```
COPYRIGHT AND LICENSE
    Copyright 2014-2017 by Alexander Netrusov <alexander.netrusov@gmail.com>

    This program is free software; you can redistribute it and/or modify it
    under the same terms as Perl itself.
```
