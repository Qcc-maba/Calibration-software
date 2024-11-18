using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.Hydra2.Systems.Common.CommonWebAPI.DependencyResolves
{
    public class BaseControllerDependencyResolver<T> : CustomDependencyResolver where T : BaseSettingsCarrier
    {
        public T CurrentCarrier { get; private set; }

        public BaseControllerDependencyResolver(T currentSettings)
            : base()
        {
            this.GetServiceFunc = new Func<Type, object>(ControllerResolver);

            CurrentCarrier = currentSettings;
        }

        public object ControllerResolver(Type serviceType)
        {
            if (serviceType == typeof(Controllers.BaseController<T>) || serviceType.IsSubclassOf(typeof(Controllers.BaseController<T>)))
            {
                var controller = Activator.CreateInstance(serviceType) as Controllers.BaseController<T>;
                controller.Carrier = CurrentCarrier;

                return controller;
            }
            return null;
        }
    }
}
