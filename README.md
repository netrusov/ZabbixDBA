## ZabbixDBA
Perl plugin for Zabbix to monitor RDBMS. Used Orabbix as example.

#### Configuration
Add your database information just like described in _conf/config.pl_.  
This file uses Perl hash structure to describe configuration.

#### Usage
Start:  
```
perl bootstrap.pl start /path/to/config.pl
```

Stop gracefully:  
```
kill -s USR1 $pid
```

#### TODO
- add start/stop scripts
- add comments
- add logging
- reformat code for easy reading and maintenance
- ~~add SIG signal handlers to stop loop gracefully~~
- ~~add Zabbix template~~
- ~~add ability to create discovery rules~~
