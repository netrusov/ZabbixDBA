## ZabbixDBA
Perl plugin for Zabbix to monitor RDBMS. Used Orabbix as example.

#### Configuration
Add your database information just like described in conf/config.pl . This file uses Perl hash structure to describe configuration.

#### Usage
```
perl bootstrap.pl start /path/to/config.pl
```

#### TODO
- add comments
- add logging
- reformat code for easy reading and maintenance  
- ~~add SIG signal handlers to stop loop gracefully~~  
- ~~add Zabbix template~~  
- ~~add ability to create discovery rules~~ 
