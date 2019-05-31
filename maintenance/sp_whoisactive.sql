/*

Download source from herer: http://whoisactive.com/downloads/
Or Get downloaded 11.32 version via who_is_active_v11_32.zip

Common usages:
+ Get current proceses running
Exec sp_whoisactive

+ Get locks
EXEC sp_whoisactive @get_locks = 1

+ Get locks with root
EXEC sp_whoisactive @get_locks = 1, @find_block_leaders = 1

+ Some cases sp_whoisactive get hang, then run command below:
USE master
GO
DBCC OPENTRAN


*/