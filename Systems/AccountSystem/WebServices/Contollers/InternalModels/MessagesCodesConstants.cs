using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.WebServices.Contollers.InternalModels
{
    internal class MessagesCodesConstants
    {
        public const int LOGIN_ERROR__ERROR_INVALID_EMAIL = 10;
        public const int LOGIN_ERROR__ERROR_MISMATCH_PASSWORDS = 11;

        public const int CONFIRMEMAIL_ERROR__FAILED_EMAIL_CONFIRMATION = 20;

        public const int RESET_PASSWORD_ERROR__PASSWORDS_MISMATCH = 30;
        public const int RESET_PASSWORD_ERROR__INVALID_EMAIL = 31;
        public const int RESET_PASSWORD_ERROR__INVALID_TOKEN = 31;

        public const int UPDATE_PROFILE_ERROR__INVALID_EMAIL = 40;
        public const int UPDATE_PROFILE_ERROR__INVALID_EMAIL__SELF_REJECTED = 41;

        public const int ADMIN_UPDATE_ERROR__USER = 50;
        public const int ADMIN_UPDATE_ERROR__INVALID_EMAIL = 51;


        public const int REGISTER_ERROR__USER_PHONE_VERIFICATION_ERROR = 3;
        public const int REGISTER_ERROR__USER_ALREADY_EXISTS = 4;
        public const int REGISTER_ERROR__USER_WRONG_PASSWORD = 5;
        public const int REGISTER_ERROR__ERROR_CREATE_USER_1 = 6;
        public const int REGISTER_ERROR__ERROR_CREATE_USER_2 = 7;
        public const int REGISTER_ERROR__ERROR_CREATE_USER_CLAIMS = 8;
    }
}
