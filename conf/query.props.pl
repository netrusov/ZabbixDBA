{
  query_list => [
    'archivelog_switch',      'uptime',
    'dbblockgets',            'dbconsistentgets',
    'dbphysicalreads',        'dbblockchanges',
    'dbhitratio',             'hitratio_body',
    'hitratio_table_proc',    'hitratio_sqlarea',
    'hitratio_trigger',       'miss_latch',
    'pga_aggregate_target',   'pga',
    'phio_datafile_reads',    'phio_datafile_writes',
    'phio_redo_writes',       'pinhitratio_body',
    'pinhitratio_sqlarea',    'pinhitratio_trigger',
    'pinhitratio_table_proc', 'pool_dict_cache',
    'pool_free_mem',          'pool_lib_cache',
    'pool_sql_area',          'pool_misc',
    'sga_buffer_cache',       'maxprocs',
    'procnum',                'maxsession',
    'session',                'session_system',
    'session_active',         'session_inactive',
    'sga_shared_pool',        'sga_fixed',
    'sga_java_pool',          'sga_large_pool',
    'sga_log_buffer',         'waits_directpath_read',
    'waits_file_io',          'waits_controlfileio',
    'waits_logwrite',         'waits_logsync',
    'waits_multiblock_read',  'waits_singleblock_read',
    'waits_sqlnet',           'blocking_sessions',
    'blocking_sessions_full', 'dbversion'
  ],
  archivelog_switch => {
    query => q{
        select count(*)
        from gv$log_history
        where first_time >= (sysdate - 1 / 24)
    },
  },
  uptime => {
    query => q{
        select to_char ( (sysdate - startup_time) * 86400, 'FM99999999999999990')
        from gv$instance
    },
  },
  dbblockgets => {
    query => q{
        select sum (value)
        from gv$sysstat
        where name = 'db block gets'
    },
  },
  dbblockchanges => {
    query => q{
        select sum (value)
        from gv$sysstat
        where name = 'db block changes'
    },
  },
  dbconsistentgets => {
    query => q{
        select sum (value)
        from gv$sysstat
        where name = 'consistent gets'
    },
  },
  dbphysicalreads => {
    query => q{
        select sum (value)
        from gv$sysstat
        where name = 'physical reads'
    },
  },
  dbhitratio => {
    query => q{
        select ( sum (case name when 'consistent gets' then value else 0 end)
        + sum (case name when 'db block gets' then value else 0 end)
        - sum (case name when 'physical reads' then value else 0 end))
        / ( sum (case name when 'consistent gets' then value else 0 end)
        + sum (case name when 'db block gets' then value else 0 end))
        * 100
        from gv$sysstat
    },
  },
  hitratio_body => {
    query => q{
        select gethitratio * 100
        from gv$librarycache
        where namespace = 'BODY'
    },
  },
  hitratio_sqlarea => {
    query => q{
        select gethitratio * 100
        from gv$librarycache
        where namespace = 'SQL AREA'
    },
  },
  hitratio_trigger => {
    query => q{
        select gethitratio * 100
        from gv$librarycache
        where namespace = 'TRIGGER'
    },
  },
  hitratio_table_proc => {
    query => q{
        select gethitratio * 100
        from gv$librarycache
        where namespace = 'TABLE/PROCEDURE'
    },
  },
  miss_latch => {
    query => q{
        select sum (misses) from gv$latch
    },
  },
  pga_aggregate_target => {
    query => q{
        select value
        from gv$pgastat
        where name = 'aggregate PGA target parameter'
    },
  },
  pga => {
    query => q{
        select value
        from gv$pgastat
        where name = 'total PGA inuse'
    },
  },
  phio_datafile_reads => {
    query => q{
        select sum (value)
        from gv$sysstat
        where name = 'physical reads direct'
    },
  },
  phio_datafile_writes => {
    query => q{
        select sum (value)
        from gv$sysstat
        where name = 'physical writes direct'
    },
  },
  phio_redo_writes => {
    query => q{
        select sum (value)
        from gv$sysstat
        where name = 'redo writes'
    },
  },
  pinhitratio_body => {
    query => q{
        select pins / (pins + reloads) * 100
        from gv$librarycache
        where namespace = 'BODY'
    },
  },
  pinhitratio_sqlarea => {
    query => q{
        select pins / (pins + reloads) * 100
        from gv$librarycache
        where namespace = 'SQL AREA'
    },
  },
  pinhitratio_trigger => {
    query => q{
        select pins / (pins + reloads) * 100
        from gv$librarycache
        where namespace = 'TRIGGER'
    },
  },
  pinhitratio_table_proc => {
    query => q{
        select pins / (pins + reloads) * 100
        from gv$librarycache
        where namespace = 'TABLE/PROCEDURE'
    },
  },
  pool_dict_cache => {
    query => q{
        select bytes
        from gv$sgastat
        where pool = 'shared pool' and name = 'dictionary cache'
    },
    no_data_found => 0,
  },
  pool_free_mem => {
    query => q{
        select bytes
        from gv$sgastat
        where pool = 'shared pool' and name = 'free memory'
    },
  },
  pool_lib_cache => {
    query => q{
        select bytes
        from gv$sgastat
        where pool = 'shared pool' and name = 'library cache'
    },
    no_data_found => 0,
  },
  pool_sql_area => {
    query => q{
        select bytes
        from gv$sgastat
        where pool = 'shared pool' and name = 'sql area'
    },
    no_data_found => 0,
  },
  pool_misc => {
    query => q{
        select sum (bytes)
        from gv$sgastat
        where pool = 'shared pool'
        and name not in ('library cache'
        , 'dictionary cache'
        , 'free memory'
        , 'sql area')
    },
  },
  maxprocs => {
    query => q{
        select value from gv$parameter where name = 'processes'
    },
  },
  procnum => {
    query => q{
        select count (*) from gv$process
    },
  },
  maxsession => {
    query => q{
        select value from gv$parameter where name = 'sessions'
    },
  },
  session => {
    query => q{
        select count (*) from gv$session
    },
  },
  session_system => {
    query => q{
        select count (*)
        from gv$session
        where type = 'BACKGROUND'
    },
  },
  session_active => {
    query => q{
        select count (*)
        from gv$session
        where type != 'BACKGROUND' and status = 'ACTIVE'
    },
  },
  session_inactive => {
    query => q{
        select count (*)
        from gv$session
        where type != 'BACKGROUND' and status = 'INACTIVE'
    },
  },
  sga_buffer_cache => {
    query => q{
        select sum (bytes)
        from gv$sgastat
        where name in ('db_block_buffers', 'buffer_cache')
    },
  },
  sga_fixed => {
    query => q{
        select sum (bytes)
        from gv$sgastat
        where name = 'fixed_sga'
    },
  },
  sga_java_pool => {
    query => q{
        select sum (bytes)
        from gv$sgastat
        where pool = 'java pool'
    },
  },
  sga_large_pool => {
    query => q{
        select sum (bytes)
        from gv$sgastat
        where pool = 'large pool'
    },
  },
  sga_shared_pool => {
    query => q{
        select sum (bytes)
        from gv$sgastat
        where pool = 'shared pool'
    },
  },
  sga_log_buffer => {
    query => q{
        select sum (bytes)
        from gv$sgastat
        where name = 'log_buffer'
    },
  },
  waits_directpath_read => {
    query => q{
        select total_waits
        from gv$system_event
        where event = 'direct path read'
    },
  },
  waits_file_io => {
    query => q{
        select nvl (sum (total_waits), 0)
        from gv$system_event
        where event in ('file identify', 'file open')
    },
  },
  waits_controlfileio => {
    query => q{
        select sum (total_waits)
        from gv$system_event
        where event in ('control file sequential read'
        , 'control file single write'
        , 'control file parallel write')
    },
  },
  waits_logwrite => {
    query => q{
        select sum (total_waits)
        from gv$system_event
        where event in ('log file single write', 'log file parallel write')
    },
  },
  waits_logsync => {
    query => q{
        select sum(total_waits)
        from gv$system_event
        where event = 'log file sync'
    },
  },
  waits_multiblock_read => {
    query => q{
        select sum (total_waits)
        from gv$system_event
        where event = 'db file scattered read'
    },
  },
  waits_singleblock_read => {
    query => q{
        select sum (total_waits)
        from gv$system_event
        where event = 'db file sequential read'
    },
  },
  waits_sqlnet => {
    query => q{
        select sum (total_waits)
        from gv$system_event
        where event in ('SQL*Net message to client'
        , 'SQL*Net message to dblink'
        , 'SQL*Net more data to client'
        , 'SQL*Net more data to dblink'
        , 'SQL*Net break/reset to client'
        , 'SQL*Net break/reset to dblink')
    },
  },
  blocking_sessions => {
    query => q{
select count(*)
  from (
            select rootid
              from (
                          select level lvl
                               , connect_by_root (inst_id || '.' || sid) rootid
                               , seconds_in_wait
                            from gv$session
                      start with blocking_session is null
                      connect by nocycle prior inst_id = blocking_instance
                                     and prior sid = blocking_session
                   )
             where lvl > 1
          group by rootid
            having sum(seconds_in_wait) > 300
       )
        },
    no_data_found => 0,
  },
  blocking_sessions_full => {
    query => q{
    select    lpad(' ', (level - 1) * 4)
           || 'INST_ID         :  '
           || inst_id
           || chr(10)
           || lpad(' ', (level - 1) * 4)
           || 'SERVICE_NAME    :  '
           || service_name
           || chr(10)
           || lpad(' ', (level - 1) * 4)
           || 'SID,SERIAL      :  '
           || sid
           || ','
           || serial#
           || chr(10)
           || lpad(' ', (level - 1) * 4)
           || 'USERNAME        :  '
           || username
           || chr(10)
           || lpad(' ', (level - 1) * 4)
           || 'OSUSER          :  '
           || osuser
           || chr(10)
           || lpad(' ', (level - 1) * 4)
           || 'MACHINE         :  '
           || machine
           || chr(10)
           || lpad(' ', (level - 1) * 4)
           || 'PROGRAM         :  '
           || program
           || chr(10)
           || lpad(' ', (level - 1) * 4)
           || 'MODULE          :  '
           || module
           || chr(10)
           || lpad(' ', (level - 1) * 4)
           || 'SQL_ID          :  '
           || sql_id
           || chr(10)
           || lpad(' ', (level - 1) * 4)
           || 'EVENT           :  '
           || event
           || chr(10)
           || lpad(' ', (level - 1) * 4)
           || 'SECONDS_IN_WAIT :  '
           || seconds_in_wait
           || chr(10)
           || lpad(' ', (level - 1) * 4)
           || 'STATE           :  '
           || state
           || chr(10)
           || lpad(' ', (level - 1) * 4)
           || 'STATUS          :  '
           || status
           || chr(10)
           || lpad(' ', (level - 1) * 4)
           || '========================='
           || chr(10)
              blocking_sess_info
      from (
                  select inst_id || '.' || sid id
                       , case
                            when blocking_instance is not null
                            then
                               blocking_instance || '.' || blocking_session
                         end
                            parent_id
                       , inst_id
                       , service_name
                       , sid
                       , serial#
                       , username
                       , osuser
                       , machine
                       , program
                       , module
                       , sql_id
                       , event
                       , seconds_in_wait
                       , state
                       , status
                       , level lvl
                       , connect_by_isleaf isleaf
                       , connect_by_root (inst_id || '.' || sid) rootid
                    from gv$session
              start with blocking_session is null
              connect by nocycle prior inst_id = blocking_instance
                             and prior sid = blocking_session
           )
     where lvl || isleaf <> '11'
       and rootid in
              (
                   select rootid
                     from (
                                 select level lvl
                                      , connect_by_root (inst_id || '.' || sid) rootid
                                      , seconds_in_wait
                                   from gv$session
                             start with blocking_session is null
                             connect by nocycle prior inst_id = blocking_instance
                                            and prior sid = blocking_session
                          )
                    where lvl > 1
                 group by rootid
                   having sum(seconds_in_wait) > 300
              )
connect by nocycle prior id = parent_id
start with parent_id is null
        },
  },
  dbversion => {
    query => q{
        select banner
        from gv$version
        where banner like '%Oracle Database%'
    },
  },
  discovery => {
    rule => {
      tablespaces => {
        query => q{
            select name ts from gv$tablespace
        },
        keys => ['TS'],
      },
      wait_classes => {
        query => q{
            select distinct wait_class as class
            from gv$system_event
        },
        keys => ['CLASS'],
      },
    },
    item => {
      ts_usage_pct => {
        query => q{
            select tablespace_name ts, round(used_percent, 5) pct
            from dba_tablespace_usage_metrics
        },
        keys => { TS => 'PCT' }
      },
      ts_usage_bytes => {
        query => q{
            select ta.tablespace_name as ts, ta.used_space * tb.block_size as bytes
            from dba_tablespace_usage_metrics ta
            join dba_tablespaces tb on ta.tablespace_name = tb.tablespace_name
        },
        keys => { TS => 'BYTES' }
      },
      waits_ms => {
        query => q{
          select ta.wait_class as class, sum(ta.total_waits) as waits_ms
          from gv$system_event ta
          where event not in ('SQL*Net message from client', 'pipe get')
          group by ta.wait_class
        },
        keys => { CLASS => 'WAITS_MS' },
      },
    },
  },
}
