using System;
using System.Collections.Generic;
using System.Linq;
using System.Security.Claims;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.Common
{
    public static class ClaimsIdentityExtentions
    {
        #region CONSTNATS

        public const string CLAIM_PREFIX = "urn:Maba";
        public const string CLAIM_GUID = "guid";
        public const string CLAIM_TEMPERAURE_UNIT = "temp";
        public const string CLAIM_CULTURE_CODE = "culture";

        #endregion

        public static string GetClaimValue(this ClaimsIdentity identity, string claimType, string defaultValue = null)
        {
            var claim = identity.Claims.FirstOrDefault(c => c.Type == claimType);

            if (claim == null)
                return defaultValue;

            return claim.Value;
        }

        public static bool ChangeClaimValue(this ClaimsIdentity identity, string claimType, string NewValue)
        {
            var claim = identity.Claims.FirstOrDefault(c => c.Type == claimType);
            if (claim == null)
            {
                identity.AddClaim(new Claim(claimType, NewValue));
                return true;
            }
            else
            {
                identity.RemoveClaim(claim);
                identity.AddClaim(new Claim(claimType, NewValue));
                return false;
            }
        }

        public static bool SetUserGUID(this ClaimsIdentity identity, string value)
        {
            var claimType = $"{CLAIM_PREFIX}:{CLAIM_GUID}";
            return ChangeClaimValue(identity, claimType, value);
        }

        public static string GetUserGUID(this ClaimsIdentity identity)
        {
            var claimType = $"{CLAIM_PREFIX}:{CLAIM_GUID}";
            return GetClaimValue(identity, claimType);
        }

        public static string GetEmail(this ClaimsIdentity identity)
        {
            return GetClaimValue(identity, ClaimTypes.Email);
        }

        public static long GetUserId(this ClaimsIdentity identity)
        {
            var claimValue = GetClaimValue(identity, ClaimTypes.Sid);

            if (claimValue == null)
                return -1;

            return long.Parse(claimValue);
        }
        public static bool SetUserId(this ClaimsIdentity identity, long UserID)
        {
            return ChangeClaimValue(identity, ClaimTypes.Sid, UserID.ToString());
        }

        public static string GetUserTemperatureUnit(this ClaimsIdentity identity)
        {
            var claimType = $"{CLAIM_PREFIX}:{CLAIM_TEMPERAURE_UNIT}";

            return GetClaimValue(identity, claimType) ?? null;
        }
        public static bool SetUserTemperatureUnit(this ClaimsIdentity identity, string TemperatureUnit)
        {
            var claimType = $"{CLAIM_PREFIX}:{CLAIM_TEMPERAURE_UNIT}";

            return ChangeClaimValue(identity, claimType, TemperatureUnit);
        }
        public static string GetUserCultureCode(this ClaimsIdentity identity)
        {
            var claimType = $"{CLAIM_PREFIX}:{CLAIM_CULTURE_CODE}";

            return GetClaimValue(identity, claimType) ?? null;
        }
        public static bool SetUserCultureCode(this ClaimsIdentity identity, string CultureCode)
        {
            var claimType = $"{CLAIM_PREFIX}:{CLAIM_CULTURE_CODE}";

            return ChangeClaimValue(identity, claimType, CultureCode);
        }
    }
}
