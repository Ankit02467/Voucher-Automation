using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DSL_CMS.DAL
{
    public class LoginDAL
    {
        public static DataTable SelectUserLoginDetails(string UserName, string Password)
        {
            return SqlHelper.ExecuteDataTable("Sp_User_Table", true, "@Action", "SelectLoginDetail", "@Email", UserName, "@Password", Password);
        }

        public static DataTable SelectGetMenuByUsers(int UserId)
        {
            return SqlHelper.ExecuteDataTable("SP_GetMenuByUsers", true, "@Userid", UserId);
        }

        public static DataTable SP_GetUserPermission(int Userid)
        {
            return SqlHelper.ExecuteDataTable("SP_GetUserPermission", true, "@Userid", Userid);
        }
    }
}
