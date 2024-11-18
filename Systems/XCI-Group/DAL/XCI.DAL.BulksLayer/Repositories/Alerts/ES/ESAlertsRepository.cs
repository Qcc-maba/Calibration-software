using Nest;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using ElasticsearchConnector = Maba.Connectors.ElasticsearchLibrary;
using Maba.Hydra2.Systems.XCIGroup.DAL.BulksLayer.Repositories.Common.Models;

namespace Maba.Hydra2.Systems.XCIGroup.DAL.BulksLayer.Repositories.Alerts.ES
{
    public class ESAlertsRepository : ElasticsearchConnector.BaseElasticsearchConnector_2x, Alerts.IAlertsRepository
    {
        #region CONSTANTS

        public const string ELASTIC__TYPE_ALERTS = "alerts";
        public const string ELASTIC__TYPE_DATE_FIELD = "recordDateT";

        public const string ELASTIC__ROUTING__BY_DEVICE = "sn";

        #endregion

        #region ctor

        public ESAlertsRepository(AlertsESSettings settings)
            : base(settings)
        {
        }

        #endregion

        #region IAlertsRepository Implementation

        public Common.Models.RecordStatus[] AddTempRecords(IEnumerable<Common.Models.TempRecord> Records)
        {
            var settings = this.CurrentSettings as AlertsESSettings;


            var response = this.BullkCreate<TempRecord>(
                 r => BuildIndexName(settings.Index_Temp_Name, r.RecordDate),
                 r => ELASTIC__TYPE_ALERTS,
                 Records,
                 r => $"{r.SN}-{r.RecordDateT}",
                 r => r.SN,
                 null);

            return this.Convert(response)
                .Select(r => new Common.Models.RecordStatus(r))
                .ToArray();
        }

        public TempRecord[] GetTempRecords(string sn, DateTime From, DateTime To, int PageNumber = 1, int PageSize = 10)
        {
            var settings = this.CurrentSettings as AlertsESSettings;

            var indicies = this.BuildIndexName(settings.Index_Temp_Name, From, To);
            var searchResult = this.Search<TempRecord>(indicies, ELASTIC__TYPE_ALERTS,null,
                r =>
                {
                    this.Search_Paging(r, PageSize, PageNumber);
                    this.Search_BuildRange(r, "recordDateT", From, To);
                    r.Routing = new string[] { sn };
                });

            return searchResult
                        .Hits
                        .Select(r => r.Source)
                        .ToArray();
        }


        #endregion
    }
}
