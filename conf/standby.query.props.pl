{
    query_list         => ['archivelog_applied'],
    archivelog_applied => {
        query => q{
            select max (sequence#)
            from v$archived_log
            where applied = 'YES'
        },
    },
}
