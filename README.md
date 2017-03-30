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

### Documentation

See [Wiki](https://github.com/anetrusov/ZabbixDBA/wiki) for documentation

---

```
COPYRIGHT AND LICENSE
    Copyright 2014-2017 by Alexander Netrusov <alexander.netrusov@gmail.com>

    This program is free software; you can redistribute it and/or modify it
    under the same terms as Perl itself.
```
