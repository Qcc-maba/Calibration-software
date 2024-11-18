using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.MF.DAL.AdminLayer.Repositories
{
    internal class GeneralHelper
    {
        private static long COUNTER_UserID = 9990000;
        private static List<Models.AccountUser> _CreatedUsers = new List<Models.AccountUser>();
        private static List<Models.GlobalizationZone> _GlobalizationZones = new List<Models.GlobalizationZone>();
        static private Random rand = new Random();

        static GeneralHelper()
        {
            using (var rep_account = new Account.TSQL.TSQLAccountRepository())
            {
                _GlobalizationZones = rep_account
                                            .GetGlobalizationZones(null)
                                            .ToList();
            }
        }

        public static Models.AccountUser CreateTesterUser()//int? level = 0)
        {
            var level = rand.Next(0, 9999);

            long _UserID = (COUNTER_UserID * 10000) + level;
            COUNTER_UserID++;

            using (var rep_account = new Account.TSQL.TSQLAccountRepository())
            {
                var _user = new Models.AccountUser()
                {
                    Email = $"test{level}@test-t{level}.com",
                    FirstName = $"tester-{level}",
                    LastName = $"Zalman-{level}",
                    CultureCode = "us-en",
                    UserID = _UserID,
                    ImgURL = $"http://walla.co.il/abc1234567890/xyz1234567890/ert1234567890/tester-{level}",
                    TimeZoneID = _GlobalizationZones[rand.Next(0, _GlobalizationZones.Count - 1)].ZoneID,
                    IdentityUserGUID = Guid.NewGuid().ToString()
                };


                var exists_ByID = rep_account.GetUser(_user.UserID);
                if (exists_ByID != null)
                {
                    rep_account.DeleteUser(_user.UserID);
                }
                var exists_ByEmail = rep_account.GetUser(_user.Email);
                if (exists_ByEmail != null)
                {
                    rep_account.DeleteUser(exists_ByEmail.UserID);
                }

                var _userID = rep_account.AddUser(_user);

                _user = rep_account.GetUser(_user.UserID);

                _CreatedUsers.Add(_user);

                return _user;
            }
        }


        public static void Init()
        {
            _CreatedUsers.Clear();
        }
        public static void Clean()
        {
            using (var rep_account = new Account.TSQL.TSQLAccountRepository())
            {
                foreach (var u in _CreatedUsers)
                {
                    rep_account.DeleteUser(u.UserID);
                }
            }
        }
    }
}
