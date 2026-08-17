using DSL_CMS.BAL;
using DSL_CMS.Helpers;
using System;
using System.Data;
using System.Text;
using System.Web.UI;
using System.Web.UI.WebControls;

namespace DSL_CMS
{
    public partial class voucher_status : System.Web.UI.Page
    {
        protected Repeater rptStatus, rptWindows, rptSummary, rptPager, rptPerformance;
        protected PlaceHolder phEmpty, phPager, phPerfEmpty;
        protected Panel pnlWindows, pnlFilters, pnlProviderGrid, pnlPerformance;
        protected LinkButton lnkPrev, lnkNext, lnkEarlyExpiry;
        protected LinkButton kpiTotal, kpiUsed, kpiUnused, kpiExpiring, kpiInvalid;
        protected Literal litCountHead, litPageInfo, litCategoryNote,
                          litKpiTotal, litKpiTrend, litKpiUsed, litKpiUsedPct,
                          litKpiUnused, litKpiUnusedPct, litKpiExpiring, litKpiInvalid;

        private const int PageSize = 10;
        private const string StatusAll = "All";

        /// <summary>The window the "Expiring soon" card counts, and the one it opens.</summary>
        private const string ExpiringWindow = "30";

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

        /// <summary>
        /// Set from the sidebar, which is the only thing that offers it now that
        /// the category chips have gone from the filter bar.
        /// </summary>
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

        /// <summary>
        /// The row filters View Data will apply for this role. The dashboard has
        /// to use the same ones, or its numbers promise rows the next screen will
        /// not show: a sub-admin's grid lists only open entries, so counting the
        /// ones already moved to the done list made every figure too high.
        ///
        /// Mirrors MovedFilter / AssignedToFilter on voucher-data.aspx.cs.
        /// </summary>
        private string RowAssignedTo
        {
            get { return IsStudent ? Convert.ToString(Session["UserId"]) : string.Empty; }
        }

        private string RowIsMoved
        {
            get
            {
                if (IsStudent) return "0";
                if (string.Equals(VoucherRole, "Voucher Sub Admin", StringComparison.OrdinalIgnoreCase))
                    return "0";     // the dashboard opens the sub-admin's open list
                return string.Empty;
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

            // Coming back from View Data or Manage Product. Those screens hand the
            // provider back so the row reopens where it was left; the anchor on
            // the row takes care of the scroll, which a fresh GET would otherwise
            // start at the top of the page.
            string from = (Request.QueryString["providerId"] ?? string.Empty).Trim();
            if (from.Length > 0) ExpandedProvider = from;

            // The sidebar's Categories menu links back here with the category on
            // the query string; there is no chip row on the page any more.
            SelectedCategory = (Request.QueryString["category"] ?? string.Empty).Trim();

            BindStatusPills();
            ApplyStatus();
            BindGrid();
            BindKpis();
        }

        /// <summary>
        /// The figures across the top. Independent of the status pills - they
        /// describe the whole stock, which is the point of a summary.
        /// </summary>
        private void BindKpis()
        {
            DataTable dt = VoucherBAL.GetDashboardTotals(RowAssignedTo, RowIsMoved);
            if (dt == null || dt.Rows.Count == 0) return;

            DataRow r = dt.Rows[0];

            int total = Convert.ToInt32(r["TotalVoucher"]);
            int used = Convert.ToInt32(r["Used"]);
            int unused = Convert.ToInt32(r["Unused"]);
            int before = Convert.ToInt32(r["BeforeThisMonth"]);

            litKpiTotal.Text = total.ToString();
            litKpiUsed.Text = used.ToString();
            litKpiUnused.Text = unused.ToString();
            litKpiExpiring.Text = Convert.ToString(r["ExpiringSoon"]);
            litKpiInvalid.Text = Convert.ToString(r["Invalid"]);

            litKpiUsedPct.Text = Percent(used, total);
            litKpiUnusedPct.Text = Percent(unused, total);

            litKpiTrend.Text = TrendText(total, before);
        }

        private static string Percent(int part, int whole)
        {
            if (whole <= 0) return "0%";
            return Math.Round(part * 100.0 / whole, 1).ToString("0.#") + "%";
        }

        /// <summary>
        /// Growth since the 1st of this month, read off AddedDate. There is no
        /// daily snapshot of stock anywhere, so this measures what was added, and
        /// says nothing at all when there is no earlier month to compare against
        /// rather than inventing a percentage.
        /// </summary>
        private static string TrendText(int total, int before)
        {
            if (before <= 0) return "<span class=\"vs-num\">new this month</span>";

            double pct = (total - before) * 100.0 / before;
            string arrow = (pct >= 0) ? "&#9650;" : "&#9660;";
            string css = (pct >= 0) ? "vs-up" : "vs-down";

            return "<span class=\"" + css + "\">" + arrow + " "
                 + Math.Abs(Math.Round(pct, 1)).ToString("0.#") + "%</span> vs last month";
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

            lnkEarlyExpiry.CssClass = EarlyExpiry ? "vs-chip ghost on" : "vs-chip ghost";
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

            // Nothing on the page sets the category, so say where it came from
            // and offer the way out of it.
            litCategoryNote.Text = (SelectedCategory.Length == 0)
                ? string.Empty
                : "<span class=\"vs-catnote\">Category <b>" + Server.HtmlEncode(SelectedCategory)
                  + "</b><a href=\"" + Server.HtmlEncode(ResolveUrl("~/voucher-status.aspx"))
                  + "\" title=\"Show every category\">&times;</a></span>";
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

        private void BindGrid()
        {
            DataTable dt = VoucherBAL.GetProviderSummary(
                SelectedStatus, SelectedDays, SelectedCategory, string.Empty, string.Empty,
                RowAssignedTo, RowIsMoved);

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
            litPageInfo.Text = string.Format("Showing <b>{0}-{1}</b> of {2} providers", from, to, rowCount);

            rptPager.DataSource = Pager.Links(pageCount, PageIndex);
            rptPager.DataBind();

            // vs-pg, not the old pg: these two are set here rather than in the
            // markup, so they were the only pager buttons left unstyled.
            lnkPrev.CssClass = (PageIndex == 0) ? "vs-pg off" : "vs-pg";
            lnkNext.CssClass = (PageIndex >= pageCount - 1) ? "vs-pg off" : "vs-pg";
        }

        #endregion

        #region Events

        protected void rptStatus_ItemCommand(object source, RepeaterCommandEventArgs e)
        {
            if (e.CommandName != "PickStatus") return;
            PickStatus(Convert.ToString(e.CommandArgument));
        }

        /// <summary>
        /// The cards are the headline figures and each one is a shortcut to the
        /// rows behind it - a card that looks clickable and is not is worse than
        /// one that never offered.
        /// </summary>
        protected void kpi_Command(object sender, CommandEventArgs e)
        {
            string card = Convert.ToString(e.CommandArgument);

            if (string.Equals(card, "Expiring", StringComparison.OrdinalIgnoreCase))
            {
                // The card counts a 30 day window, so it opens the same one.
                SelectedStatus = StatusAll;
                EarlyExpiry = true;
                SelectedDays = ExpiringWindow;
                PageIndex = 0;

                BindStatusPills();
                ApplyStatus();
                BindGrid();
                return;
            }

            PickStatus(card);
        }

        /// <summary>
        /// Status and early expiry are two separate views of the same list, not
        /// filters that stack. Picking a status drops the expiry window, the same
        /// way picking the window drops the status.
        /// </summary>
        private void PickStatus(string status)
        {
            SelectedStatus = status;
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
            string css = "vs-chip " + StatusColourClass(value);

            if (!EarlyExpiry && string.Equals(value, SelectedStatus, StringComparison.OrdinalIgnoreCase))
                css += " on";

            return css.Trim();
        }

        /// <summary>The coloured dot on a status chip.</summary>
        protected string StatusPipStyle(object pillValue)
        {
            switch (Convert.ToString(pillValue).ToLowerInvariant())
            {
                case "used": return "background: var(--st-used);";
                case "unused": return "background: var(--st-unused);";
                case "expired": return "background: var(--st-expired);";
                case "invalid": return "background: var(--st-invalid);";
                case "notset": return "background: var(--st-notset);";
                default: return "background: var(--brand);";
            }
        }

        protected string WindowPillClass(object pillValue)
        {
            return string.Equals(Convert.ToString(pillValue), SelectedDays, StringComparison.Ordinal)
                ? "vs-chip on"
                : "vs-chip";
        }

        /// <summary>Pager links come back as "pg" / "pg on"; the new table wants vs-pg.</summary>
        protected string PagerClass(object cssClass)
        {
            string css = Convert.ToString(cssClass);
            return css.Replace("pg", "vs-pg");
        }

        protected string CaretClass(object providerId)
        {
            return IsExpanded(providerId) ? "vs-caret open" : "vs-caret";
        }

        protected string RowClass(object providerId)
        {
            return IsExpanded(providerId) ? "vs-prow open" : "vs-prow";
        }

        protected string ProviderTile(object providerId, object name)
        {
            return ProviderBrand.Tile(providerId, name, "logo");
        }

        protected bool IsExpanded(object providerId)
        {
            return string.Equals(Convert.ToString(providerId), ExpandedProvider, StringComparison.Ordinal);
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

        /// <summary>
        /// The products of an opened provider, as rows of the same table rather
        /// than a list tucked inside the provider cell - a product is a row of
        /// stock like its parent, and reads as one when the columns line up.
        ///
        /// Names, ids and counts arrive pipe separated in one column each and
        /// share an ORDER BY, so index N of one matches index N of the others.
        /// </summary>
        protected string ProductRows(object providerId, object productNames, object productIds,
            object productCounts)
        {
            if (!IsExpanded(providerId)) return string.Empty;

            string rawNames = Convert.ToString(productNames);

            // With a status picked, the proc has already dropped products holding
            // none of it - so an empty list here means exactly that.
            if (string.IsNullOrWhiteSpace(rawNames))
                return "<tr class=\"vs-subrow\"><td></td><td colspan=\"3\" class=\"vs-subnone\">"
                     + "No products to show under this filter.</td></tr>";

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

                sb.Append("<tr class=\"vs-subrow\"><td></td><td><span class=\"vs-prodname\">")
                  .Append("<span class=\"dot\"></span>").Append(Server.HtmlEncode(name))
                  .Append("</span></td><td class=\"c\"><span class=\"vs-subcount vs-num\">")
                  .Append(Server.HtmlEncode(count))
                  .Append("</span></td><td><div class=\"vs-rowacts\"><a class=\"vs-mini solid\" href=\"")
                  .Append(Server.HtmlEncode(ViewDataUrl(providerId, id)))
                  .Append("\">View Data</a>");

                if (CanManageProduct)
                    sb.Append("<a class=\"vs-mini\" href=\"")
                      .Append(Server.HtmlEncode(ManageProductUrl(providerId)))
                      .Append("\">Manage</a>");

                sb.Append("</div></td></tr>");
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
