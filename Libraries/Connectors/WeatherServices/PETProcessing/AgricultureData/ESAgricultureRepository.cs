using Maba.Connectors.ElasticsearchLibrary;
using Maba.Connectors.ElasticsearchLibrary.Models;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Connectors.WeatherServices.PETProcessing.AgricultureData
{
    public class ESAgricultureRepository : BaseElasticsearchConnector_2x, IAgricultureData
    {
        #region CONSTANTS

        public const string ELASTIC__TYPE_PET = "pet_data";
        public const string ELASTIC__INDEX_NAME = "pet_history";
        public const string ELASTIC__LOCATION_FIELD = "location";
        public const string ELASTIC__STATION_FIELD = "sID";


        #endregion

        #region ctor

        public ESAgricultureRepository(ElasticSettings settings)
            : base(settings)
        {
        }



        #endregion

        #region IAgricultureData Implementation




        public HitRecord[] AddPETRecords(IEnumerable<AgricultureRecord> list)
        {
            var bulkRespose = BullkIndex(S => ELASTIC__TYPE_PET, item => ELASTIC__INDEX_NAME, list);
            return Convert(bulkRespose);

        }
        public AgricultureRecord GetPETRecord(Location location, int Distance)
        {
            var result = Search<AgricultureRecord>(ELASTIC__INDEX_NAME, ELASTIC__TYPE_PET,
               null,
               r =>
               {
                   Search_LocationRange<AgricultureRecord>(r, ELASTIC__LOCATION_FIELD, (Double)location.lat, (Double)location.lon, Distance);
               });

            var Hits = result.Hits.ToArray();
            if (Hits.Length > 0)
            {
                return Hits[0].Source;
            }
            else return null;
        }

        public AgricultureRecord GetPETRecord(string StationID)
        {
            var result = Search<AgricultureRecord>(ELASTIC__INDEX_NAME, ELASTIC__TYPE_PET,
              null,
              r =>
              {
                  Search_Term<AgricultureRecord>(r, ELASTIC__STATION_FIELD, StationID);
              }
                  );

            var Hits = result.Hits.ToArray();
            if (Hits.Length > 0)
            {
                return Hits[0].Source;
            }
            else return null;
        }


        #endregion
    }
}
