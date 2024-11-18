using System;
using System.Linq;
using System.Text;
using System.Threading.Tasks;
using System.Collections.Generic;

namespace Maba.Hydra2.Systems.MF.BL.ViewModelLayer.Models.User
{
    public class UserViewModelManager : Base.BaseViewModelManager
    {
        #region members

        private DAL.AdminLayer.Repositories.Account.IAccountRepository _AccountRepository = null;

        private DAL.AdminLayer.Repositories.Foldering.IFolderingRepository _FolderingRepository = null;

        #endregion

        #region ctor

        public UserViewModelManager(Base.ViewModelSettings currentSettings)
            : base(currentSettings)
        {
            _AccountRepository = currentSettings.DAL_AdminLayer_RepositoriesGenerator.Generator_IAccountRepository();
            _FolderingRepository = currentSettings.DAL_AdminLayer_RepositoriesGenerator.Generator_IFolderingRepository();
        }

        #endregion

        #region BaseViewModelManager members

        protected override void OnDispose()
        {
            if (_AccountRepository != null)
            {
                this._AccountRepository.Dispose();
            }
        }

        #endregion

        #region public methods

        #region User CRUD

        //public long CreateUser(Models.User.UserView user)
        //{
        //    var newUserID = _AccountRepository.AddUser(new DAL.AdminLayer.Models.AccountUser()
        //    {
        //        IdentityUserGUID = user.AccountUserGUID,
        //        CultureCode = user.CultureCode,
        //        Email = user.Email,
        //        FirstName = user.FirstName,
        //        LastName = user.LastName,
        //        LastToken = user.Token,
        //        UserID = user.UserID
        //    });

        //    return newUserID;
        //}

        public Models.User.UserView GetUser(long UserID)
        {
            var user = _AccountRepository.GetUser(UserID);

            return new UserView(user);
        }

        public Models.User.UserView GetUser(string UserEmail)
        {
            var user = _AccountRepository.GetUser(UserEmail);

            return new UserView(user);
        }

        #endregion

        #region messages actions

        public Messages.InboxMessagesView GetMessages(string UserEmail, int PageSize, int PageNumber)
        {
            DAL.BulksLayer.Repositories.InboxMessages.Models.InboxContentResponse inboxContent = null;
            using (var messagesRepository = this.CurrentSettings.DAL_BulksLayer_RepositoriesGenerator.Generator_IInboxMessagesRepository())
            {
                inboxContent = messagesRepository.GetInboxContent(UserEmail, null, null, PageSize, PageNumber);
            }

            if (inboxContent == null || inboxContent.Records == null)
            {
                return new Messages.InboxMessagesView()
                {
                    Result = false,
                    Messages = new Messages.InboxMessageRecordView[0]
                };
            }
            else
            {
                return new Messages.InboxMessagesView()
                {
                    Result = true,
                    PageSize = PageSize,
                    PageNumber = PageNumber,
                    TotalMessages = this.CountMessages(UserEmail),
                    Messages = inboxContent.Records
                       .Select(r => new Messages.InboxMessageRecordView(r))
                       .ToArray(),
                };
            }
        }

        public Messages.InboxMessageRecordView GetMessage(string UserEmail, string MessageID)
        {
            DAL.BulksLayer.Repositories.InboxMessages.Models.InboxMessageRecord record = null;
            using (var messagesRepository = this.CurrentSettings.DAL_BulksLayer_RepositoriesGenerator.Generator_IInboxMessagesRepository())
            {
                record = messagesRepository.GetMessage(UserEmail, MessageID);
            }
            return new Messages.InboxMessageRecordView(record);
        }

        public void AddMessage(Messages.InboxMessageRecordView messageView)
        {
            //create users
            var targetUser = new DAL.BulksLayer.Repositories.InboxMessages.Models.MessageUserInfo()
            {
                FirstName = messageView.TargetUserInfo.FirstName,
                LastName = messageView.TargetUserInfo.LastName,
                UserID = messageView.TargetUserInfo.UserID,
                UserEmail = messageView.TargetUserInfo.Email,
                ImgURL = messageView.TargetUserInfo.ImgURL
            };

            var sourceUser = new DAL.BulksLayer.Repositories.InboxMessages.Models.MessageUserInfo()
            {
                FirstName = messageView.SourceUser.FirstName,
                LastName = messageView.SourceUser.LastName,
                UserID = messageView.SourceUser.UserID,
                UserEmail = messageView.SourceUser.Email,
                ImgURL = messageView.SourceUser.ImgURL
            };

            //create the message
            var message = DAL.BulksLayer.Repositories.InboxMessages.Models.InboxMessageRecord.CreateMessage(targetUser, sourceUser, messageView.ConvertToBody());

            using (var messagesRepository = this.CurrentSettings.DAL_BulksLayer_RepositoriesGenerator.Generator_IInboxMessagesRepository())
            {
                //finally delete record
                var newMessageID = messagesRepository.AddMessage(message);

                //update total messages
                if (newMessageID)
                {
                    _AccountRepository.UpdateMessagesCount(messageView.TargetUserInfo.Email, 1);
                }
            }
        }

        public bool DeleteMessage(string UserEmail, string MessageID)
        {
            using (var messagesRepository = this.CurrentSettings.DAL_BulksLayer_RepositoriesGenerator.Generator_IInboxMessagesRepository())
            {
                //finally delete record
                var result = messagesRepository.DeleteMessage(UserEmail, MessageID);

                //update total messages
                if (result)
                {
                    result = _AccountRepository.UpdateMessagesCount(UserEmail, -1);
                }

                return result;
            }
        }

        public int CountMessages(string UserEmail)
        {
            return _AccountRepository.CountUserMessages(UserEmail);
        }

        public bool RefreshUserExhange(long newOwnerUserID)
        {
            return _AccountRepository.RefreshUserExhange(newOwnerUserID);
        }

        #region Foldering Message
        /// <summary>
        /// 
        /// </summary>
        /// <param name="RespondedUserID"></param>
        /// <param name="MessageID"></param>
        /// <param name="MessageStatus"></param>
        /// <param name="TargetFolderingProjectID">when null create new Project to this user. when -1 accept this new Share/Transfer as Root Project</param>
        /// <param name="TargetFolderingNewProjectName"></param>
        /// <returns></returns>
        /* public FolderingMessageResultView UpdateFolderingMessage(long RespondedUserID, string MessageID, Messages.FolderinHydra2teMessageView.MessagesStatus MessageStatus,
                                             long? TargetFolderingProjectID, string TargetFolderingNewProjectName)
         {
             var record = this.GetMessage(RespondedUserID, MessageID);
             if (record == null
                 || record.MessageType != Messages.MessagesTypes.FolderingMessage
                 || record.Record == null
                 || record.Record.GetType() != typeof(Messages.FolderinHydra2teMessageView)
                 || record.TargetUserInfo.UserID != RespondedUserID)
             {
                 return new FolderingMessageResultView()
                 {
                     Succeed = false
                 };
             }

             var folderingMessage = record.Record as Messages.FolderinHydra2teMessageView;

             #region handle message

             #region Add New project

             if (!TargetFolderingProjectID.HasValue && string.IsNullOrEmpty(TargetFolderingNewProjectName))
             {
                 if (!string.IsNullOrEmpty(TargetFolderingNewProjectName))
                 {
                     var temp_p = _FolderingRepository.GetSite(folderingMessage.SharingLevels.SiteID);
                     temp_p.Name = TargetFolderingNewProjectName;
                     TargetFolderingProjectID = _FolderingRepository.AddProject(temp_p, RespondedUserID);
                 }
                 else
                 {
                     return new FolderingMessageResultView()
                     {
                         Succeed = false
                     };
                 }
             }

             #endregion

             var response = new FolderingMessageResultView()
             {
                 Succeed = false
             };
             bool deleteMessage = true;

             switch (folderingMessage.FolderingType)
             {
                 case Messages.FolderinHydra2teMessageView.FolderingTypes.ProjectTransfer:
                 case Messages.FolderinHydra2teMessageView.FolderingTypes.SiteTransfer:
                     #region managing Transfer steps

                     switch (MessageStatus)
                     {
                         default:
                         case Messages.FolderinHydra2teMessageView.MessagesStatus.Active:
                             deleteMessage = false;
                             break;
                         case Messages.FolderinHydra2teMessageView.MessagesStatus.Accepted:
                             //when transferring entire project send -1 to DAL.
                             //It will transfer the SourceSiteID to be under TargetUserID as project.
                             if (_FolderingRepository.SiteTransfer_Accept(
                                                                                folderingMessage.SharingLevels.SiteID,
                                                                                record.SourceUser.UserID,

                                                                                TargetFolderingProjectID == -1 ? null : TargetFolderingProjectID,
                                                                                RespondedUserID))
                             {
                                 response.Succeed = true;
                                 response.ProjectID = TargetFolderingProjectID == -1 ? folderingMessage.SharingLevels.SiteID : TargetFolderingProjectID.Value;
                             }
                             break;
                         //case Messages.FolderinHydra2teMessageView.MessagesStatus.Delete:
                         //    response.Succeed = _FolderingRepository.SiteTransfer_Cancel(record.SourceUser.UserID, folderingMessage.SharingLevels.SiteID);
                         //    break;
                         case Messages.FolderinHydra2teMessageView.MessagesStatus.Rejected:
                             response.Succeed = _FolderingRepository.SiteTransfer_Reject(record.SourceUser.UserID, RespondedUserID, folderingMessage.SharingLevels.SiteID);

                             break;
                     }

                     #endregion
                     break;

                 case Messages.FolderinHydra2teMessageView.FolderingTypes.ProjectShared:
                 case Messages.FolderinHydra2teMessageView.FolderingTypes.SiteShared:
                     #region managing Sharing steps

                     switch (MessageStatus)
                     {
                         case Messages.FolderinHydra2teMessageView.MessagesStatus.Active:
                             deleteMessage = false;
                             break;
                         case Messages.FolderinHydra2teMessageView.MessagesStatus.Accepted:
                             if (_FolderingRepository.ShareSite_Accept(
                                                                                folderingMessage.SharingLevels.SiteID,
                                                                                record.SourceUser.UserID,
                                                                                RespondedUserID,
                                                                                TargetFolderingProjectID == -1 ? null : TargetFolderingProjectID))
                             {
                                 response.Succeed = true;
                                 response.ProjectID = TargetFolderingProjectID == -1 ? folderingMessage.SharingLevels.SiteID : TargetFolderingProjectID.Value;
                             }
                             break;
                         //case Messages.FolderinHydra2teMessageView.MessagesStatus.Delete:
                         //    response.Succeed = _FolderingRepository.SharedUsers_Delete(folderingMessage.SharingLevels.SiteID, record.SourceUser.UserID, record.SourceUser.UserID);
                         //    break;
                         case Messages.FolderinHydra2teMessageView.MessagesStatus.Rejected:
                             response.Succeed = _FolderingRepository.SharedUsers_Reject(folderingMessage.SharingLevels.SiteID, record.SourceUser.UserID, RespondedUserID);
                             break;
                     }

                     #endregion
                     break;
             }



             #endregion

             if (deleteMessage)
             {
                 using (var messagesRepository = this.CurrentSettings.DAL_BulksLayer_RepositoriesGenerator.Generator_IInboxMessagesRepository())
                 {
                     //finally delete record
                     var result = messagesRepository.DeleteMessage(record.TargetUserInfo.UserID, MessageID);

                     //update total messages
                     if (result)
                     {
                         _AccountRepository.UpdateMessagesCount(RespondedUserID, -1);
                     }
                 }
             }

             return response;
         }

         */
        #endregion

        #endregion

        #endregion
    }
}
