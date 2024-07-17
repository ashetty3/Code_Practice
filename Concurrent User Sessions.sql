/*

QUESTION

You have a table 
'user_sessions' with columns (user_id, session_start, session_end, session_duration_minutes).
 Write a SQL query to find users who have had at least 5 overlapping sessions in the past week. 
 An overlapping session is defined as a session that starts before another session ends for the same user.
 Include the user_id and the maximum number of concurrent overlapping sessions for each user.*/

 ----------------------------------First Attempt ----------------------------------------------------------------------

/*
 
 conditions : PAST Week 
          >= 5 sessions 
          starts before another session ends AND  same user

aggregates : sum of overlaps


tables : user_sessions

Assumption: Session start date is available on a second level time stamp. 
            We only need this information for the current time

output : userid, maximum concurrent sessions

*/

With overlap AS 
(
SELECT user_id, session_start,session_end, 
       LEAD(session_start) OVER (PARTITION BY user_id ORDER BY session_start) AS next_session, -- Get next session for the smae user 
       CASE WHEN DATEDIFF(second,LEAD(session_start) OVER (PARTITION BY user_id ORDER BY session_start), session_end) > 0 
            THEN 1 ELSE 0 
       END AS overlap_flag -- Check whether next session starts before the end of the same session for this user
  FROM user_sessions
  WHERE session_start >= DATEADD(days, -7, NOW()) -- all sessions past week

),
users_filter AS 
(
SELECT distinct user_id
  FROM overlap 
  GROUP BY user_id -- Could have also grouped by week number and year and counted 5 overlaps for scalability
  HAVING SUM(overlap_flag) >=5 -- At least 5 overlaps in the past week 
),
concurrent_overlap AS
(
SELECT user_id, session_start,session_end, SUM(overlap_flag) as concurr_overlap -- number of times the same session had overlaps
  FROM overlap
  GROUP BY user_id,session_start,session_end
)
SELECT c.user_id, max(concurr_overlap) as maximum_concurrent_sessions
FROM concurrent_overlap c
JOIN users_filter u on c.user_id = u.user_id
GROUP BY c.user_id


---------------------------------------- Better Way----------------------------


WITH session_points AS (
    SELECT user_id, session_start AS point, 1 AS value
    FROM user_sessions
    WHERE session_start >= DATEADD(day, -7, GETDATE())
    UNION ALL
    SELECT user_id, session_end AS point, -1 AS value
    FROM user_sessions
    WHERE session_end >= DATEADD(day, -7, GETDATE())
),
concurrent_sessions AS (
    SELECT user_id, point,
           SUM(value) OVER (PARTITION BY user_id ORDER BY point ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS concurrent_count
    FROM session_points
),
max_concurrent AS (
    SELECT user_id, MAX(concurrent_count) AS max_concurrent_sessions
    FROM concurrent_sessions
    GROUP BY user_id
),
users_with_overlaps AS (
    SELECT user_id
    FROM max_concurrent
    WHERE max_concurrent_sessions >= 5
)
SELECT mc.user_id, mc.max_concurrent_sessions
FROM max_concurrent mc
JOIN users_with_overlaps uw ON mc.user_id = uw.user_id
ORDER BY mc.max_concurrent_sessions DESC;



