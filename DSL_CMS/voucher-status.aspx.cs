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
        protected Repeater rptStatus, rptWindows, rptSummary, rptPager, rptPerformance;
        protected PlaceHolder phEmpty, phPager, phPerfEmpty;
        protected Panel pnlWindows, pnlFilters, pnlProviderGrid, pnlPerformance, pnlDenied;
        protected LinkButton lnkPrev, lnkNext, lnkEarlyExpiry;
        protected LinkButton kpiTotal, kpiUsed, kpiUnused, kpiExpiring, kpiInvalid, kpiNotSet;
        protected LinkButton lnkSortName, lnkSortCount;
        protected Literal litCountHead, litPageInfo, litCategoryNote,
                          litKpiTotal, litKpiTrend, litKpiUsed, litKpiUsedPct,
                          litKpiUnused, litKpiUnusedPct, litKpiExpiring, litKpiInvalid,
                          litKpiNotSet, litSortName, litSortCount;

        private const int PageSize = 10;
        private const string StatusAll = "All";

        /// <summary>Sortable columns of the provider table.</summary>
        private const string SortByName = "Name";
        private const string SortByCount = "StatusCount";

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

        /// <summary>
        /// Which providers have their product list open, as a delimited list of
        /// ids. A set rather than the single id this used to hold: with one
        /// value, opening a second provider silently shut the first, so clicking
        /// "+" on one row made another row's products disappear.
        ///
        /// Kept as a string because ViewState has to serialise it, and this is a
        /// handful of integers rather than a collection worth its own type.
        /// </summary>
        private string ExpandedProviders
        {
            get { return (string)(ViewState["Expanded"] ?? string.Empty); }
            set { ViewState["Expanded"] = value; }
        }

        private const char ExpandedSep = ',';

        private bool IsProviderOpen(string id)
        {
            if (id.Length == 0) return false;

            foreach (string held in ExpandedProviders.Split(ExpandedSep))
                if (held == id) return true;

            return false;
        }

        /// <summary>Opens or closes one provider, leaving every other one as it is.</summary>
        private void SetProviderOpen(string id, bool open)
        {
            if (id.Length == 0) return;

            var kept = new List<string>();
            foreach (string held in ExpandedProviders.Split(ExpandedSep))
                if (held.Length > 0 && held != id) kept.Add(held);

            if (open) kept.Add(id);

            ExpandedProviders = string.Join(ExpandedSep.ToString(), kept.ToArray());
        }

        private int PageIndex
        {
            get { return (int)(ViewState["Page"] ?? 0); }
            set { ViewState["Page"] = value; }
        }

        protected int RowOffset { get { return PageIndex * PageSize; } }

        /// <summary>
        /// Which column the provider table is ordered by. Defaults to the
        /// provider name, so the list reads alphabetically before anyone has
        /// touched a header - the proc returns rows in Id order, which is the
        /// order they happened to be created in and means nothing to a reader.
        ///
        /// Sorted here rather than in the proc because the header has to be able
        /// to change it, and a round trip per click to re-order six rows is work
        /// the page can do itself.
        /// </summary>
        private string SortKey
        {
            get { return (string)(ViewState["SortKey"] ?? SortByName); }
            set { ViewState["SortKey"] = value; }
        }

        private bool SortDesc
        {
            get { return (bool)(ViewState["SortDesc"] ?? false); }
            set { ViewState["SortDesc"] = value; }
        }

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

                // Blank when nothing is mapped and the fallback is off, which
                // Page_Load turns into a refusal. Helpers/VoucherAccess.cs.
                bool unmapped;
                string role = VoucherAccess.Effective(Session["UserId"], out unmapped);

                ViewState["Role"] = role;
                return role;
            }
        }

        #endregion

        protected void Page_Load(object sender, EventArgs e)
        {
            if (IsPostBack) return;

            // No voucher role and no fallback: nothing on this screen is theirs
            // to see. Checked before anything binds, so no query runs either.
            if (VoucherRole.Length == 0)
            {
                pnlDenied.Visible = true;
                pnlFilters.Visible = false;
                pnlProviderGrid.Visible = false;
                pnlPerformance.Visible = false;
                return;
            }

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
            if (from.Length > 0) SetProviderOpen(from, true);

            // The sidebar's Categories menu links back here with the category on
            // the query string; there is no chip row on the page any more.
            SelectedCategory = (Request.QueryString["category"] ?? string.Empty).Trim();

            BindStatusPills();
            ApplyStatus();
            BindGrid();
            BindKpis();
        }

        /// <summary>
        /// The figures across the top. Independent of the status pills - a card
        /// per status is what the summary is for, so narrowing them by the
        /// selected status would leave one card holding everything.
        ///
        /// They DO follow the category, because that is a different question:
        /// the sidebar's IT / Language narrows which providers are in scope at
        /// all, and the provider table underneath already obeys it. While these
        /// cards ignored it, All, IT and Language every one read the same totals.
        /// </summary>
        private void BindKpis()
        {
            DataTable dt = VoucherBAL.GetDashboardTotals(RowAssignedTo, RowIsMoved, SelectedCategory);
            if (dt == null || dt.Rows.Count == 0) return;

            DataRow r = dt.Rows[0];

            int total = Num(r, "TotalVoucher");
            int used = Num(r, "Used");
            int unused = Num(r, "Unused");
            int before = Num(r, "BeforeThisMonth");

            litKpiTotal.Text = total.ToString();
            litKpiUsed.Text = used.ToString();
            litKpiUnused.Text = unused.ToString();
            litKpiExpiring.Text = Num(r, "ExpiringSoon").ToString();
            litKpiInvalid.Text = Num(r, "Invalid").ToString();
            litKpiNotSet.Text = Num(r, "NotSet").ToString();

            litKpiUsedPct.Text = Percent(used, total);
            litKpiUnusedPct.Text = Percent(unused, total);

            litKpiTrend.Text = TrendText(total, before);
        }

        /// <summary>
        /// A count off the totals row. SUM(CASE ...) over an empty stock table
        /// returns NULL, not 0 - so on a database with no vouchers in it yet
        /// every card here is DBNull while COUNT(*) still reads 0. Convert.ToInt32
        /// throws on that, which is a yellow screen on the first page after login.
        /// </summary>
        private static int Num(DataRow r, string column)
        {
            if (!r.Table.Columns.Contains(column)) return 0;

            object v = r[column];
            if (v == null || v == DBNull.Value) return 0;

            int n;
            return int.TryParse(Convert.ToString(v), out n) ? n : 0;
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

            dt = ApplySort(dt);
            ApplySortHeads();

            int rowCount = (dt == null) ? 0 : dt.Rows.Count;
            int pageCount = Pager.PageCount(rowCount, PageSize);

            if (PageIndex >= pageCount) PageIndex = pageCount - 1;
            if (PageIndex < 0) PageIndex = 0;

            rptSummary.DataSource = Pager.Slice(dt, PageIndex, PageSize);
            rptSummary.DataBind();

            phEmpty.Visible = (rowCount == 0);
            BindPager(rowCount, pageCount);
        }

        /// <summary>
        /// Orders the provider rows before they are paged. Sorting after the
        /// slice would only shuffle whichever ten rows page 1 happened to hold.
        ///
        /// Name is compared case-insensitively so "aws" and "AWS" do not land in
        /// two different places; DataView cannot be told to ignore case, so the
        /// comparison runs off a sort column added here rather than off Name.
        /// </summary>
        private DataTable ApplySort(DataTable dt)
        {
            if (dt == null || dt.Rows.Count == 0) return dt;

            string key = SortKey;
            if (!dt.Columns.Contains(key)) key = SortByName;
            if (!dt.Columns.Contains(key)) return dt;   // nothing to sort on

            string order = key;

            if (key == SortByName)
            {
                const string shadow = "__NameSort";
                if (!dt.Columns.Contains(shadow))
                {
                    dt.Columns.Add(shadow, typeof(string));
                    foreach (DataRow row in dt.Rows)
                        row[shadow] = Convert.ToString(row[SortByName]).Trim().ToUpperInvariant();
                }
                order = shadow;
            }

            var view = new DataView(dt) { Sort = order + (SortDesc ? " DESC" : " ASC") };
            return view.ToTable();
        }

        /// <summary>
        /// The arrow beside each sortable heading. Only the column actually in
        /// use carries one, so the table says how it is ordered without having
        /// to be clicked to find out.
        /// </summary>
        private void ApplySortHeads()
        {
            litSortName.Text = SortArrow(SortByName);
            litSortCount.Text = SortArrow(SortByCount);

            lnkSortName.ToolTip = SortTip(SortByName);
            lnkSortCount.ToolTip = SortTip(SortByCount);
        }

        /// <summary>
        /// Both sortable headings carry an icon at all times. One that shows
        /// nothing until it is clicked does not look sortable, so nobody clicks
        /// it. The glyphs match the ones the View Data grid already uses.
        /// </summary>
        private string SortArrow(string key)
        {
            if (!string.Equals(key, SortKey, StringComparison.Ordinal))
                return "<span class=\"vs-sortar\">&#8645;</span>";

            return SortDesc ? "<span class=\"vs-sortar on\">&#9660;</span>"
                            : "<span class=\"vs-sortar on\">&#9650;</span>";
        }

        private string SortTip(string key)
        {
            bool active = string.Equals(key, SortKey, StringComparison.Ordinal);
            bool nextDesc = active ? !SortDesc : DefaultDesc(key);

            if (key == SortByName)
                return nextDesc ? "Sort Z to A" : "Sort A to Z";

            return nextDesc ? "Sort highest first" : "Sort lowest first";
        }

        /// <summary>
        /// Which way a column runs the first time it is picked. A name wants to
        /// start at A; a count is being asked "which has most", so it starts at
        /// the largest.
        /// </summary>
        private static bool DefaultDesc(string key)
        {
            return key == SortByCount;
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
            SetProviderOpen(id, !IsProviderOpen(id));

            BindGrid();
        }

        /// <summary>
        /// A sortable column heading. Clicking the column already in use turns it
        /// around; clicking a different one starts it whichever way that column
        /// is usually read. Paging resets, because page 4 of the old order has
        /// nothing to do with page 4 of the new one.
        /// </summary>
        protected void sort_Command(object sender, CommandEventArgs e)
        {
            string key = Convert.ToString(e.CommandArgument);
            if (key != SortByName && key != SortByCount) return;

            if (string.Equals(key, SortKey, StringComparison.Ordinal))
            {
                SortDesc = !SortDesc;
            }
            else
            {
                SortKey = key;
                SortDesc = DefaultDesc(key);
            }

            PageIndex = 0;
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
            return IsProviderOpen(Convert.ToString(providerId));
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
