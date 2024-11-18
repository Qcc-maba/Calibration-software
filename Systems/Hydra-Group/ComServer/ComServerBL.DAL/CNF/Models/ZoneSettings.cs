using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace ComServerBL.Hydra2.DAL.CNF.Models
{
    public class ZoneSettings
    {
        #region properties

        public long ConfigID { get; set; }
        public byte OutputNumber { get; set; }
        public long ZoneID { get; set; }
        public System.DateTime UpdateDate { get; set; }
        public System.DateTime CreationDate { get; set; }

        public long RevisionID { get; set; }
        public long BaseRevisionID { get; set; }
        public string Name { get; set; }

        public byte StatusID { get; set; }
        public byte TypeID { get; set; }
        public decimal? SetupNominalFlow { get; set; }
        public short TimeFillDelay { get; set; }
        public byte LowFlowDeviation { get; set; }
        public byte HighFlowDeviation { get; set; }
        public short LowFlowFaultDelay { get; set; }
        public short HighFlowFaultDelay { get; set; }
        public bool FertilizerConnected { get; set; }
        public bool StopOnFertFailure { get; set; }
        public decimal? LastFlow { get; set; }
        public int? LastFlow_FlowViewTypeID { get; set; }
        public DateTime? LastFlow_Date { get; set; }

        #endregion

        #region ctor

        public ZoneSettings()
        {
        }

        #endregion

    }
}
