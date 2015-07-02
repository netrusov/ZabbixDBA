## ZabbixDBA
Perl plugin for Zabbix to monitor RDBMS. Used Orabbix as example.  
  
ZabbixDBA uses threading of DBI connections which is good for monitoring of multiple database instances.
    
Feel free to fork and contribute!

#### Requirements
To install all pre-requirements execute the following in plugin directory:
```
cpanm --installdeps .
```

#### Configuration
Create user ZABBIX (or whatever you want) in database and grant privileges regarding your privacy policy (I've granted select privilege on all dictionary tables).  
  
Add your database information just like described in **conf/config.pl** (this file uses Perl hash structure to describe configuration).

#### Usage
Start:  
```
perl bootstrap.pl start /path/to/config.pl
```

Stop gracefully:  
```
kill -s USR1 $pid
```

#### HOWTO
  
You can define custom rules and items for discovery in query properties file - just add rule/item description to 'discovery' section.
  
###### Rule discovery  
Syntax:  

```
rule => {
    itemname => {
        query => q{
            *query*
        },
        keys => [ 'column0', 'column1', 'etc.' ],
    }
}
```

Here:
- *itemname* - Zabbix item name
- *query* - SQL query text
- *column..* - column names to use as a key for discovery
  
Example for tablespace discovery:
```
rule => {
    tablespaces => {
        query => q{
            select name tsname from gv$tablespace
        },
        keys => ['TSNAME'],
    }
}
```
JSON output (formatted) after fetching and processing rows:
```
{"data":[
{"{#TSNAME}":"SYSTEM"},
{"{#TSNAME}":"SYSAUX"},
{"{#TSNAME}":"UNDOTBS1"},
{"{#TSNAME}":"TEMP"},
{"{#TSNAME}":"USERS"}
]}
```
  
###### Item discovery
Syntax:
```
item => {
    itemname => {
        query => q{
            query
        },
        key_value => { 'column0' => 'column1' },
    }
}
```
Here:
- *column0* - **value** of column0 to be put as a parameter for item, i.e.: item[valueof(column0)]
- *column1* - final item value, i.e.: item[valueof(column0)] = valueof(column1)
  
Example:
```
item => {
    tablespace_usage => {
        query => q{
            select tablespace_name tsname, used_percent pct
            from dba_tablespace_usage_metrics
        },
        key_value => { 'TSNAME' => 'PCT' }
    }
}
```
Output (formatted):
```
tablespace_usage[SYSTEM] => 12.7166748046875
tablespace_usage[SYSAUX] => 23.1109619140625
tablespace_usage[UNDOTBS1] => .0640869140625
tablespace_usage[TEMP] => .0244148075807977538377025666066469313639
tablespace_usage[USERS] => 55.542144775390625
```
  
  
#### TODO
- add start/stop scripts
- reformat code for easy reading and maintenance
- ~~add comments~~
- ~~add logging~~
- ~~add SIG signal handlers to stop loop gracefully~~
- ~~add Zabbix template~~
- ~~add ability to create discovery rules~~
