using DSL_CMS.BAL;
using DSL_CMS.Helpers;
using System;
using System.Collections.Generic;
using System.Data;
using System.Text;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace DSL_CMS
{
    public partial class voucher_status : System.Web.UI.Page
    {
        protected Repeater rptStatus, rptWindows, rptCategory, rptSummary, rptPager;
        protected PlaceHolder phEmpty, phPager;
        protected Panel pnlWindows;
        protected LinkButton lnkPrev, lnkNext;
        protected Literal litCountHead, litPageInfo;

        private const int PageSize = 10;
        private const string StatusAll = "All";

        /// <summary>Status pills. "All" is the default and counts every voucher.</summary>
        private static readonly ListItem[] StatusPills =
        {
            new ListItem("All",     StatusAll),
            new ListItem("Used",    "Used"),
            new ListItem("Unused",  "Unused"),
            new ListItem("Expired", "Expired"),
            new ListItem("Invalid", "Invalid")
        };

        /// <summary>Expiry windows, offered only while Unused is selected.</summary>
        private static readonly ListItem[] Windows =
        {
            new ListItem("1 Day",   "1"),
            new ListItem("3 Days",  "3"),
            new ListItem("7 Days",  "7"),
            new ListItem("1 Month", "30")
        };

        #region State

        public string SelectedStatus
        {
            get { return (string)(ViewState["Status"] ?? StatusAll); }
            set { ViewState["Status"] = value; }
        }

        public string SelectedCategory
        {
            get { return (string)(ViewState["Category"] ?? string.Empty); }
            set { ViewState["Category"] = value; }
        }

        /// <summary>Selected expiry window in days; blank means the whole Unused set.</summary>
        private string SelectedDays
        {
            get { return (string)(ViewState["Days"] ?? string.Empty); }
            set { ViewState["Days"] = value; }
        }

        /// <summary>Provider whose product list is currently expanded, if any.</summary>
        private string ExpandedProvider
        {
            get { return (string)(ViewState["Expanded"] ?? string.Empty); }
            set { ViewState["Expanded"] = value; }
        }

        private int PageIndex
        {
            get { return (int)(ViewState["Page"] ?? 0); }
            set { ViewState["Page"] = value; }
        }

        protected int RowOffset { get { return PageIndex * PageSize; } }

        /// <summary>Manage Product is an admin-only action.</summary>
        protected bool CanManageProduct
        {
            get { return string.Equals(VoucherRole, "Voucher Admin", StringComparison.OrdinalIgnoreCase); }
        }

        private string VoucherRole
        {
            get
            {
                string cached = ViewState["Role"] as string;
                if (cached != null) return cached;

                DataTable dt = VoucherBAL.GetUserRole(Convert.ToString(Session["UserId"]));
                string role = (dt != null && dt.Rows.Count > 0)
                    ? Convert.ToString(dt.Rows[0]["RoleName"]).Trim()
                    : string.Empty;

                // Users with no voucher role mapped fall back to admin, as on View Data.
                if (role.Length == 0) role = "Voucher Admin";

                ViewState["Role"] = role;
                return role;
            }
        }

        #endregion

        protected void Page_Load(object sender, EventArgs e)
        {
            if (IsPostBack) return;

            BindStatusPills();
            BindCategoryPills();
            ApplyStatus();
            BindGrid();
        }

        /// <summary>
        /// The single count column is headed with whatever status is selected,
        /// and the expiry windows only make sense for Unused.
        /// </summary>
        private void ApplyStatus()
        {
            litCountHead.Text = SelectedStatus;

            bool unused = (SelectedStatus == "Unused");
            pnlWindows.Visible = unused;

            if (unused)
            {
                rptWindows.DataSource = Windows;
                rptWindows.DataBind();
            }
            else
            {
                SelectedDays = string.Empty;
            }
        }

        #region Binding

        private void BindStatusPills()
        {
            rptStatus.DataSource = StatusPills;
            rptStatus.DataBind();
        }

        private void BindCategoryPills()
        {
            DataTable dt = VoucherBAL.GetProviderSummary(StatusAll, string.Empty,
                string.Empty, string.Empty, string.Empty);

            var seen = new List<string>();
            DataTable categories = new DataTable();
            categories.Columns.Add("Category", typeof(string));

            if (dt != null)
            {
                foreach (DataRow r in dt.Rows)
                {
                    string category = Convert.ToString(r["Category"]).Trim();
                    if (category.Length > 0 && !seen.Contains(category))
                    {
                        seen.Add(category);
                        categories.Rows.Add(category);
                    }
                }
            }

            rptCategory.DataSource = categories;
            rptCategory.DataBind();
        }

        private void BindGrid()
        {
            DataTable dt = VoucherBAL.GetProviderSummary(
                SelectedStatus, SelectedDays, SelectedCategory, string.Empty, string.Empty);

            int rowCount = (dt == null) ? 0 : dt.Rows.Count;
            int pageCount = Pager.PageCount(rowCount, PageSize);

            if (PageIndex >= pageCount) PageIndex = pageCount - 1;
            if (PageIndex < 0) PageIndex = 0;

            rptSummary.DataSource = Pager.Slice(dt, PageIndex, PageSize);
            rptSummary.DataBind();

            phEmpty.Visible = (rowCount == 0);
            BindPager(rowCount, pageCount);
        }

        private void BindPager(int rowCount, int pageCount)
        {
            phPager.Visible = (rowCount > 0);
            if (!phPager.Visible) return;

            int from = (PageIndex * PageSize) + 1;
            int to = Math.Min(from + PageSize - 1, rowCount);
            litPageInfo.Text = string.Format("Showing {0}-{1} of {2}", from, to, rowCount);

            rptPager.DataSource = Pager.Links(pageCount, PageIndex);
            rptPager.DataBind();

            lnkPrev.CssClass = (PageIndex == 0) ? "pg off" : "pg";
            lnkNext.CssClass = (PageIndex >= pageCount - 1) ? "pg off" : "pg";
        }

        #endregion

        #region Events

        protected void rptStatus_ItemCommand(object source, RepeaterCommandEventArgs e)
        {
            if (e.CommandName != "PickStatus") return;

            SelectedStatus = Convert.ToString(e.CommandArgument);
            SelectedDays = string.Empty;
            PageIndex = 0;

            BindStatusPills();
            ApplyStatus();
            BindGrid();
        }

        protected void rptWindows_ItemCommand(object source, RepeaterCommandEventArgs e)
        {
            if (e.CommandName != "PickDays") return;

            string picked = Convert.ToString(e.CommandArgument);

            // Clicking the active window clears it and shows all unused again.
            SelectedDays = (SelectedDays == picked) ? string.Empty : picked;
            PageIndex = 0;

            ApplyStatus();
            BindGrid();
        }

        protected void rptCategory_ItemCommand(object source, RepeaterCommandEventArgs e)
        {
            if (e.CommandName != "PickCategory") return;

            string picked = Convert.ToString(e.CommandArgument);
            SelectedCategory = (SelectedCategory == picked) ? string.Empty : picked;
            PageIndex = 0;

            BindCategoryPills();
            BindGrid();
        }

        protected void rptSummary_ItemCommand(object source, RepeaterCommandEventArgs e)
        {
            if (e.CommandName != "ToggleProducts") return;

            string id = Convert.ToString(e.CommandArgument);
            ExpandedProvider = (ExpandedProvider == id) ? string.Empty : id;

            BindGrid();
        }

        protected void rptPager_ItemCommand(object source, RepeaterCommandEventArgs e)
        {
            if (e.CommandName != "Go") return;
            int index;
            if (int.TryParse(Convert.ToString(e.CommandArgument), out index) && index >= 0)
                PageIndex = index;
            BindGrid();
        }

        protected void lnkPrev_Click(object sender, EventArgs e)
        {
            if (PageIndex > 0) PageIndex--;
            BindGrid();
        }

        protected void lnkNext_Click(object sender, EventArgs e)
        {
            PageIndex++;
            BindGrid();
        }

        #endregion

        #region Template helpers

        protected string StatusPillClass(object pillValue)
        {
            string value = Convert.ToString(pillValue);
            string css = "pill-btn " + StatusColourClass(value);

            if (string.Equals(value, SelectedStatus, StringComparison.OrdinalIgnoreCase))
                css += " on";

            return css.TrimEnd();
        }

        protected string WindowPillClass(object pillValue)
        {
            return string.Equals(Convert.ToString(pillValue), SelectedDays, StringComparison.Ordinal)
                ? "pill-btn on"
                : "pill-btn";
        }

        protected string CategoryPillClass(object pillValue)
        {
            return string.Equals(Convert.ToString(pillValue), SelectedCategory, StringComparison.OrdinalIgnoreCase)
                ? "pill-btn on"
                : "pill-btn";
        }

        /// <summary>Used = red, Unused = green, Expired = yellow, Invalid = blue, All = plain.</summary>
        internal static string StatusColourClass(string status)
        {
            switch ((status ?? string.Empty).ToLowerInvariant())
            {
                case "used": return "s-used";
                case "unused": return "s-unused";
                case "expired": return "s-expired";
                case "invalid": return "s-invalid";
                default: return string.Empty;
            }
        }

        protected bool IsExpanded(object providerId)
        {
            return string.Equals(Convert.ToString(providerId), ExpandedProvider, StringComparison.Ordinal);
        }

        protected string ChevronClass(object providerId)
        {
            return IsExpanded(providerId) ? "chev-icon open" : "chev-icon";
        }

        /// <summary>Renders the pipe separated product names as chips.</summary>
        protected string ProductChips(object productNames)
        {
            string raw = Convert.ToString(productNames);
            if (string.IsNullOrWhiteSpace(raw)) return "<span class=\"muted\">No products.</span>";

            var sb = new StringBuilder();
            foreach (string name in raw.Split('|'))
            {
                if (name.Trim().Length == 0) continue;
                sb.Append("<span class=\"prod-chip\">")
                  .Append(Server.HtmlEncode(name.Trim()))
                  .Append("</span>");
            }
            return sb.ToString();
        }

        /// <summary>
        /// Carries the selected status through to View Data, so that screen opens
        /// showing the same slice. "All" is passed through too and clears the filter.
        /// </summary>
        protected string ViewDataUrl(object providerId)
        {
            return ResolveUrl("~/voucher-data.aspx?providerId=") + Convert.ToString(providerId)
                 + "&status=" + Server.UrlEncode(SelectedStatus);
        }

        protected string ManageProductUrl(object providerId)
        {
            return ResolveUrl("~/manage-product.aspx?providerId=") + Convert.ToString(providerId);
        }

        #endregion
    }
}
