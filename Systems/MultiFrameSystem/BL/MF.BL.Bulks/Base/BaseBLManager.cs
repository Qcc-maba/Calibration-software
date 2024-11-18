using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.Bulks.Base
{
    public class BaseBLManager
    {
        public Base.BLSettings CurrentBLSettings { get; private set; }

        public BaseBLManager(Base.BLSettings settings)
        {
            CurrentBLSettings = settings;
        }
    }
}
