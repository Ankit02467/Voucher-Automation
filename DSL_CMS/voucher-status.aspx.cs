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
        protected Repeater rptStatus, rptWindows, rptCategory, rptSummary, rptPager, rptPerformance;
        protected PlaceHolder phEmpty, phPager, phPerfEmpty;
        protected Panel pnlWindows, pnlFilters, pnlProviderGrid, pnlPerformance;
        protected LinkButton lnkPrev, lnkNext, lnkEarlyExpiry;
        protected HyperLink lnkStudentPerf, lnkProductPerf;
        protected Literal litCountHead, litPageInfo;

        private const int PageSize = 10;
        private const string StatusAll = "All";

        /// <summary>
        /// Status pills. "All" is the default and counts every voucher; "NotSet"
        /// counts fresh uploads nobody has triaged yet (Status IS NULL).
        /// </summary>
        private static readonly ListItem[] StatusPills =
        {
            new ListItem("All",     StatusAll),
            new ListItem("Not Set", "NotSet"),
            new ListItem("Used",    "Used"),
            new ListItem("Unused",  "Unused"),
            new ListItem("Expired", "Expired"),
            new ListItem("Invalid", "Invalid")
        };

        /// <summary>
        /// Expiry windows. These belong to "View Early Expiry" only - picking the
        /// Unused status no longer reveals them.
        /// </summary>
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

        /// <summary>
        /// Selected expiry window in days; blank means no expiry restriction.
        /// Only meaningful while <see cref="EarlyExpiry"/> is on.
        /// </summary>
        private string SelectedDays
        {
            get { return (string)(ViewState["Days"] ?? string.Empty); }
            set { ViewState["Days"] = value; }
        }

        /// <summary>
        /// "View Early Expiry" toggle. The 1 / 3 / 7 Day and 1 Month buttons are
        /// shown only while this is on, whatever status is selected.
        /// </summary>
        private bool EarlyExpiry
        {
            get { return (bool)(ViewState["Early"] ?? false); }
            set { ViewState["Early"] = value; }
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

        /// <summary>A student gets their own performance figures instead of the provider summary.</summary>
        private bool IsStudent
        {
            get { return string.Equals(VoucherRole, "Voucher Student", StringComparison.OrdinalIgnoreCase); }
        }

        /// <summary>Student wise performance is open to admin and sub-admin.</summary>
        protected bool CanSeeStudentPerformance
        {
            get
            {
                return string.Equals(VoucherRole, "Voucher Admin", StringComparison.OrdinalIgnoreCase)
                    || string.Equals(VoucherRole, "Voucher Sub Admin", StringComparison.OrdinalIgnoreCase);
            }
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

            lnkStudentPerf.Visible = CanSeeStudentPerformance;
            lnkStudentPerf.NavigateUrl = ResolveUrl("~/student-performance.aspx");

            lnkProductPerf.Visible = CanManageProduct;   // admin only
            lnkProductPerf.NavigateUrl = ResolveUrl("~/product-performance.aspx");

            // A student gets their own figures here; everyone else gets the
            // provider summary with its filters.
            pnlFilters.Visible = !IsStudent;
            pnlProviderGrid.Visible = !IsStudent;
            pnlPerformance.Visible = IsStudent;

            if (IsStudent)
            {
                BindPerformance();
                return;
            }

            BindStatusPills();
            BindCategoryPills();
            ApplyStatus();
            BindGrid();
        }

        /// <summary>
        /// The signed-in student's own checked-voucher counts, one row per
        /// provider. View Data stays reachable from each row so the student can
        /// still get to their work from here.
        /// </summary>
        private void BindPerformance()
        {
            DataTable dt = VoucherBAL.GetPerformanceByProvider(Convert.ToString(Session["UserId"]));

            rptPerformance.DataSource = dt;
            rptPerformance.DataBind();

            phPerfEmpty.Visible = (dt == null || dt.Rows.Count == 0);
        }

        /// <summary>
        /// The single count column is headed with whatever status is selected.
        /// The expiry windows belong to "View Early Expiry" and are independent of
        /// the status pills - selecting Unused must not reveal them.
        /// </summary>
        private void ApplyStatus()
        {
            litCountHead.Text = StatusLabel(SelectedStatus);

            lnkEarlyExpiry.CssClass = EarlyExpiry ? "pill-btn on" : "pill-btn";
            pnlWindows.Visible = EarlyExpiry;

            if (EarlyExpiry)
            {
                rptWindows.DataSource = Windows;
                rptWindows.DataBind();
            }
            else
            {
                SelectedDays = string.Empty;
            }
        }

        /// <summary>Pill value to the wording used in the column heading.</summary>
        private static string StatusLabel(string status)
        {
            return string.Equals(status, "NotSet", StringComparison.Ordinal) ? "Not Set" : status;
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

            // Status and early expiry are two separate views of the same list, not
            // filters that stack. Picking a status drops the expiry window, the
            // same way picking the window drops the status.
            SelectedStatus = Convert.ToString(e.CommandArgument);
            EarlyExpiry = false;
            SelectedDays = string.Empty;
            PageIndex = 0;

            BindStatusPills();
            ApplyStatus();
            BindGrid();
        }

        /// <summary>
        /// Toggles the early-expiry window buttons into view. Switching it off
        /// drops any window that was picked, so the grid goes back to every date.
        /// </summary>
        protected void lnkEarlyExpiry_Click(object sender, EventArgs e)
        {
            EarlyExpiry = !EarlyExpiry;

            if (EarlyExpiry)
            {
                // switching into the expiry view clears whatever status was picked,
                // so the two are never lit at once
                SelectedStatus = StatusAll;
            }
            else
            {
                SelectedDays = string.Empty;
            }

            PageIndex = 0;

            BindStatusPills();   // repaint so the old status pill loses its highlight
            ApplyStatus();
            BindGrid();
        }

        protected void rptWindows_ItemCommand(object source, RepeaterCommandEventArgs e)
        {
            if (e.CommandName != "PickDays") return;

            string picked = Convert.ToString(e.CommandArgument);

            // Clicking the active window clears it and drops the date restriction.
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

        /// <summary>Used = red, Unused = green, Expired = yellow, Invalid = blue, Not Set = grey, All = plain.</summary>
        internal static string StatusColourClass(string status)
        {
            switch ((status ?? string.Empty).ToLowerInvariant())
            {
                case "used": return "s-used";
                case "unused": return "s-unused";
                case "expired": return "s-expired";
                case "invalid": return "s-invalid";
                case "notset": return "s-notset";
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

        /// <summary>
        /// Renders the pipe separated product names as a vertical list of links.
        /// Names and ids arrive in the same order, so index N of one matches index
        /// N of the other. Each link opens View Data already narrowed to that one
        /// product, carrying the status and expiry window along with it.
        /// </summary>
        protected string ProductLinks(object providerId, object productNames, object productIds,
            object productCounts)
        {
            string rawNames = Convert.ToString(productNames);

            // With a status picked, the proc has already dropped products holding
            // none of it - so an empty list here means exactly that.
            if (string.IsNullOrWhiteSpace(rawNames))
                return "<span class=\"muted\">No data to show yet.</span>";

            string[] names = rawNames.Split('|');
            string[] ids = Convert.ToString(productIds).Split('|');
            string[] counts = Convert.ToString(productCounts).Split('|');

            var sb = new StringBuilder();
            for (int i = 0; i < names.Length; i++)
            {
                string name = names[i].Trim();
                if (name.Length == 0) continue;

                string id = (i < ids.Length) ? ids[i].Trim() : string.Empty;
                string count = (i < counts.Length) ? counts[i].Trim() : string.Empty;

                sb.Append("<a class=\"prod-link\" href=\"")
                  .Append(Server.HtmlEncode(ViewDataUrl(providerId, id)))
                  .Append("\">")
                  .Append(Server.HtmlEncode(name));

                // the figure explains why a product is or is not in this list
                if (count.Length > 0)
                    sb.Append("<span class=\"prod-count\">").Append(Server.HtmlEncode(count)).Append("</span>");

                sb.Append("</a>");
            }
            return sb.ToString();
        }

        /// <summary>
        /// Carries the selected status and early-expiry window through to View
        /// Data, so that screen opens showing exactly the slice this page counted.
        /// "All" is passed through too and clears the filter.
        /// </summary>
        protected string ViewDataUrl(object providerId)
        {
            return ViewDataUrl(providerId, string.Empty);
        }

        protected string ViewDataUrl(object providerId, string productId)
        {
            var sb = new StringBuilder(ResolveUrl("~/voucher-data.aspx"));
            sb.Append("?providerId=").Append(Server.UrlEncode(Convert.ToString(providerId)));
            sb.Append("&status=").Append(Server.UrlEncode(SelectedStatus));

            if (!string.IsNullOrEmpty(productId))
                sb.Append("&productId=").Append(Server.UrlEncode(productId));

            if (EarlyExpiry && SelectedDays.Length > 0)
                sb.Append("&days=").Append(Server.UrlEncode(SelectedDays));

            return sb.ToString();
        }

        protected string ManageProductUrl(object providerId)
        {
            return ResolveUrl("~/manage-product.aspx?providerId=") + Convert.ToString(providerId);
        }

        #endregion
    }
}
