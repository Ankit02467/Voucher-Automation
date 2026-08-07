using DSL_CMS.BAL;
using System;
using System.Data;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace DSL_CMS
{
    public partial class login : System.Web.UI.Page
    {
        protected TextBox txtEmail;
        protected TextBox txtPassword;
        protected Button btnLogin;
        protected Panel pnlMsg;
        protected Literal litMsg;

        /// <summary>Cache buster for the stylesheet - changes on every rebuild.</summary>
        public string AssetVersion
        {
            get
            {
                try
                {
                    return System.IO.File
                        .GetLastWriteTimeUtc(typeof(login).Assembly.Location).Ticks.ToString();
                }
                catch
                {
                    return DateTime.UtcNow.Ticks.ToString();
                }
            }
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            if (!IsPostBack && Session["UserId"] != null)
                Response.Redirect("~/voucher-status.aspx", true);
        }

        protected void btnLogin_Click(object sender, EventArgs e)
        {
            var email = (txtEmail.Text ?? string.Empty).Trim();
            var password = (txtPassword.Text ?? string.Empty).Trim();

            if (email.Length == 0 || password.Length == 0)
            {
                ShowError("Please enter both email and password.");
                return;
            }

            try
            {
                // User_Table stores passwords Base64 encoded (e.g. "123" -> "MTIz").
                DataTable dt = LoginBAL.SelectUserLoginDetails(email, Encode(password));

                if (dt == null || dt.Rows.Count == 0)
                {
                    ShowError("Invalid email or password.");
                    return;
                }

                DataRow row = dt.Rows[0];
                Session["UserId"] = Convert.ToString(row["Id"]);
                Session["FullName"] = Convert.ToString(row["FullName"]);
                Session["Email"] = Convert.ToString(row["Email"]);
                Session["UserType"] = Convert.ToString(row["UserType"]);

                Response.Redirect("~/voucher-status.aspx", true);
            }
            catch (System.Threading.ThreadAbortException)
            {
                throw;   // Response.Redirect - let it through
            }
            catch (Exception ex)
            {
                ShowError("Login failed: " + ex.Message);
            }
        }

        /// <summary>Matches the Base64 password format already used in User_Table.</summary>
        private static string Encode(string plainText)
        {
            return Convert.ToBase64String(System.Text.Encoding.UTF8.GetBytes(plainText));
        }

        private void ShowError(string message)
        {
            litMsg.Text = Server.HtmlEncode(message);
            pnlMsg.Visible = true;
        }
    }
}
