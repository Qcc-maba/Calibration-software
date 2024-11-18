using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.XCIGroup.BL.Bulks.Base
{
    public class BaseBLManager
    {
        public BLSettings CurrentBLSettings { get; private set; }

        public BaseBLManager(BLSettings settings)
        {
            CurrentBLSettings = settings;
        }
    }
}
