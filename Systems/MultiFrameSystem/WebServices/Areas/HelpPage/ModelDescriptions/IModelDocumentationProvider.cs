using System;
using System.Reflection;

namespace Maba.Hydra2.Systems.MF.WebServices.Areas.HelpPage.ModelDescriptions
{
    public interface IModelDocumentationProvider
    {
        string GetDocumentation(MemberInfo member);

        string GetDocumentation(Type type);
    }
}