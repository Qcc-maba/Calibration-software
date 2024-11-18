using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace Maba.VCT.CommServer.Monitor
{
    class DeviceRecord<T> where T : class
    {
        public enum Actions
        {
            Idle,
            New,
            Update,
            Remove
        }

        private Actions _ActionToDo = Actions.Idle;

        public Actions ActionToDo
        {
            get
            {
                return _ActionToDo;
            }
            set
            {
                if (value != Actions.Remove && _ActionToDo == Actions.Remove)
                {

                }

                _ActionToDo = value;
            }
        }
        public T Device { get; set; }

        public ListViewItem ViewItem { get; set; }
    }
}
