using System;
using System.Collections.Generic;
using System.Linq;
using System.Web;
using System.Web.Http.Dependencies;

namespace Maba.Hydra2.Systems.Common.CommonWebAPI.DependencyResolves
{
    public class CustomDependencyResolver : IDependencyResolver
    {
        #region properties

        public Func<Type, object> GetServiceFunc { get; protected set; }

        #endregion

        #region ctor

        protected CustomDependencyResolver()
        {

        }

        public CustomDependencyResolver(Func<Type,object> getServiceFunc)
        {
            GetServiceFunc = getServiceFunc;
        }

        #endregion

        #region override from IDependencyResolver

        public IDependencyScope BeginScope()
        {
            return this;
        }

        public object GetService(Type serviceType)
        {
            return GetServiceFunc(serviceType);
        }

        public IEnumerable<object> GetServices(Type serviceType)
        {
            return new object[0];
        }

        public void Dispose()
        {
        }

        #endregion
    }
}