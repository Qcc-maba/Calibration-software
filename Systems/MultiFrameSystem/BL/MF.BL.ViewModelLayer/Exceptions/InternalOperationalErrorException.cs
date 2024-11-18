using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Exceptions
{
    public class InternalOperationalErrorException : Exception
    {
        public InternalOperationalErrorException()
        {

        }

        public InternalOperationalErrorException(string message) : base(message)
        {

        }
    }
}
