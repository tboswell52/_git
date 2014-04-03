select * from ELMAH_Error 
where TimeUtc between '10/22/2013 23:27:00' and '10/22/2013 23:50:00'
and [type] <> 'System.UnauthorizedAccessException'
and [type] <> 'Focus.Core.Exceptions.IntendedForUserException'
and [type] <> 'Focus.Core.Entities.SchedulerDateException'
and Source <> 'Aspose.Pdf'
and Message not like ('%Focus.Web.Controllers.LoginController%')


select * from ELMAH_Error 
where TimeUtc between '10/23/2013 00:00:00' and '10/23/2013 00:10:00'
and [type] <> 'System.UnauthorizedAccessException'
and [type] <> 'Focus.Core.Exceptions.IntendedForUserException'
and [type] <> 'Focus.Core.Entities.SchedulerDateException'
and Source <> 'Aspose.Pdf'
and Message not like ('%Focus.Web.Controllers.LoginController%')

select * from ELMAH_Error 
where TimeUtc between '10/22/2013 16:40:00' and '10/22/2013 17:00:00'
and [type] <> 'System.UnauthorizedAccessException'
and [type] <> 'Focus.Core.Exceptions.IntendedForUserException'
and [type] <> 'Focus.Core.Entities.SchedulerDateException'
and Source <> 'Aspose.Pdf'
and Message not like ('%Focus.Web.Controllers.LoginController%')


select Dateadd(Hour, -4, TimeUtc), * from ELMAH_Error 
where TimeUtc between '10/22/2013 12:00:00' and '10/23/2013 01:00:00'
and Message = 'Payment is missing client account id.'
