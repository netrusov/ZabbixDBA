# ZabbixDBA - Zabbix Database Monitoring Service

## Description
ZabbixDBA is fast and flexible service to monitor your RDBMS.

ZabbixDBA uses threading of DBI connections which is good for monitoring of multiple database instances simultaneously. Just configure it, run daemon and it will do all the job.
Currently there are template and query set only for Oracle database, but Perl DBI supports any type of RDBMS:
- Oracle
- MySQL
- MS SQL
- PostgreSQL
- DB2, etc.

You can find full list of DBD modules here: https://metacpan.org/search?q=DBD

The code has been tested with Oracle, PostgreSQL, and MySQL, and it's 100% compatible with them (but be sure to install appropriate drivers and `DBD::...` module)

Feel free to fork and contribute!

## Documentation

See [Wiki](https://github.com/anetrusov/ZabbixDBA/wiki) for documentation

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/netrusov/ZabbixDBA.

## License

The code is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
