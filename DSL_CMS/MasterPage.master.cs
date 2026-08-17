using DSL_CMS.BAL;
using DSL_CMS.Helpers;
using System;
using System.Data;
using System.IO;
using System.Text;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace DSL_CMS
{
    public partial class MasterPage : System.Web.UI.MasterPage
    {
        protected LinkButton lnkLogout;
        protected Literal litUserRole;
        protected Repeater rptNavProviders, rptNavCategories;
        protected PlaceHolder phNavProductPerf, phNavStudentPerf, phNavAddProvider;

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

        /// <summary>The date shown beside the user, spelled out rather than 13/08/2026.</summary>
        public string TodayLong
        {
            get { return DateTime.Now.ToString("ddd, dd MMM yyyy"); }
        }

        protected void Page_Load(object sender, EventArgs e)
        {
            if (Session["UserId"] == null)
            {
                Response.Redirect(ResolveUrl("~/login.aspx"), true);
                return;
            }

            litUserRole.Text = Server.HtmlEncode(VoucherRole());

            // Rebuilt on every request, postback included: a provider added on
            // Manage Product has to appear in the menu without a fresh login,
            // and the counts beside each name go stale the moment a voucher
            // changes status.
            BindNav();
        }

        #region Sidebar menu

        private void BindNav()
        {
            string role = VoucherRole();

            bool admin = string.Equals(role, "Voucher Admin", StringComparison.OrdinalIgnoreCase);

            phNavProductPerf.Visible = admin;
            phNavAddProvider.Visible = admin;
            phNavStudentPerf.Visible = admin
                || string.Equals(role, "Voucher Sub Admin", StringComparison.OrdinalIgnoreCase);

            rptNavProviders.DataSource = NavProviders();
            rptNavProviders.DataBind();

            rptNavCategories.DataSource = NavCategories();
            rptNavCategories.DataBind();
        }

        private DataTable NavCategories()
        {
            try { return VoucherBAL.GetProviderCategories(); }
            catch { return null; }
        }

        /// <summary>
        /// Providers with their product lists, counted the same way Voucher
        /// Status counts them. Scoped by role for the same reason that page is:
        /// a student reading 24 in the menu and then landing on 3 rows is the
        /// dashboard mismatch all over again, one panel to the left.
        /// </summary>
        private DataTable NavProviders()
        {
            try
            {
                // Narrowed by the chips above it, so the tree lists the same
                // providers the page is showing rather than contradicting it.
                return VoucherBAL.GetProviderSummary("All", string.Empty, CurrentCategory,
                    string.Empty, string.Empty, NavAssignedTo, NavIsMoved);
            }
            catch
            {
                // The menu is furniture. A database that is down must not take
                // every page down with it - the page itself will report that.
                return null;
            }
        }

        /// <summary>Mirrors RowAssignedTo / RowIsMoved on voucher-status.aspx.cs.</summary>
        private string NavAssignedTo
        {
            get
            {
                return string.Equals(VoucherRole(), "Voucher Student", StringComparison.OrdinalIgnoreCase)
                    ? Convert.ToString(Session["UserId"])
                    : string.Empty;
            }
        }

        private string NavIsMoved
        {
            get
            {
                string role = VoucherRole();
                if (string.Equals(role, "Voucher Student", StringComparison.OrdinalIgnoreCase)) return "0";
                if (string.Equals(role, "Voucher Sub Admin", StringComparison.OrdinalIgnoreCase)) return "0";
                return string.Empty;
            }
        }

        protected string ProviderTile(object providerId, object name)
        {
            return ProviderBrand.Tile(providerId, name, "lg");
        }

        /// <summary>
        /// The products under one provider, as links straight into View Data.
        /// Names, ids and counts arrive pipe separated in one column each and
        /// share an ORDER BY, so index N of one matches index N of the others.
        /// </summary>
        protected string NavProducts(object providerId, object productNames, object productIds,
            object productCounts)
        {
            string rawNames = Convert.ToString(productNames);
            if (string.IsNullOrWhiteSpace(rawNames))
                return "<span class=\"navnone\">No products yet</span>";

            string[] names = rawNames.Split('|');
            string[] ids = Convert.ToString(productIds).Split('|');
            string[] counts = Convert.ToString(productCounts).Split('|');

            string data = ResolveUrl("~/voucher-data.aspx");
            var sb = new StringBuilder();

            for (int i = 0; i < names.Length; i++)
            {
                string name = names[i].Trim();
                if (name.Length == 0) continue;

                string id = (i < ids.Length) ? ids[i].Trim() : string.Empty;
                string count = (i < counts.Length) ? counts[i].Trim() : string.Empty;

                sb.Append("<a class=\"navprod\" href=\"").Append(Server.HtmlEncode(data))
                  .Append("?providerId=").Append(Server.UrlEncode(Convert.ToString(providerId)));

                if (id.Length > 0)
                    sb.Append("&amp;productId=").Append(Server.UrlEncode(id));

                sb.Append("\"><span class=\"dot\"></span><span class=\"nm\">")
                  .Append(Server.HtmlEncode(name))
                  .Append("</span>");

                if (count.Length > 0)
                    sb.Append("<span class=\"cnt\">").Append(Server.HtmlEncode(count)).Append("</span>");

                sb.Append("</a>");
            }

            return sb.ToString();
        }

        protected string ProviderDataUrl(object providerId)
        {
            return ResolveUrl("~/voucher-data.aspx?providerId=") + Convert.ToString(providerId);
        }

        protected string CategoryUrl(object category)
        {
            return ResolveUrl("~/voucher-status.aspx?category=")
                 + Server.UrlEncode(Convert.ToString(category));
        }

        /// <summary>
        /// Lights the category the page is currently narrowed to. Pass null for
        /// the "All" chip, which is lit while nothing is narrowing the page.
        /// </summary>
        protected string CategoryChipClass(object category)
        {
            return string.Equals(CurrentCategory, Convert.ToString(category).Trim(),
                       StringComparison.OrdinalIgnoreCase)
                ? "navchip on"
                : "navchip";
        }

        private string CurrentCategory
        {
            get { return (Request.QueryString["category"] ?? string.Empty).Trim(); }
        }

        #endregion

        #region Breadcrumb

        /// <summary>
        /// Leaf of the breadcrumb. Read off the file being served rather than
        /// set by each page, so a new screen picks one up by being added here
        /// instead of by remembering to assign it.
        /// </summary>
        public string PageLabel
        {
            get
            {
                switch (CurrentPage.ToLowerInvariant())
                {
                    case "voucher-status.aspx": return "Voucher Status";
                    case "voucher-data.aspx": return "View Data";
                    case "manage-product.aspx": return "Manage Product";
                    case "add-provider.aspx": return "Add Provider";
                    case "product-performance.aspx": return "Product wise Performance";
                    case "student-performance.aspx": return "Student wise Performance";
                    case "dashboard.aspx": return "Dashboard";
                    default: return "Voucher Portal";
                }
            }
        }

        private string CurrentPage
        {
            get { return Path.GetFileName(Request.AppRelativeCurrentExecutionFilePath ?? string.Empty); }
        }

        #endregion

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

        /// <summary>Marks the sidebar link for the page currently being served.</summary>
        protected string NavClass(string page)
        {
            return string.Equals(CurrentPage, page, StringComparison.OrdinalIgnoreCase)
                ? "active"
                : string.Empty;
        }

        /// <summary>
        /// Voucher Status owns the provider tree, so its group starts open on
        /// the screens that tree leads to as well as on the page itself.
        /// </summary>
        protected string NavGroupClass()
        {
            string page = CurrentPage.ToLowerInvariant();
            bool inside = page == "voucher-status.aspx"
                       || page == "voucher-data.aspx"
                       || page == "manage-product.aspx";

            return inside ? "navgroup open" : "navgroup";
        }

        protected void lnkLogout_Click(object sender, EventArgs e)
        {
            Session.Clear();
            Session.Abandon();
            Response.Redirect(ResolveUrl("~/login.aspx"), true);
        }
    }
}
