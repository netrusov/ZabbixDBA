## ZabbixDBA
ZabbixDBA uses threading of DBI connections which is good for monitoring of multiple database instances.
Currently there are template and query set only for Oracle database, but Perl DBI supports any type of RDBMS:
- Oracle
- MySQL
- MS SQL
- PostgreSQL
- DB2, etc.
  
You can find full list of DBD modules here: https://metacpan.org/search?q=DBD
  
Feel free to fork and contribute!
  
#### Installation
Copy project source to desired directory. 
If path will differ from default (/opt/ZabbixDBA) be sure to change it in startup script!
Open **settings.sh** file and carefully check all paths.
  
Put the script **init.d/ZabbixDBA** to your **/etc/init.d** directory
```
cp init.d/ZabbixDBA /etc/init.d
chmod +x /etc/init.d/ZabbixDBA
/sbin/chkconfig ZabbixDBA on     # enable automatic startup/shutdown
```
  
To install all Perl requirements execute the following in plugin directory:
```
cpanm --installdeps .
```
  
#### Usage
```
/sbin/service ZabbixDBA {start|stop|restart|reload|status}
```
  
#### Configuration
Create user ZABBIX (or whatever you want) in database and grant privileges regarding your privacy policy.  
Add your database information just like described in **conf/config.pl** (this file uses Perl hash structure to describe configuration).

#### Features

- [Discovery rules](docs/DiscoveryRules.md)
- [send_to](docs/SendTo.md)
- [Bind Values](https://metacpan.org/pod/DBI#Placeholders-and-Bind-Values)
- [Log4perl](https://metacpan.org/pod/Log::Log4perl)
  
#### TODO
- reformat code for easy reading and maintenance
- ~~add start/stop scripts~~
- ~~add comments~~
- ~~add logging~~
- ~~add SIG signal handlers to stop loop gracefully~~
- ~~add Zabbix template~~
- ~~add ability to create discovery rules~~
