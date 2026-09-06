using System;

namespace Maba.VCT.Common
{
    /// <summary>
    /// Who is signed in at this calibration station, for the lifetime of the ComServer process.
    ///
    /// WHY THIS EXISTS
    /// ---------------
    /// The calibrator's e-mail decides which loggers and which measurement channels this station
    /// loads from SQL (dbo.GetLogersConfiguredByCalibrator, dbo.AssignMeasurmentDevicesToCalibrator).
    /// It used to come only from CalibratorUserEmail in App.config, which meant every installation
    /// had to be hand-edited per technician and a station configured for one person loaded that
    /// person's loggers no matter who actually signed in.
    ///
    /// The ComServer starts before anyone signs in and is a separate process from the browser, so
    /// it cannot read the session cookie and cannot know the user on its own. The web app tells it:
    /// any WebSocket message may carry an "Email" field (see BaseMessage.Email), and the first one
    /// that does sets the station's identity here. App.config remains the fallback for unattended
    /// runs (a Windows service with no UI, or --dump-calibrator-loggers from the command line).
    /// </summary>
    public static class CalibratorSession
    {
        private static readonly object Gate = new object();
        private static string _email;

        /// <summary>Raised when the signed-in user changes, so settings loaded for the previous
        /// user can be re-read. Not raised when the same address arrives again.</summary>
        public static event EventHandler<string> EmailChanged;

        /// <summary>The signed-in calibrator's e-mail, or null while nobody has announced one.</summary>
        public static string Email
        {
            get { lock (Gate) { return _email; } }
        }

        /// <summary>
        /// Records the signed-in user. Ignores blank input so a message without the field never
        /// clears an identity that is already established.
        /// </summary>
        /// <returns>true if this changed the signed-in user.</returns>
        public static bool SetEmail(string email)
        {
            if (string.IsNullOrWhiteSpace(email))
            {
                return false;
            }

            var trimmed = email.Trim();
            string previous;

            lock (Gate)
            {
                if (string.Equals(_email, trimmed, StringComparison.OrdinalIgnoreCase))
                {
                    return false;
                }

                previous = _email;
                _email = trimmed;
            }

            Console.WriteLine("[LOGIN] Calibrator is now " + trimmed +
                (previous == null ? " (was: nobody)" : " (was: " + previous + ")"));

            var handler = EmailChanged;
            if (handler != null)
            {
                handler(null, trimmed);
            }

            return true;
        }

        /// <summary>Forgets the signed-in user (sign-out, or the web app disconnecting).</summary>
        public static void Clear()
        {
            lock (Gate)
            {
                _email = null;
            }
        }
    }
}
