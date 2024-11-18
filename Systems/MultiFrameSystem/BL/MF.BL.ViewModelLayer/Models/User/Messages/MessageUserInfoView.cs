using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.User.Messages
{
    public class MessageUserInfoView
    {
        #region properties

        public string Email { get; set; }
        public string FirstName { get; set; }
        public string LastName { get; set; }
        public string ImgURL { get; set; }

        public long UserID { get; set; }

        #endregion

        #region ctor(s)

        public MessageUserInfoView()
        {

        }

        public MessageUserInfoView(DAL.AdminLayer.Models.AccountUser user)
        {
            UserID = user.UserID;
            Email = user.Email;
            FirstName = user.FirstName;
            LastName = user.LastName;
            ImgURL = user.ImgURL;
        }

        public MessageUserInfoView(DAL.BulksLayer.Repositories.InboxMessages.Models.MessageUserInfo userInfo)
        {
            Email = userInfo.UserEmail;

            FirstName = userInfo.FirstName;
            LastName = userInfo.LastName;
            ImgURL = userInfo.ImgURL;
        }

        #endregion

       
    }
}
