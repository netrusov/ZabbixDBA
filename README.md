## ZabbixDBA
Perl plugin for Zabbix to monitor RDBMS. Used Orabbix as example.

#### Configuration
Add your database information just like described in conf/config.pl . This file uses Perl hash structure to describe configuration.

#### Usage
```
perl bootstrap.pl start /path/to/config.pl
```

#### TODO
~~- add ability to create discovery rules~~
- add comments
~~- add SIG signal handlers to stop loop gracefully~~
- add logging
~~- add Zabbix template~~
- reformat code for easy reading and maintenance
