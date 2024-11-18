using System;

namespace Maba.VCT.DIGI.APIProtocol
{
    #region Delegate
    public delegate void NotificationDelegate(object sender, NewNodeNotificationEventArgs e);
    #endregion

    public class NewNodeNotificationEventArgs : EventArgs
    {
        #region properties

        public RemoteEndpoint Node { get; private set; }

        #endregion

        #region ctor(s)

        public NewNodeNotificationEventArgs(RemoteEndpoint C)
            : base()
        {
            Node = C;
        }

        #endregion
    }
}