{
  query_list     => ['archivelog_seq'],
  archivelog_seq => {
    query => q{
        select max (sequence#) from v$log_history
    },
    send_to => ['STANDBY'],
  },
}
