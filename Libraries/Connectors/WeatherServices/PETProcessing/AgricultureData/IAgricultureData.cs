using Maba.Connectors.ElasticsearchLibrary.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.WeatherServices.PETProcessing.AgricultureData
{
    public interface IAgricultureData : IDisposable
    {
        HitRecord[] AddPETRecords(IEnumerable<AgricultureRecord> list);
        AgricultureRecord GetPETRecord(Location location, int Distance);
        AgricultureRecord GetPETRecord(string StationID);
    }
}
