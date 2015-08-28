CREATE OR REPLACE FUNCTION GET_BLOCKING_SESSIONS
   RETURN VARCHAR2
AS
   RESULT          VARCHAR2 (4000);

   CURSOR ALL_LOCKS
   IS
      (    SELECT TAB.ID
                , TAB.PARENT_ID
                , TAB.INST_ID
                , TAB.SERVICE_NAME
                , TAB.SID
                , TAB.SERIAL#
                , TAB.USERNAME
                , TAB.OSUSER
                , TAB.MACHINE
                , TAB.PROGRAM
                , TAB.SQL_ID
                , TAB.EVENT
                , TAB.SECONDS_IN_WAIT
                , TAB.STATE
                , TAB.STATUS
                , LEVEL LVL
                , CONNECT_BY_ISLEAF LF
             FROM (SELECT T1.ID
                        , T1.PARENT_ID
                        , T1.INST_ID
                        , T1.SERVICE_NAME
                        , T1.SID
                        , T1.SERIAL#
                        , T1.USERNAME
                        , T1.OSUSER
                        , T1.MACHINE
                        , T1.PROGRAM
                        , T1.SQL_ID
                        , T1.EVENT
                        , T1.SECONDS_IN_WAIT
                        , T1.STATE
                        , T1.STATUS
                     FROM (    SELECT INST_ID || '.' || SID ID
                                    , DECODE (
                                         BLOCKING_INSTANCE || '.' || BLOCKING_SESSION
                                       , '.', NULL
                                       , BLOCKING_INSTANCE || '.' || BLOCKING_SESSION)
                                         PARENT_ID
                                    , INST_ID
                                    , SERVICE_NAME
                                    , SID
                                    , SERIAL#
                                    , USERNAME
                                    , OSUSER
                                    , MACHINE
                                    , PROGRAM
                                    , SQL_ID
                                    , EVENT
                                    , SECONDS_IN_WAIT
                                    , STATE
                                    , STATUS
                                    , LEVEL LVL
                                    , CONNECT_BY_ISLEAF ISLEAF
                                    , CONNECT_BY_ROOT (INST_ID || '.' || SID) ROOTID
                                 FROM GV$SESSION
                           START WITH BLOCKING_SESSION IS NULL
                           CONNECT BY NOCYCLE     PRIOR INST_ID =
                                                     BLOCKING_INSTANCE
                                              AND PRIOR SID = BLOCKING_SESSION)
                          T1
                    WHERE     LVL || ISLEAF <> '11'
                          AND ROOTID IN (  SELECT ROOTID
                                             FROM (    SELECT LEVEL LVL
                                                            , CONNECT_BY_ROOT (   INST_ID
                                                                               || '.'
                                                                               || SID)
                                                                 ROOTID
                                                            , SECONDS_IN_WAIT
                                                         FROM GV$SESSION
                                                   START WITH BLOCKING_SESSION
                                                                 IS NULL
                                                   CONNECT BY NOCYCLE     PRIOR INST_ID =
                                                                             BLOCKING_INSTANCE
                                                                      AND PRIOR SID =
                                                                             BLOCKING_SESSION)
                                            WHERE LVL > 1
                                         GROUP BY ROOTID
                                           HAVING SUM (SECONDS_IN_WAIT) > 100)) TAB
       CONNECT BY NOCYCLE PRIOR ID = PARENT_ID
       START WITH PARENT_ID IS NULL);

   ALL_LOCKS_REC   ALL_LOCKS%ROWTYPE;
   SPACE           VARCHAR2 (100);

   FUNCTION MAKE_SPACES (NUM IN NUMBER)
      RETURN VARCHAR2
   IS
      A     NUMBER;
      STR   VARCHAR2 (100);
   BEGIN
      IF NUM > 0 THEN
         A := 0;

         LOOP
            A := A + 1;
            STR := STR || CHR (9);
            EXIT WHEN A = NUM;
         END LOOP;
      ELSE
         STR := '';
      END IF;

      RETURN STR;
   END;
BEGIN
   OPEN ALL_LOCKS;

   FETCH ALL_LOCKS INTO ALL_LOCKS_REC;

   IF ALL_LOCKS%NOTFOUND THEN
      RESULT := NULL;
   ELSE
      LOOP
         SPACE := MAKE_SPACES (ALL_LOCKS_REC.LVL - 1);

         RESULT := RESULT || SPACE || 'TRANSACTION:         LOCAL' || CHR (10);
         RESULT :=
               RESULT
            || SPACE
            || 'INST_ID              '
            || ALL_LOCKS_REC.INST_ID
            || CHR (10);
         RESULT :=
               RESULT
            || SPACE
            || 'SERVICE_NAME:        '
            || ALL_LOCKS_REC.SERVICE_NAME
            || CHR (10);
         RESULT :=
               RESULT
            || SPACE
            || 'SID,SERIAL#:         '
            || ALL_LOCKS_REC.SID
            || ','
            || ALL_LOCKS_REC.SERIAL#
            || CHR (10);
         RESULT :=
               RESULT
            || SPACE
            || 'USERNAME:            '
            || ALL_LOCKS_REC.USERNAME
            || CHR (10);
         RESULT :=
               RESULT
            || SPACE
            || 'OSUSER:              '
            || ALL_LOCKS_REC.OSUSER
            || CHR (10);
         RESULT :=
               RESULT
            || SPACE
            || 'MACHINE:             '
            || ALL_LOCKS_REC.MACHINE
            || CHR (10);
         RESULT :=
               RESULT
            || SPACE
            || 'PROGRAM:             '
            || ALL_LOCKS_REC.PROGRAM
            || CHR (10);
         RESULT :=
               RESULT
            || SPACE
            || 'SQL_ID:              '
            || ALL_LOCKS_REC.SQL_ID
            || CHR (10);
         RESULT :=
               RESULT
            || SPACE
            || 'EVENT:               '
            || ALL_LOCKS_REC.EVENT
            || CHR (10);
         RESULT :=
               RESULT
            || SPACE
            || 'SECONDS_IN_WAIT:     '
            || ALL_LOCKS_REC.SECONDS_IN_WAIT
            || CHR (10);
         RESULT :=
               RESULT
            || SPACE
            || 'STATE:               '
            || ALL_LOCKS_REC.STATE
            || CHR (10);
         RESULT :=
               RESULT
            || SPACE
            || 'STATUS:              '
            || ALL_LOCKS_REC.STATUS
            || CHR (10);
         RESULT := RESULT || SPACE || '=========================' || CHR (10);

         FETCH ALL_LOCKS INTO ALL_LOCKS_REC;

         EXIT WHEN ALL_LOCKS%NOTFOUND;
      END LOOP;
   END IF;

   RETURN RESULT;
END;