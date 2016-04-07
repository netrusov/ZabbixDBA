## ZabbixDBA
ZabbixDBA uses threading of DBI connections which is good for monitoring of multiple database instances.
Currently there are template and query set only for Oracle database, but Perl DBI supports any type of RDBMS:
- Oracle
- MySQL
- MS SQL
- PostgreSQL
- DB2, etc.
  
You can find full list of DBD modules here: https://metacpan.org/search?q=DBD

This plugin tested with Oracle, PostgreSQL, and MySQL, and it's 100% compatible with them (but be sure to install appropriate drivers and DBD::... module)

Feel free to fork and contribute!
  
#### Installation
Copy project source to desired directory.
If path will differ from default (/opt/ZabbixDBA) be sure to change it in startup script!
Open **settings.sh** file and carefully check all paths.
  
Put the script **[init.d/zdba](init.d/zdba)** to your **/etc/init.d** directory
```
cp init.d/zdba /etc/init.d
chmod +x /etc/init.d/zdba
/sbin/chkconfig zdba on     # enable automatic startup/shutdown
```
  
To install all Perl requirements execute the following in plugin directory:
```
cpanm --installdeps .
```
  
#### Usage
```
/sbin/service zdba {start|stop|restart|reload|status}
```
  
#### Configuration
1. Create user ZABBIX (or whatever you want) in database.
2. Grant him privileges regarding your privacy policy.
3. Add your database credentials just like described in **[conf/config.example.pl](conf/config.example.pl)** (see more [here](docs/Configuration.md)).

#### Features

- [Discovery Rules](docs/DiscoveryRules.md)
- [Bind Values](https://metacpan.org/pod/DBI#Placeholders-and-Bind-Values)
- [Log4perl](https://metacpan.org/pod/Log::Log4perl)
