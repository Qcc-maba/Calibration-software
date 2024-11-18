using System;
using System.Reflection;

namespace Maba.Hydra2.Systems.XCIGroup.WebServices.Areas.HelpPage.ModelDescriptions
{
    public interface IModelDocumentationProvider
    {
        string GetDocumentation(MemberInfo member);

        string GetDocumentation(Type type);
    }
}