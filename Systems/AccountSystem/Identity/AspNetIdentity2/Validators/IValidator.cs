using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace Maba.AccountSystem.AspNetIdentity.Identity2.Validators
{
    public interface IValidator<in T>
    {
        Task<ActionResult> ValidateAsync(T item);
    }
}
