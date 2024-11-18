using Microsoft.AspNet.Identity;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.UserManager.UnitTest
{
    class TestableIdentityMessageService : IIdentityMessageService
    {
        public List<IdentityMessage> _SentMessages { get; private set; }

        #region ctor

        public TestableIdentityMessageService()
        {
            _SentMessages = new List<IdentityMessage>();
        }

        #endregion

        #region static methods

        public void Clear()
        {
            lock (_SentMessages)
            {
                _SentMessages.Clear();
            }
        }

        #endregion

        #region IIdentityMessageService

        public System.Threading.Tasks.Task SendAsync(IdentityMessage message)
        {
            lock (_SentMessages)
            {
                _SentMessages.Add(message);
            }

            return Task.FromResult<object>(null);

        }

        #endregion
    }
}
