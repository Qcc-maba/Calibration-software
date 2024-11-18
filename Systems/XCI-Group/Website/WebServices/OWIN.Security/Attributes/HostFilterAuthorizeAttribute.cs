using System;
using System.Collections.Generic;
using System.Linq;
using System.Net;
using System.Net.Http;
using System.Security.Claims;
using System.Security.Principal;
using System.Web;
using System.Web.Http;
using System.Web.Http.Controllers;
using System.Web.Http.Filters;

namespace Maba.Hydra2.Systems.XCIGroup.WebServices.OWIN.Security.Attributes
{
    public class HostFilterAuthorizeAttribute : AuthorizationFilterAttribute
    {
        #region CONSTANTS

        public const string LOCALHOST_FAKE__HEADER_NAME = "X-LOCALHOST";
        public const string LOCALHOST_FAKE__HEADER_VALUE = "FAKE";

        #endregion

        #region properties

        private string[] _RolesSplit = null;
        private string _Roles = null;
        public string Roles
        {
            get
            {
                return _Roles;
            }
            set
            {
                _Roles = value;
                _RolesSplit = _Roles
                                .Split(new char[] { ',' }, StringSplitOptions.RemoveEmptyEntries)
                                .Select(v => v.ToLower())
                                .ToArray();
            }
        }

        private int[] _RolesCodes = null;
        public int[] RolesCodes
        {
            get
            {
                return _RolesCodes;
            }
            set
            {
                _RolesCodes = value;
                _RolesCodes = _RolesCodes
                                .Where(v => v >= 0)
                                .ToArray();
            }
        }


        private string[] _ValidHostsSplit = null;
        private string _ValidHosts = null;
        public string ValidHosts
        {
            get
            {
                return _ValidHosts;
            }
            set
            {
                _ValidHosts = value;
                _ValidHostsSplit = _ValidHosts
                                            .Split(new char[] { ',' }, StringSplitOptions.RemoveEmptyEntries)
                                            .Select(v => v.ToLower())
                                            .ToArray();
            }
        }

        public bool OnlyLoopback { get; set; }

        #endregion

        public HostFilterAuthorizeAttribute()
            : base()
        {

        }

        #region overridden from AuthorizationFilterAttribute

        public override void OnAuthorization(HttpActionContext actionContext)
        {
            #region OnlyLoopback

            if (OnlyLoopback)
            {
                var faked = actionContext.Request.Headers.Any(h => h.Key == LOCALHOST_FAKE__HEADER_NAME && h.Value.Any(h1 => h1 == LOCALHOST_FAKE__HEADER_VALUE));

                if (!faked && !actionContext.Request.RequestUri.IsLoopback)
                {
                    actionContext.Response = new HttpResponseMessage(HttpStatusCode.Unauthorized);
                }
            }

            #endregion

            #region ValidHosts

            if (_ValidHostsSplit != null && _ValidHostsSplit.Length > 0)
            {
                if (!_ValidHostsSplit.Any(h => h == actionContext.Request.Headers.Host.ToLower()))
                {
                    actionContext.Response = new HttpResponseMessage(HttpStatusCode.Unauthorized);
                }
            }

            #endregion

            #region Roles

            //by roles string
            if (_RolesSplit != null && _RolesSplit.Length > 0)
            {
                IPrincipal user = actionContext.ControllerContext.RequestContext.Principal;
                var identity = user.Identity as ClaimsIdentity;

                if (!_RolesSplit.All(r => identity.Claims
                                                        .Any(c => c.Type == ClaimsIdentity.DefaultRoleClaimType && c.Value == r)))
                {
                    actionContext.Response = new HttpResponseMessage(HttpStatusCode.Unauthorized);
                }
            }

            //by int array
            if (_RolesCodes != null && _RolesCodes.Length > 0)
            {
                IPrincipal user = actionContext.ControllerContext.RequestContext.Principal;
                var identity = user.Identity as ClaimsIdentity;

                if (!_RolesCodes.All(r => identity.Claims
                                                        .Any(c => c.Type == ClaimsIdentity.DefaultRoleClaimType && c.Value == r.ToString())))
                {
                    actionContext.Response = new HttpResponseMessage(HttpStatusCode.Unauthorized);
                }
            }

            #endregion
        }

        #endregion

        #region private methods

        private static readonly string[] _emptyArray = new string[0];
        private string[] SplitString(string original)
        {
            if (String.IsNullOrEmpty(original))
            {
                return _emptyArray;
            }

            var split = from piece in original.Split(',')
                        let trimmed = piece.Trim()
                        where !String.IsNullOrEmpty(trimmed)
                        select trimmed;
            return split.ToArray();
        }

        #endregion
    }
}