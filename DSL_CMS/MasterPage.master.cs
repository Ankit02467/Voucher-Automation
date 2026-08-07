using System;
using System.IO;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace DSL_CMS
{
    public partial class MasterPage : System.Web.UI.MasterPage
    {
        protected LinkButton lnkLogout;

        /// <summary>
        /// Cache buster appended to css/js links. Changes whenever the site is
        /// rebuilt, so browsers can never serve a stale stylesheet.
        /// </summary>
        public string AssetVersion
        {
            get
            {
                object cached = Application["AssetVersion"];
                if (cached != null) return (string)cached;

                string version;
                try
                {
                    string dll = typeof(MasterPage).Assembly.Location;
                    version = File.GetLastWriteTimeUtc(dll).Ticks.ToString();
                }
                catch
                {
                    version = DateTime.UtcNow.Ticks.ToString();
                }

                Application["AssetVersion"] = version;
                return version;
            }
        }

        /// <summary>Name shown in the top bar.</summary>
        public string CurrentUserName
        {
            get
            {
                var name = Session["FullName"] as string;
                return string.IsNullOrEmpty(name) ? "Guest" : name;
            }
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            if (Session["UserId"] == null)
                Response.Redirect(ResolveUrl("~/login.aspx"), true);
        }

        /// <summary>Marks the sidebar link for the page currently being served.</summary>
        protected string NavClass(string page)
        {
            var current = Path.GetFileName(Request.AppRelativeCurrentExecutionFilePath ?? string.Empty);
            return string.Equals(current, page, StringComparison.OrdinalIgnoreCase) ? "active" : string.Empty;
        }

        protected void lnkLogout_Click(object sender, EventArgs e)
        {
            Session.Clear();
            Session.Abandon();
            Response.Redirect(ResolveUrl("~/login.aspx"), true);
        }
    }
}
