/*

Download source from herer: http://whoisactive.com/downloads/

Common usages:
+ Get current proceses running
Exec sp_whoisactive

+ Get locks
EXEC sp_whoisactive @get_locks = 1

+ Get locks with root
EXEC sp_whoisactive @get_locks = 1, @find_block_leaders = 1


*/