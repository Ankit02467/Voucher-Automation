using DSL_CMS.DAL;
using System;
using System.Collections.Generic;
using System.Data;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace DSL_CMS.BAL
{
    public class LoginBAL
    {
        public static DataTable SelectUserLoginDetails(string UserName, string Password)
        {
            return LoginDAL.SelectUserLoginDetails(UserName, Password);
        }

        public static DataTable SelectGetMenuByUsers(int UserId)
        {
            return LoginDAL.SelectGetMenuByUsers(UserId);
        }

        public static DataTable SP_GetUserPermission(int Userid)
        {
            return LoginDAL.SP_GetUserPermission(Userid);
        }
    }
}
