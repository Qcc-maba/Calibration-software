using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.BulksLayer.Repositories.InboxMessages.Models
{
    public class MessageUserInfo
    {
        public string UserEmail { get; set; }
        public long UserID { get; set; }
        public string UserGUID { get; set; }
        public string FirstName { get; set; }
        public string LastName { get; set; }
        public string ImgURL { get; set; }
    }
}
