{   
    query_list => [
        'alive',                 'archive',
        'uptime',                'dbblockgets',
        'dbconsistentgets',      'dbphysicalreads',
        'dbblockchanges',        'dbhitratio',
        'hitratio_body',         'hitratio_table_proc',
        'hitratio_sqlarea',      'hitratio_trigger',
        'miss_latch',            'pga_aggregate_target',
        'pga',                   'phio_datafile_reads',
        'phio_datafile_writes',  'phio_redo_writes',
        'pinhitratio_body',      'pinhitratio_sqlarea',
        'pinhitratio_trigger',   'pinhitratio_table_proc',
        'pool_dict_cache',       'pool_free_mem',
        'pool_lib_cache',        'pool_sql_area',
        'pool_misc',             'sga_buffer_cache',
        'sga_fixed',             'sga_java_pool',
        'sga_large_pool',        'sga_log_buffer',
        'waits_directpath_read', 'waits_file_io',
        'waits_controlfileio',   'waits_logwrite',
        'waits_multiblock_read', 'waits_singleblock_read',
        'waits_sqlnet',          'blocking_sessions',
        'dbversion'
    ],
    alive => {
        query => q{
            select 1 from dual
        },
        no_data_found => 0,
    },
    archive => {
        query => q{
            select count (*)
            from gv$archived_log
            where completion_time >= (sysdate - 1 / 24)
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
            select value / 1024 / 1024
            from gv$pgastat
            where name = 'aggregate PGA target parameter'
        },
    },
    pga => {
        query => q{
            select value / 1024 / 1024
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
            select bytes / 1024 / 1024
            from gv$sgastat
            where pool = 'shared pool' and name = 'dictionary cache'
        },
    },
    pool_free_mem => {
        query => q{
            select bytes / 1024 / 1024
            from gv$sgastat
            where pool = 'shared pool' and name = 'free memory'
        },
    },
    pool_lib_cache => {
        query => q{
            select bytes / 1024 / 1024
            from gv$sgastat
            where pool = 'shared pool' and name = 'library cache'
        },
    },
    pool_sql_area => {
        query => q{
            select bytes / 1024 / 1024
            from gv$sgastat
            where pool = 'shared pool' and name = 'sql area'
        },
        no_data_found => 0,
    },
    pool_misc => {
        query => q{
            select sum (bytes / 1024 / 1024)
            from gv$sgastat
            where pool = 'shared pool'
            and name not in ('library cache'
            , 'dictionary cache'
            , 'free memory'
            , 'sql area')
        },
    },
    sga_buffer_cache => {
        query => q{
            select sum (bytes) / 1024 / 1024
            from gv$sgastat
            where name in ('db_block_buffers', 'buffer_cache')
        },
    },
    sga_fixed => {
        query => q{
            select sum (bytes) / 1024 / 1024
            from gv$sgastat
            where name = 'fixed_sga'
        },
    },
    sga_java_pool => {
        query => q{
            select sum (bytes) / 1024 / 1024
            from gv$sgastat
            where pool = 'java pool'
        },
    },
    sga_large_pool => {
        query => q{
            select sum (bytes) / 1024 / 1024
            from gv$sgastat
            where pool = 'large pool'
        },
    },
    sga_log_buffer => {
        query => q{
            select sum (bytes) / 1024 / 1024
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
            select sum (total_waits)
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
            select count (*)
            from (    select count (*)
            from gv$session
            group by level
            having level > 1 and sum (seconds_in_wait) > 100
            start with blocking_session is null
            connect by nocycle     prior inst_id = blocking_instance
            and prior sid = blocking_session)
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
                    select name tsname from gv$tablespace
                },
                columns => ['TSNAME']
            },
        },
        item => {
            tablespace_usage => {
                query => q{
                        select tablespace_name tsname, used_percent pct
                        from dba_tablespace_usage_metrics
                    },
                key => { 'TSNAME' => 'PCT' }
            }
        },
    }
}