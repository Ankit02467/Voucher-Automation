using DSL_CMS.BAL;
using System;
using System.Data;
using System.IO;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace DSL_CMS
{
    /// <summary>
    /// Implemented by a page that wants the topbar search box. The master shows
    /// the box only for pages that can actually do something with it, rather
    /// than offering a search that searches nothing.
    /// </summary>
    public interface ISearchablePage
    {
        /// <summary>False when the page is showing something the box cannot narrow.</summary>
        bool SearchEnabled { get; }

        void ApplySearch(string term);
    }

    public partial class MasterPage : System.Web.UI.MasterPage
    {
        protected LinkButton lnkLogout;
        protected Panel pnlSearch;
        protected TextBox txtTopSearch;
        protected Button btnTopSearch;
        protected Literal litUserRole;

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

        /// <summary>Up to two letters for the avatar tile.</summary>
        public string UserInitials
        {
            get
            {
                string name = CurrentUserName.Trim();
                if (name.Length == 0) return "?";

                string[] parts = name.Split(new[] { ' ' }, StringSplitOptions.RemoveEmptyEntries);
                if (parts.Length == 1)
                    return parts[0].Substring(0, Math.Min(2, parts[0].Length)).ToUpperInvariant();

                return (parts[0].Substring(0, 1) + parts[parts.Length - 1].Substring(0, 1)).ToUpperInvariant();
            }
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            if (Session["UserId"] == null)
            {
                Response.Redirect(ResolveUrl("~/login.aspx"), true);
                return;
            }

            // Only offered where it does something. The page's own Load has
            // already run by now, so it knows which view it is showing.
            var searchable = Page as ISearchablePage;
            pnlSearch.Visible = (searchable != null && searchable.SearchEnabled);

            litUserRole.Text = Server.HtmlEncode(VoucherRole());
        }

        /// <summary>
        /// Looked up once and kept in Session - it would otherwise be a database
        /// round trip on every page load just to letter a subtitle.
        /// </summary>
        private string VoucherRole()
        {
            var cached = Session["VoucherRole"] as string;
            if (cached != null) return cached;

            string role = string.Empty;
            try
            {
                DataTable dt = VoucherBAL.GetUserRole(Convert.ToString(Session["UserId"]));
                if (dt != null && dt.Rows.Count > 0)
                    role = Convert.ToString(dt.Rows[0]["RoleName"]).Trim();
            }
            catch { }

            if (role.Length == 0) role = "Voucher Admin";

            Session["VoucherRole"] = role;
            return role;
        }

        protected void btnTopSearch_Click(object sender, EventArgs e)
        {
            var target = Page as ISearchablePage;
            if (target != null) target.ApplySearch(txtTopSearch.Text.Trim());
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
