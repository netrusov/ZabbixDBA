## ZabbixDBA
Perl plugin for Zabbix to monitor RDBMS. Used Orabbix as example.

#### Configuration
Create user ZABBIX (or whatever you want) in database and grant privileges regarging your privacy policy (I've granted select privilege on all dictionary tables).  
  
Add your database information just like described in _conf/config.pl_ (this file uses Perl hash structure to describe configuration).

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
