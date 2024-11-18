using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.BulksLayer.Repositories.Alerts
{
    public interface IAlertsRepository : IDisposable
    {
        Common.Models.RecordStatus[] AddTempRecords(IEnumerable<Common.Models.TempRecord> Records);
        Common.Models.TempRecord[] GetTempRecords(string sn, DateTime From, DateTime To, int PageNumber = 1, int PageSize = 10);



        /*
                RecordStatus[] AddDWHAlertRecords(string SN, IEnumerable<Alerts.AlertRecord> records);
                Alerts.AlertRecordsResponse GetDWHAlerts(string ParentSiteID, string SN, int PageSize, int PageNumber, long? from, long to);
                IEnumerable<Alerts.AlertRecord> GetTempRecords(string SN, int PageSize, int PageNumber, long? from, long to);
                RecordStatus[] AddTempRecords(string SN, IEnumerable<Alerts.AlertRecord> records);*/
    }
}
