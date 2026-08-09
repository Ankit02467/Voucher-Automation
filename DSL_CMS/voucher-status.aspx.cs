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
        protected Literal litCountHead, litPageInfo,
                          litProviderCount, litProductCount,
                          litKpiTotal, litKpiTrend, litKpiUsed, litKpiUsedPct,
                          litKpiUnused, litKpiUnusedPct, litKpiExpiring, litKpiInvalid;

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

            // Coming back from View Data or Manage Product. Those screens hand the
            // provider back so the row reopens where it was left; the anchor on
            // the row takes care of the scroll, which a fresh GET would otherwise
            // start at the top of the page.
            string from = (Request.QueryString["providerId"] ?? string.Empty).Trim();
            if (from.Length > 0) ExpandedProvider = from;

            BindStatusPills();
            BindCategoryPills();
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
            DataTable dt = VoucherBAL.GetDashboardTotals();
            if (dt == null || dt.Rows.Count == 0) return;

            DataRow r = dt.Rows[0];

            int total = Convert.ToInt32(r["TotalVoucher"]);
            int used = Convert.ToInt32(r["Used"]);
            int unused = Convert.ToInt32(r["Unused"]);
            int before = Convert.ToInt32(r["BeforeThisMonth"]);

            litProviderCount.Text = Convert.ToString(r["Providers"]);
            litProductCount.Text = Convert.ToString(r["Products"]);

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

            lnkEarlyExpiry.CssClass = EarlyExpiry ? "vs-chip on" : "vs-chip";
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
            string css = "vs-chip " + StatusColourClass(value);

            if (string.Equals(value, SelectedStatus, StringComparison.OrdinalIgnoreCase))
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

        protected string CategoryPillClass(object pillValue)
        {
            return string.Equals(Convert.ToString(pillValue), SelectedCategory, StringComparison.OrdinalIgnoreCase)
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

        /// <summary>
        /// Letters for the provider tile when there is no logo file. Capitals
        /// carried in the name work better than the first few characters:
        /// LanguageCERT gives "LC", not "LAN".
        /// </summary>
        protected string ProviderInitials(object name)
        {
            string text = Convert.ToString(name).Trim();
            if (text.Length == 0) return "?";

            // A name that is already an acronym is shown whole: AWS, PTE, ETS.
            bool acronym = true;
            foreach (char c in text)
                if (char.IsLetter(c) && !char.IsUpper(c)) { acronym = false; break; }

            if (acronym)
                return text.Substring(0, Math.Min(3, text.Length)).ToUpperInvariant();

            // Otherwise two capitals: LanguageCERT gives LC, not LCE.
            var caps = new StringBuilder();
            foreach (char c in text)
            {
                if (char.IsUpper(c)) caps.Append(c);
                if (caps.Length == 2) break;
            }

            if (caps.Length == 2) return caps.ToString();

            return text.Substring(0, Math.Min(2, text.Length)).ToUpperInvariant();
        }

        /// <summary>
        /// Filenames already checked this request. Server.MapPath plus a disk hit
        /// per provider per render is wasteful when the answer cannot change.
        /// </summary>
        private readonly Dictionary<string, string> _logoCache =
            new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

        /// <summary>
        /// The provider tile. Uses a logo from ~/assets/img/providers if one is
        /// there, otherwise falls back to coloured initials, so dropping a file
        /// in is all it takes and a missing file never leaves a hole.
        ///
        /// Expected name: the provider name lowercased with anything that is not
        /// a letter or digit removed - AWS becomes aws.png, LanguageCERT becomes
        /// languagecert.png. png, svg, jpg and webp are all looked for.
        /// </summary>
        protected string ProviderTile(object providerId, object name)
        {
            string logo = ProviderLogoUrl(name);

            if (logo.Length > 0)
            {
                return "<span class=\"logo has-img\"><img src=\"" + Server.HtmlEncode(logo)
                     + "\" alt=\"" + Server.HtmlEncode(Convert.ToString(name)) + "\" /></span>";
            }

            return "<span class=\"logo\" style=\"" + ProviderLogoStyle(providerId) + "\">"
                 + Server.HtmlEncode(ProviderInitials(name)) + "</span>";
        }

        private string ProviderLogoUrl(object name)
        {
            string slug = Slug(Convert.ToString(name));
            if (slug.Length == 0) return string.Empty;

            string cached;
            if (_logoCache.TryGetValue(slug, out cached)) return cached;

            string found = string.Empty;
            foreach (string ext in new[] { ".png", ".svg", ".jpg", ".jpeg", ".webp" })
            {
                string rel = "~/assets/img/providers/" + slug + ext;
                try
                {
                    if (System.IO.File.Exists(Server.MapPath(rel)))
                    {
                        found = ResolveUrl(rel);
                        break;
                    }
                }
                catch { }
            }

            _logoCache[slug] = found;
            return found;
        }

        private static string Slug(string text)
        {
            var sb = new StringBuilder();
            foreach (char c in text ?? string.Empty)
                if (char.IsLetterOrDigit(c)) sb.Append(char.ToLowerInvariant(c));
            return sb.ToString();
        }

        /// <summary>
        /// Tile colour, taken straight off the provider id.
        ///
        /// Hashing the name looked cleverer but collided - ETS and LanguageCERT
        /// both landed on green. Walking the palette by id cannot collide until
        /// there are more providers than colours, and each provider keeps its
        /// colour for good.
        /// </summary>
        protected string ProviderLogoStyle(object providerId)
        {
            string[] palette =
            {
                "#ff9900",  // orange
                "#0f6cbd",  // blue
                "#7a2ff2",  // violet
                "#e0392b",  // red
                "#0e9f6e",  // green
                "#d946ef",  // magenta
                "#0891b2",  // teal
                "#b45309"   // amber
            };

            int id;
            if (!int.TryParse(Convert.ToString(providerId), out id) || id < 1) id = 1;

            return "background: " + palette[(id - 1) % palette.Length] + ";";
        }

        /// <summary>
        /// The stacked bar plus its legend. Shows the whole status split of the
        /// provider's stock - it is not narrowed by the status chip, because a bar
        /// filtered to one status would just be one solid block.
        /// </summary>
        protected string DistributionCell(object dataItem)
        {
            var row = dataItem as DataRowView;
            if (row == null) return string.Empty;

            int total = ToInt(row["TotalCount"]);
            if (total <= 0) return "<span class=\"muted\">&mdash;</span>";

            var parts = new[]
            {
                new { Key = "Used",    Val = ToInt(row["UsedCount"]),    Colour = "var(--st-used)" },
                new { Key = "Unused",  Val = ToInt(row["UnusedCount"]),  Colour = "var(--st-unused)" },
                new { Key = "Expired", Val = ToInt(row["ExpiredCount"]), Colour = "var(--st-expired)" },
                new { Key = "Not set", Val = ToInt(row["NotSetCount"]),  Colour = "var(--st-notset)" },
                new { Key = "Invalid", Val = ToInt(row["InvalidCount"]), Colour = "var(--st-invalid)" }
            };

            var bar = new StringBuilder("<div class=\"vs-distrib\"><div class=\"vs-bar\">");
            var legend = new StringBuilder("<div class=\"vs-legend\">");

            foreach (var p in parts)
            {
                if (p.Val <= 0) continue;

                double pct = p.Val * 100.0 / total;
                bar.Append("<i style=\"width:").Append(pct.ToString("0.##", System.Globalization.CultureInfo.InvariantCulture))
                   .Append("%; background:").Append(p.Colour).Append(";\" title=\"")
                   .Append(p.Key).Append(' ').Append(p.Val).Append("\"></i>");

                legend.Append("<span><span class=\"pip\" style=\"background:").Append(p.Colour).Append(";\"></span>")
                      .Append(p.Key).Append(" <b>").Append(p.Val).Append("</b></span>");
            }

            bar.Append("</div>").Append(legend).Append("</div></div>");
            return bar.ToString();
        }

        private static int ToInt(object value)
        {
            return (value == null || value == DBNull.Value) ? 0 : Convert.ToInt32(value);
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

                sb.Append("<a class=\"vs-prodlink\" href=\"")
                  .Append(Server.HtmlEncode(ViewDataUrl(providerId, id)))
                  .Append("\"><span>")
                  .Append(Server.HtmlEncode(name))
                  .Append("</span>");

                // the figure explains why a product is or is not in this list
                if (count.Length > 0)
                    sb.Append("<span class=\"cnt\">").Append(Server.HtmlEncode(count)).Append("</span>");

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
