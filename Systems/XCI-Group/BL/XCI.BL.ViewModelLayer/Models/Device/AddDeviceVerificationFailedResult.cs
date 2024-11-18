using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.ViewModelLayer.Models.Device
{
    public class AddDeviceVerificationFailedResult : AddDeviceVerificationResult
    {
        public int FailureReasonCode { get; set; }
        public string FailureReason { get; set; }
    }
}
