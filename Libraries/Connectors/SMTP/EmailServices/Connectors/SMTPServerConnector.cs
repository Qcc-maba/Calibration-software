using System;
using System.Collections.Generic;
using System.Linq;
using System.Net.Mail;
using System.Text;
using System.Threading.Tasks;
//using System.Threading.Tasks.Dataflow;

namespace Maba.Connectors.EmailServices.Connectors
{
    //public class SMTPServerConnector : IEmailSenderConnector
    //{
    //    //#region CONSTANTS

    //    //public const string CONNECTOR_TYPE = "Default";

    //    //#endregion

    //    //#region private methods

    //    //System.Net.Mail.SmtpClient _InternalSender = null;

    //    //#endregion

    //    //#region properties

    //    //public EmailServiceSettings Settings { get; set; }

    //    //#endregion

    //    #region ctor

    //    public SMTPServerConnector(EmailServiceSettings settings)
    //    {
    //        //Settings = settings;
    //    }

    //    #endregion

    //    //#region private methods
    //    //private async Task<bool> _Send(EmailMessage message)
    //    //{
    //    //    message.Status = ProccesStatues.Sending;

    //    //    if (_InternalSender == null)
    //    //    {
    //    //        _InternalSender = new System.Net.Mail.SmtpClient();
    //    //        _InternalSender.Port = Settings.Port;
    //    //        _InternalSender.UseDefaultCredentials = Settings.UseDefaultCredentials;
    //    //        _InternalSender.Host = Settings.Host;
    //    //        _InternalSender.Credentials = new System.Net.NetworkCredential(Settings.Credential_UserName, Settings.Credential_Password);
    //    //        _InternalSender.EnableSsl = Settings.EnableSsl;
    //    //        _InternalSender.Timeout = Settings.Timeout;
    //    //    }
    //    //    try
    //    //    {
    //    //        var sender = String.IsNullOrEmpty(Settings.DefaultFromAddress) ? message.From : (Settings.ForceSenderAddress ? Settings.DefaultFromAddress : message.From);
    //    //        var From_DisplayName = String.IsNullOrEmpty(Settings.DefaultDisplayName) ? message.From_DisplayName : Settings.DefaultDisplayName;
    //    //        // Create the message:
    //    //        using (var mail = new System.Net.Mail.MailMessage(new MailAddress(sender, From_DisplayName), new MailAddress(message.To, message.To_DisplayName)))
    //    //        {
    //    //            mail.Subject = message.Subject;
    //    //            mail.Body = message.Body;
    //    //            mail.IsBodyHtml = true;

    //    //            #region CC

    //    //            if (message.CC != null && message.CC.Length > 0)
    //    //            {
    //    //                foreach (var cc in message.CC)
    //    //                {
    //    //                    mail.CC.Add(cc);
    //    //                }
    //    //            }

    //    //            #endregion

    //    //            #region BCC

    //    //            if (message.BCC != null && message.BCC.Length > 0)
    //    //            {
    //    //                foreach (var bcc in message.BCC)
    //    //                {
    //    //                    mail.Bcc.Add(bcc);
    //    //                }
    //    //            }

    //    //            #endregion

    //    //            #region Attachments (if any)

    //    //            if (message.Attachments != null && message.Attachments.Length > 0)
    //    //            {
    //    //                foreach (var a in message.Attachments)
    //    //                {
    //    //                    mail.Attachments.Add(a);
    //    //                }
    //    //            }

    //    //            #endregion

    //    //            await _InternalSender.SendMailAsync(mail);

    //    //            message.Status = ProccesStatues.Sent;

    //    //            if (SendingMessage != null)
    //    //            {
    //    //                SendingMessage.BeginInvoke(this, new SendingMessageEventArgs(message, true, DateTime.UtcNow), null, null);
    //    //            }

    //    //            return true;
    //    //        }
    //    //    }
    //    //    catch (System.Exception e)
    //    //    {
    //    //        message.Status = ProccesStatues.SendingFailed;

    //    //        try
    //    //        {
    //    //            _InternalSender.Dispose();
    //    //        }
    //    //        catch { }

    //    //        if (SendingMessage != null)
    //    //        {
    //    //            SendingMessage.BeginInvoke(this, new SendingMessageEventArgs(message, false, DateTime.UtcNow) { Error = e }, null, null);
    //    //        }

    //    //        return false;
    //    //    }

    //    //}

    //    //#endregion

    //    //#region IEmailSenderConnector members

    //    //public event SendingMessageDelegate SendingMessage;

    //    //public bool Send(EmailMessage message, int timeoutMilliseconds)
    //    //{
    //    //    message.Status = ProccesStatues.Pending;
    //    //    message.PostedDate = DateTime.UtcNow;

    //    //    var task = _Send(message);
    //    //    return task.Wait(timeoutMilliseconds);
    //    //}

    //    //public async Task<bool> SendAsync(EmailMessage message)
    //    //{
    //    //    message.Status = ProccesStatues.Pending;
    //    //    message.PostedDate = DateTime.UtcNow;

    //    //    return await _Send(message);
    //    //}

    //    //#endregion

    //    //#region IDisposable members

    //    //public void Dispose()
    //    //{
    //    //    if (_InternalSender != null)
    //    //    {
    //    //        _InternalSender.Dispose();
    //    //        _InternalSender = null;
    //    //    }
    //    //}

    //    //#endregion

    //}

}
