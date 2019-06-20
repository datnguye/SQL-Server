rem DAVE\DAVE140 is server name
rem SystemMonitor: Database which is compiled with sproc MaintenanceDBBackup
rem -U: user name (this user must have right to run BACKUP Database)
rem -P: password
rem -Q: upper case to run query then terminate connection after it

Sqlcmd -S "DAVE\DAVE140" -d "SystemMonitor" -U "sa" -P "123" -Q "EXEC [MaintenanceDBBackup] @DbName = 'Test', @BackupFolderPath = 'C:\Shared\Temp'" 