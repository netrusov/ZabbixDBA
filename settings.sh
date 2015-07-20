ORACLE_HOME=/usr/share/oracle/instantclient_12_1
LD_LIBRARY_PATH=/usr/share/oracle/instantclient_12_1
TNS_ADMIN=$ORACLE_HOME
PATH=$ORACLE_HOME:$PATH

CONFIG=/opt/ZabbixDBA/conf/config.pl
LOCKFILE=/var/lock/subsys/ZabbixDBA
PIDFILE=/var/run/ZabbixDBA.pid