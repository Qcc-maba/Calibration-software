using System;

namespace Maba.VCT.ComLayer
{
    #region Delegate

    public delegate void LayerDestroyedDelegate(object sender, DestroyedEventArgs e);

    #endregion

    public class DestroyedEventArgs : EventArgs
    {
        #region ctor

        public DestroyedEventArgs()
            : base()
        {

        }

        #endregion
    }
}