### Discovery Rules

You can define custom rules and items for discovery in query properties file - just add rule/item description to 'discovery' section.

###### Rule discovery
Syntax:

```perl
rule => {
    itemname => {
        query => q{
            querytext
        },
        keys => [ 'column0', 'column1', 'etc.' ],
    }
}
```

Here:
- *itemname* - Zabbix item name
- *querytext* - SQL query text
- *column..* - column names to use as a key for discovery

Example for tablespace discovery:
```perl
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
```json
{
  "data": [
    {
      "{#TSNAME}": "SYSTEM"
    },
    {
      "{#TSNAME}": "SYSAUX"
    },
    {
      "{#TSNAME}": "UNDOTBS1"
    },
    {
      "{#TSNAME}": "TEMP"
    },
    {
      "{#TSNAME}": "USERS"
    }
  ]
}
```

###### Item discovery
Syntax:
```perl
item => {
    itemname => {
        query => q{
            querytext
        },
        keys => { 'column0' => 'column1' },
    }
}
```
Here:
- *column0* - **value** of column0 to be put as a parameter for item, i.e.: itemname[valueof(column0)]
- *column1* - final item value, i.e.: itemname[valueof(column0)] = valueof(column1)

Example:
```
item => {
    tablespace_usage => {
        query => q{
            select tablespace_name tsname, used_percent pct
            from dba_tablespace_usage_metrics
        },
        keys => { 'TSNAME' => 'PCT' }
    }
}
```

Output (formatted):
```json
[
  {
    "key": "tablespace_usage[SYSTEM]",
    "value": "12.7166748046875"
  },
  {
    "key": "tablespace_usage[SYSAUX]",
    "value": "23.1109619140625"
  },
  {
    "key": "tablespace_usage[UNDOTBS1]",
    "value": ".0640869140625"
  },
  {
    "key": "tablespace_usage[TEMP]",
    "value": ".0244148075807977538377025666066469313639"
  },
  {
    "key": "tablespace_usage[USERS]",
    "value": "55.542144775390625"
  }
]

```
