using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.Bulks.Alerts
{
    /// <summary>
    /// Alert Manager Cycle
    /// 
    /// 
    /// 
    /// Step 1 - Add Temp record (binary data), then add to queue for next proccessing
    /// Step 2 - Process from queue, save as DHW and send for remote DWH
    /// </summary>







    public class AlertsBLManager : Base.BaseBLManager
    {
        #region CONSTANTS

        private const string ACCU_ALERT_TEMP = "ALERT_TEMP";

        #endregion

        #region ctor

        public AlertsBLManager(Base.BLSettings settings)
            : base(settings)
        {

        }

        #endregion

        public bool[] Step1_Binary(string sn, DAL.BulksLayer.Repositories.Common.Models.TempRecord[] Records)
        {
            bool[] Status = new bool[Records.Length];

            //validate request
            if (Records == null || Records.Length == 0)
            {
                return Status;
            }

            DAL.DataAccessLayer.Models.Device.DeviceInfo deviceInfo = null;
            DAL.DataAccessLayer.Models.Device.DeviceAccumulator ALERT_TEMP_acc = null;

            #region get device info & accumulators

            using (var adminDAL = this.CurrentBLSettings.DAL_DataAccessLayer_RepositoriesGenerator.IDeviceProcessingRepository())
            {
                deviceInfo = adminDAL.GetDeviceWithAccmulators(sn);
            }

            //refuse entire request if cannot find device
            if (deviceInfo == null)
            {
                return Status;
            }

            //get specific accumulator
            ALERT_TEMP_acc = deviceInfo.Accumulators.FirstOrDefault(a => a.AccType == ACCU_ALERT_TEMP);
            if (ALERT_TEMP_acc == null)
            {
                ALERT_TEMP_acc = new DAL.DataAccessLayer.Models.Device.DeviceAccumulator()
                {
                    AccType = ACCU_ALERT_TEMP,
                    DeviceID = deviceInfo.DeviceID
                };
            }

            #endregion

            #region locate accumulators

            long? originalStartTicks = ALERT_TEMP_acc.StartTicks;
            //validate records behind accumulators
            for (int i = 0; i < Records.Length; i++)
            {
                if (!ALERT_TEMP_acc.StartTicks.HasValue || Records[i].RecordDate.Ticks > ALERT_TEMP_acc.StartTicks)
                {
                    ALERT_TEMP_acc.StartTicks = Records[i].RecordDate.Ticks;
                }
            }
            //return false if no valid record was found
            if (!ALERT_TEMP_acc.StartTicks.HasValue || originalStartTicks == ALERT_TEMP_acc.StartTicks)
            {
                return new bool[Records.Length];
            }

            //remote records behind accumulator
            int effectiveRecordsCount = 0;

            if (originalStartTicks.HasValue)
            {
                for (int i = 0; i < Records.Length; i++)
                {
                    if (Records[i].RecordDate.Ticks < originalStartTicks)
                    {
                        Records[i] = null;
                    }
                    else
                    {
                        effectiveRecordsCount++;
                    }
                }
            }
            else
            {
                effectiveRecordsCount = Records.Length;
            }

            //no new record to process...
            if (originalStartTicks.HasValue && effectiveRecordsCount == 0)
            {
                return Status;
            }

            #endregion

            #region add records to storage

            int effectiveRecordIndex = 0;
            DateTime minRecord = DateTime.MaxValue;
            DateTime maxRecord = DateTime.MinValue;
            var effectiverecords = new DAL.BulksLayer.Repositories.Common.Models.TempRecord[effectiveRecordsCount];
            for (int i = 0; i < Records.Length; i++)
            {
                if (Records[i] != null)
                {
                    if (minRecord > Records[i].RecordDate)
                    {
                        minRecord = Records[i].RecordDate;
                    }
                    if (maxRecord < Records[i].RecordDate)
                    {
                        maxRecord = Records[i].RecordDate;
                    }
                    effectiverecords[effectiveRecordIndex++] = Records[i];
                }
            }

            DAL.BulksLayer.Repositories.Common.Models.RecordStatus[] _Status = null;
            using (var dal = this.CurrentBLSettings.DAL_BulksLayer_RepositoriesGenerator.Generator_IAlertsRepository())
            {
                _Status = dal.AddTempRecords(effectiverecords)
                    .ToArray();
            }

            effectiveRecordIndex = 0;
            for (int i = 0; i < Status.Length; i++)
            {
                if (Records[i] != null)
                {
                    if (Records[i] == effectiverecords[effectiveRecordIndex])
                    {
                        Status[i] = _Status[effectiveRecordIndex++].Success;
                    }
                }
                else
                {
                    Records[i] = null;
                }
            }

            #endregion

            #region add to queue

            var now = DateTime.UtcNow;

            var queueMessage = new Common.PendingQueueMessage()
            {
                DeviceID = deviceInfo.DeviceID,
                MessageDate = now,
                MessageType = ACCU_ALERT_TEMP,
                SN = deviceInfo.SN,
                Description = $"Add Temp records (SN={deviceInfo.SN}, UTCTime={now}, Effective={effectiveRecordsCount}/{Records.Length},MinTime={minRecord}, MaxTime={maxRecord}"
            };

            using (var q = this.CurrentBLSettings.DAL_QueueGenerator_Generator.Generate_IQueueConnector())
            {
                q.Queue(queueMessage);
            }

            #endregion

            #region  finally update accumulator

            using (var adminDAL = this.CurrentBLSettings.DAL_DataAccessLayer_RepositoriesGenerator.IDeviceProcessingRepository())
            {
                adminDAL.UpdateTimer_StartPoint(deviceInfo.DeviceID, ALERT_TEMP_acc);
            }

            #endregion

            return Status;
        }

    }
}
