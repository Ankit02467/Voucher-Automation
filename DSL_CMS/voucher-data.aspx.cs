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
    public partial class voucher_data : System.Web.UI.Page
    {
        #region Controls

        protected Literal litProvider, litMsg, litCount, litPageInfo, litEditTitle,
                          litUploadMsg, litUploadHint, litAssignMsg, litAssignCount,
                          litAssignTitle, litAssignBox, litAssignEmpty,
                          litGridTitle, litReassignMsg, litReassignCode,
                          litHistCode, litHistSummary;
        protected Panel pnlBody, pnlDenied,
                        pnlMsg, pnlRoleNote, pnlRoleSwitch, pnlEdit, pnlEditDealer, pnlEditStatus, pnlEditAdmin,
                        pnlUsedDate, pnlUpload, pnlUploadMsg, pnlHistory, pnlAssign, pnlAssignMsg,
                        pnlFilterDealer, pnlReassign, pnlReassignMsg,
                        pnlStatusButtons, pnlStatusDropdown, pnlStatusExtras;
        protected LinkButton lnkStatusUsed, lnkStatusUnused, lnkStatusInvalid;
        protected DropDownList ddlRoleSwitch, ddlFilterProduct, ddlFilterCheckedBy,
                               ddlEditStatus, ddlExamMode, ddlAssignProduct, ddlReassignStudent,
                               ddlAdminStatus;
        protected TextBox txtFilterCode, txtFilterDealer, txtFilterCheckDate, txtFilterExpiry,
                          txtUsedDate, txtCandidate, txtExamDate, txtPaste, txtAssignCount,
                          txtAdminCode, txtAdminExpiry, txtAdminCheckDate, txtAdminUsedDate,
                          txtAdminAddedBy, txtAdminCandidate, txtAdminExamDate, txtAdminExamMode;
        protected HiddenField hfId, hfReassignId;
        protected LinkButton lnkUpload, lnkAssign, lnkDone, lnkAddDealer, lnkPrev, lnkNext;
        protected Repeater rptHead, rptVoucher, rptPager, rptUploadProduct, rptHistory,
                           rptAssignVouchers, rptStudents, rptDealerEdit, rptAdminDealers;
        protected PlaceHolder phEmpty, phPager, phHistoryEmpty, phAssignEmpty, phStudentsEmpty;
        protected Button btnSearch, btnResetFilter, btnSaveEdit, btnCancelEdit,
                         btnUploadSave, btnAssignPick, btnAssignSave, btnReassignSave;
        protected System.Web.UI.HtmlControls.HtmlGenericControl divEditModal, divStatusFields;

        #endregion

        private const int PageSize = 10;

        private const string RoleAdmin = "Voucher Admin";
        private const string RoleSubAdmin = "Voucher Sub Admin";
        private const string RoleTeam = "Voucher Team";
        private const string RoleStudent = "Voucher Student";

        #region State

        private int PageIndex
        {
            get { return (int)(ViewState["Page"] ?? 0); }
            set { ViewState["Page"] = value; }
        }

        protected int RowOffset { get { return PageIndex * PageSize; } }

        private string ProviderId
        {
            get { return (string)(ViewState["ProviderId"] ?? string.Empty); }
            set { ViewState["ProviderId"] = value; }
        }

        private string Role
        {
            get { return (string)(ViewState["Role"] ?? RoleAdmin); }
            set { ViewState["Role"] = value; }
        }

        /// <summary>
        /// Status carried over from the dashboard. Blank (or "All") means every
        /// status; "NotSet" means the ones nobody has triaged yet. Reset clears it.
        /// </summary>
        private string StatusFilter
        {
            get { return (string)(ViewState["StatusFilter"] ?? string.Empty); }
            set { ViewState["StatusFilter"] = value; }
        }

        /// <summary>
        /// Early-expiry window carried over from the dashboard, in days. Keeping it
        /// is what makes this grid show the same number the dashboard counted.
        /// Reset clears it.
        /// </summary>
        private string DaysFilter
        {
            get { return (string)(ViewState["DaysFilter"] ?? string.Empty); }
            set { ViewState["DaysFilter"] = value; }
        }

        /// <summary>
        /// Set when the screen was opened by clicking a product name on the
        /// dashboard. The grid opens filtered to it and Upload Entry is pinned to
        /// it, so entries cannot be uploaded against a different product by
        /// mistake. Reset clears it.
        /// </summary>
        private string LockedProductId
        {
            get { return (string)(ViewState["LockedProduct"] ?? string.Empty); }
            set { ViewState["LockedProduct"] = value; }
        }

        protected bool HasProductLock { get { return LockedProductId.Length > 0; } }

        /// <summary>
        /// Back to Voucher Status, carrying the provider so its row reopens and
        /// the anchor puts the page back where it was. Without it the dashboard
        /// returns collapsed and scrolled to the top, which is a long way from
        /// the provider you were just looking at.
        /// </summary>
        protected string BackUrl
        {
            get
            {
                string url = ResolveUrl("~/voucher-status.aspx");
                if (ProviderId.Length == 0) return url;

                return url + "?providerId=" + Server.UrlEncode(ProviderId) + "#prov-" + ProviderId;
            }
        }

        private bool RoleUnmapped
        {
            get { return (bool)(ViewState["RoleUnmapped"] ?? false); }
            set { ViewState["RoleUnmapped"] = value; }
        }

        /// <summary>How many "Dealer Name / Sale Date" pairs the grid shows.</summary>
        private int DealerColumns
        {
            get { return (int)(ViewState["DealerCols"] ?? 1); }
            set { ViewState["DealerCols"] = value < 1 ? 1 : value; }
        }

        /// <summary>Sub-admin toggle: true shows the entries students have moved on.</summary>
        private bool DoneMode
        {
            get { return (bool)(ViewState["Done"] ?? false); }
            set { ViewState["Done"] = value; }
        }

        private string UploadProductId
        {
            get { return (string)(ViewState["UpProduct"] ?? string.Empty); }
            set { ViewState["UpProduct"] = value; }
        }

        private List<string> PickedVouchers
        {
            get
            {
                var list = ViewState["Picked"] as List<string>;
                if (list == null) { list = new List<string>(); ViewState["Picked"] = list; }
                return list;
            }
        }

        private string PickedStudent
        {
            get { return (string)(ViewState["Student"] ?? string.Empty); }
            set { ViewState["Student"] = value; }
        }

        /// <summary>
        /// Column the grid is ordered by, blank until one is picked - the proc
        /// already returns a sensible order and nothing should override it
        /// before being asked to.
        /// </summary>
        private string SortKey
        {
            get { return (string)(ViewState["SortKey"] ?? string.Empty); }
            set { ViewState["SortKey"] = value; }
        }

        private bool SortDesc
        {
            get { return (bool)(ViewState["SortDesc"] ?? false); }
            set { ViewState["SortDesc"] = value; }
        }

        #endregion

        #region Permissions

        protected bool CanUpload { get { return Role == RoleAdmin || Role == RoleTeam; } }
        protected bool CanHistory { get { return Role == RoleAdmin; } }
        protected bool CanAssign { get { return Role == RoleSubAdmin; } }
        /// <summary>
        /// Every role edits, but not the same fields: the voucher team gets the
        /// dealer pairs, the student the status, and the admin and sub-admin the
        /// status entry. Which panel opens is decided in OpenEditor.
        /// </summary>
        protected bool CanEdit
        {
            get
            {
                return Role == RoleTeam || Role == RoleStudent
                    || Role == RoleSubAdmin || Role == RoleAdmin;
            }
        }
        protected bool CanCheck { get { return Role == RoleStudent || Role == RoleSubAdmin; } }

        /// <summary>Reassign only appears on the sub-admin's done list.</summary>
        protected bool CanReassign { get { return Role == RoleSubAdmin && DoneMode; } }

        /// <summary>
        /// The picker at the top of the screen does two jobs. On the open list it
        /// hands unheld vouchers to a student; on the done list it hands finished
        /// ones back. Same modal, same multi-select, different set and different save.
        /// </summary>
        protected bool ReassignMode { get { return CanAssign && DoneMode; } }

        /// <summary>
        /// The Actions column earns its place only when there is an action in it.
        /// </summary>
        protected bool ShowActions { get { return CanEdit || CanReassign; } }

        /// <summary>
        /// Dealer name and sale date are for the admin and the voucher team only.
        /// The sub-admin and the student never see them.
        /// </summary>
        protected bool ShowDealers { get { return Role == RoleAdmin || Role == RoleTeam; } }

        /// <summary>A student sees neither Added By nor Checked By.</summary>
        protected bool ShowAddedBy { get { return Role != RoleStudent; } }
        protected bool ShowCheckedBy { get { return Role != RoleStudent; } }

        /// <summary>A student sets the status with buttons rather than a dropdown.</summary>
        protected bool UsesStatusButtons { get { return Role == RoleStudent; } }

        private string AssignedToFilter
        {
            get { return (Role == RoleStudent) ? Convert.ToString(Session["UserId"]) : string.Empty; }
        }

        /// <summary>"0" = still open, "1" = moved on, blank = no restriction.</summary>
        private string MovedFilter
        {
            get
            {
                if (Role == RoleStudent) return "0";              // a student never sees moved rows
                if (Role == RoleSubAdmin) return DoneMode ? "1" : "0";
                return string.Empty;
            }
        }

        #endregion

        protected void Page_Load(object sender, EventArgs e)
        {
            // Before anything else, including the sweep below: a caller with no
            // voucher role has no business running either. Checked on postback
            // as well as on GET, because the role is what every branch below
            // keys off and a postback must not be able to skip the test.
            if (VoucherAccess.IsDenied(Session["UserId"]))
            {
                pnlDenied.Visible = true;
                pnlBody.Visible = false;
                return;
            }

            // Vouchers checked on an earlier day belong to the sub-admin from
            // midnight. There is no SQL Agent on LocalDB to do it on the stroke of
            // twelve, so the sweep runs here: idempotent, normally a no-op, and it
            // has always caught up before anyone looks at the grid.
            VoucherBAL.AutoMove();

            if (IsPostBack) return;

            ProviderId = Request.QueryString["providerId"] ?? string.Empty;

            // Status picked on the dashboard; "All" means no restriction.
            string status = (Request.QueryString["status"] ?? string.Empty).Trim();
            StatusFilter = status.Equals("All", StringComparison.OrdinalIgnoreCase)
                ? string.Empty
                : status;

            // Early-expiry window and product, both carried over from the dashboard.
            DaysFilter = (Request.QueryString["days"] ?? string.Empty).Trim();
            LockedProductId = (Request.QueryString["productId"] ?? string.Empty).Trim();

            // A code handed down by the search box in the topbar. It goes into the
            // filter this screen already has rather than a state of its own, so it
            // shows in the filter bar where it can be seen and changed, and Reset
            // clears it like anything else typed there.
            string searched = (Request.QueryString["code"] ?? string.Empty).Trim();
            if (searched.Length > 0) txtFilterCode.Text = searched;

            ResolveRole();
            InitDealerColumns();
            ApplyRole();

            BindProducts();
            BindCheckedBy();
            BindGrid();
        }

        #region Role

        private void ResolveRole()
        {
            bool unmapped;
            string role = VoucherAccess.Effective(Session["UserId"], out unmapped);

            // Unmapped only matters here when the fallback is switched on - it
            // is what shows the role-preview dropdown. With the fallback off,
            // role comes back blank and the page refuses instead.
            RoleUnmapped = unmapped && role.Length > 0;
            Role = role;
        }

        private void InitDealerColumns()
        {
            DataTable dt = VoucherBAL.GetDealerColumns(ProviderId);
            int max = (dt != null && dt.Rows.Count > 0) ? Convert.ToInt32(dt.Rows[0]["MaxSeq"]) : 1;
            DealerColumns = max;
        }

        private void ApplyRole()
        {
            litProvider.Text = ProviderName();

            pnlRoleNote.Visible = RoleUnmapped;
            pnlRoleSwitch.Visible = RoleUnmapped;
            if (RoleUnmapped) SelectIfPresent(ddlRoleSwitch, Role);

            lnkUpload.Visible = CanUpload;
            lnkAssign.Visible = CanAssign;
            lnkAssign.Text = ReassignMode ? "Reassign" : "+ Assign";
            lnkDone.Visible = (Role == RoleSubAdmin);
            lnkDone.Text = DoneMode ? "View Open Entries" : "View Done Entries";

            pnlFilterDealer.Visible = ShowDealers;
            ApplyGridTitle();
        }

        /// <summary>
        /// Spells out every filter carried over from the dashboard, so it is never
        /// a mystery why the grid is showing fewer rows than the provider holds.
        /// </summary>
        private void ApplyGridTitle()
        {
            string title = DoneMode ? "Done Entries" : "Voucher List";

            if (StatusFilter.Length > 0)
                title += " - " + Server.HtmlEncode(StatusLabel(StatusFilter));

            string product = LockedProductName();
            if (product.Length > 0)
                title += " - " + Server.HtmlEncode(product);

            if (DaysFilter.Length > 0)
                title += " - expiring within " + Server.HtmlEncode(DaysFilter) + " day(s)";

            litGridTitle.Text = title;
        }

        /// <summary>
        /// The dashboard passes its status down in the query string, and two of
        /// those are tokens the proc understands rather than words anyone would
        /// write on a screen. Printed raw, the title read "UnusedOrNotSet".
        /// </summary>
        private static string StatusLabel(string status)
        {
            if (string.Equals(status, "NotSet", StringComparison.Ordinal)) return "Not Set";
            if (string.Equals(status, "UnusedOrNotSet", StringComparison.Ordinal)) return "Unused & Not Set";
            return status;
        }

        private string ProviderName()
        {
            if (ProviderId.Length == 0) return "Voucher Data";

            DataTable dt = VoucherBAL.GetProvider(ProviderId);
            return (dt != null && dt.Rows.Count > 0)
                ? Convert.ToString(dt.Rows[0]["Name"]) + " - Voucher Data"
                : "Voucher Data";
        }

        protected void ddlRoleSwitch_SelectedIndexChanged(object sender, EventArgs e)
        {
            Role = ddlRoleSwitch.SelectedValue;
            DoneMode = false;
            PageIndex = 0;
            pnlEdit.Visible = false;

            ApplyRole();
            BindGrid();
        }

        #endregion

        #region Binding

        private void BindProducts()
        {
            DataTable dt = VoucherBAL.GetProductDetail(ProviderId, string.Empty, "SelectDropdown");

            ddlFilterProduct.Items.Clear();
            ddlFilterProduct.Items.Add(new ListItem("-- All --", string.Empty));
            ddlAssignProduct.Items.Clear();
            ddlAssignProduct.Items.Add(new ListItem("-- All --", string.Empty));

            if (dt == null) return;
            foreach (DataRow r in dt.Rows)
            {
                string id = Convert.ToString(r["Id"]);
                string name = Convert.ToString(r["Name"]);
                ddlFilterProduct.Items.Add(new ListItem(name, id));
                ddlAssignProduct.Items.Add(new ListItem(name, id));
            }

            // arrived by clicking a product on the dashboard - open on that product
            if (HasProductLock) SelectIfPresent(ddlFilterProduct, LockedProductId);
        }

        /// <summary>Product name behind the lock, for the grid heading.</summary>
        private string LockedProductName()
        {
            if (!HasProductLock) return string.Empty;
            ListItem item = ddlFilterProduct.Items.FindByValue(LockedProductId);
            return (item == null) ? string.Empty : item.Text;
        }

        private void BindCheckedBy()
        {
            ddlFilterCheckedBy.Items.Clear();
            ddlFilterCheckedBy.Items.Add(new ListItem("-- All --", string.Empty));

            DataTable dt = VoucherBAL.GetCheckedByList(ProviderId);
            if (dt == null) return;

            foreach (DataRow r in dt.Rows)
            {
                string v = Convert.ToString(r["CheckedBy"]);
                ddlFilterCheckedBy.Items.Add(new ListItem(v, v));
            }
        }

        private void BindGrid()
        {
            DataTable dt = VoucherBAL.GetVoucherDetail(
                ProviderId,
                ddlFilterProduct.SelectedValue,
                txtFilterCode.Text.Trim(),
                ShowDealers ? txtFilterDealer.Text.Trim() : string.Empty,
                txtFilterCheckDate.Text.Trim(),
                ddlFilterCheckedBy.SelectedValue,
                StatusFilter,
                AssignedToFilter,
                MovedFilter,
                DaysFilter,
                txtFilterExpiry.Text.Trim(),
                "Select");

            int count = (dt == null) ? 0 : dt.Rows.Count;
            int pageCount = Pager.PageCount(count, PageSize);

            if (PageIndex >= pageCount) PageIndex = pageCount - 1;
            if (PageIndex < 0) PageIndex = 0;

            // grow the dealer columns if any row on this page carries more
            if (ShowDealers && dt != null)
            {
                foreach (DataRow r in dt.Rows)
                {
                    int used = Convert.ToInt32(r["DealerCount"]);
                    if (used > DealerColumns) DealerColumns = used;
                }
            }

            // after the scan above, so the header knows the final pair count
            BindHead();
            ApplyGridTitle();

            // Sorted whole, then paged. Sorting the page instead would only
            // shuffle the ten rows already on screen.
            dt = ApplySort(dt);

            rptVoucher.DataSource = Pager.Slice(dt, PageIndex, PageSize);
            rptVoucher.DataBind();

            litCount.Text = count.ToString();
            phEmpty.Visible = (count == 0);
            BindPager(count, pageCount);
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

        #region Header and sorting

        /// <summary>
        /// Every header cell, in order. Built here rather than written out in
        /// the markup because the set changes with the role and with how many
        /// dealer pairs the rows carry, and each one has to offer the same sort.
        ///
        /// A blank Key means there is nothing to sort on: S.No is a row number
        /// rather than a field, and Actions holds buttons.
        /// </summary>
        private void BindHead()
        {
            var t = new DataTable();
            t.Columns.Add("Key", typeof(string));
            t.Columns.Add("Label", typeof(string));
            t.Columns.Add("Width", typeof(string));
            t.Columns.Add("Extra", typeof(string));

            if (ShowActions) t.Rows.Add(string.Empty, "Actions", "width: 150px;", string.Empty);
            t.Rows.Add(string.Empty, "S.No", "width: 70px;", string.Empty);
            t.Rows.Add("ProductName", "Product Name", string.Empty, string.Empty);
            t.Rows.Add("VoucherCode", "Voucher Code", string.Empty, string.Empty);
            t.Rows.Add("ExpiryDate", "Expiry Date", string.Empty, string.Empty);
            if (ShowAddedBy) t.Rows.Add("AddedByName", "Added By", string.Empty, string.Empty);

            if (ShowDealers)
            {
                for (int i = 1; i <= DealerColumns; i++)
                {
                    // the voucher team gets a "+" on the last pair that adds one more
                    string extra = (i == DealerColumns && Role == RoleTeam) ? AddDealerButton() : string.Empty;

                    t.Rows.Add("Dealer:" + i, "Dealer Name " + i, string.Empty, extra);
                    t.Rows.Add("SaleDate:" + i, "Sale Date " + i, string.Empty, string.Empty);
                }
            }

            // Checked By sits next to the check date it belongs to, and the used
            // date follows both. The body cells in the markup are in this same
            // order - move one and the other has to move with it.
            t.Rows.Add("Status", "Voucher Status", string.Empty, string.Empty);
            t.Rows.Add("VoucherCheckDate", "Voucher Check Date", string.Empty, string.Empty);
            if (ShowCheckedBy) t.Rows.Add("CheckedBy", "Checked By", string.Empty, string.Empty);
            t.Rows.Add("UsedDate", "Voucher Used Date", string.Empty, string.Empty);
            t.Rows.Add("CandidateName", "Candidate Name", string.Empty, string.Empty);
            t.Rows.Add("ExamDate", "Exam Date", string.Empty, string.Empty);
            t.Rows.Add("ExamMode", "Exam Mode", string.Empty, string.Empty);

            rptHead.DataSource = t;
            rptHead.DataBind();
        }

        private string AddDealerButton()
        {
            return "<a href=\"javascript:__doPostBack('" + lnkAddDealer.UniqueID
                 + "','')\" class=\"col-add\" title=\"Add another dealer column\">+</a>";
        }

        protected bool SortableCell(object dataItem)
        {
            var row = dataItem as DataRowView;
            return row != null && Convert.ToString(row["Key"]).Length > 0;
        }

        protected string SortTip(object dataItem)
        {
            var row = dataItem as DataRowView;
            if (row == null) return string.Empty;

            string key = Convert.ToString(row["Key"]);
            if (key.Length == 0) return string.Empty;

            return (key == SortKey && !SortDesc) ? "Sort Z to A" : "Sort A to Z";
        }

        /// <summary>
        /// The mark beside a heading. Every sortable column carries one, so the
        /// ones that sort can be told from the ones that do not without clicking.
        /// </summary>
        protected string SortArrow(object key)
        {
            string k = Convert.ToString(key);
            if (k.Length == 0) return string.Empty;

            if (k != SortKey) return "<span class=\"sortarrow\">&#8645;</span>";

            return SortDesc
                ? "<span class=\"sortarrow on\">&#9660;</span>"
                : "<span class=\"sortarrow on\">&#9650;</span>";
        }

        protected void rptHead_ItemCommand(object source, RepeaterCommandEventArgs e)
        {
            if (e.CommandName != "Sort") return;

            string key = Convert.ToString(e.CommandArgument);
            if (key.Length == 0) return;

            // the same column again turns it round; a new one always starts A to Z
            if (key == SortKey)
            {
                SortDesc = !SortDesc;
            }
            else
            {
                SortKey = key;
                SortDesc = false;
            }

            // back to page 1, or the sort lands on a page that means nothing now
            PageIndex = 0;
            BindGrid();
        }

        /// <summary>
        /// Reorders the whole result.
        ///
        /// Dealer name and sale date arrive as one pipe separated column each,
        /// while the grid shows the Nth of each as a column of its own. Sorting
        /// on the raw column would order by the first pair whichever one was
        /// clicked, so the Nth value is pulled into a column of its own instead.
        /// </summary>
        private DataTable ApplySort(DataTable dt)
        {
            if (dt == null || dt.Rows.Count == 0 || SortKey.Length == 0) return dt;

            string column = SortKey;
            int slot;

            if (TrySlot(SortKey, "Dealer:", out slot))
                column = SlotColumn(dt, "DealerNames", slot, false);
            else if (TrySlot(SortKey, "SaleDate:", out slot))
                column = SlotColumn(dt, "SaleDates", slot, true);

            if (column == null || !dt.Columns.Contains(column)) return dt;

            try
            {
                dt.DefaultView.Sort = "[" + column + "] " + (SortDesc ? "DESC" : "ASC");
                return dt.DefaultView.ToTable();
            }
            catch (Exception)
            {
                // a column that will not sort must not take the grid down with it
                return dt;
            }
        }

        private static bool TrySlot(string key, string prefix, out int slot)
        {
            slot = 0;
            return key.StartsWith(prefix, StringComparison.Ordinal)
                && int.TryParse(key.Substring(prefix.Length), out slot);
        }

        /// <summary>
        /// Pulls the Nth item out of a pipe separated column into one of its own
        /// and hands back its name; null when the source column is not there.
        /// </summary>
        private static string SlotColumn(DataTable dt, string source, int slot, bool asDate)
        {
            if (!dt.Columns.Contains(source)) return null;

            const string name = "__sortkey";
            if (dt.Columns.Contains(name)) dt.Columns.Remove(name);
            dt.Columns.Add(name, asDate ? typeof(DateTime) : typeof(string));

            foreach (DataRow r in dt.Rows)
            {
                string[] parts = Split(r[source]);
                string value = (slot >= 1 && slot <= parts.Length) ? parts[slot - 1].Trim() : string.Empty;

                if (!asDate)
                {
                    r[name] = value;
                    continue;
                }

                // blanks stay NULL so they gather at one end instead of reading as 1900
                DateTime parsed;
                r[name] = DateTime.TryParse(value, out parsed) ? (object)parsed : DBNull.Value;
            }

            return name;
        }

        #endregion

        #region Dealer columns

        /// <summary>Row cells, read from the pipe separated lists the proc returns.</summary>
        protected string DealerCells(object dealerNames, object saleDates)
        {
            if (!ShowDealers) return string.Empty;

            string[] names = Split(dealerNames);
            string[] dates = Split(saleDates);

            var sb = new StringBuilder();
            for (int i = 0; i < DealerColumns; i++)
            {
                string name = (i < names.Length) ? names[i].Trim() : string.Empty;
                string date = (i < dates.Length) ? dates[i].Trim() : string.Empty;

                sb.Append("<td class=\"left\">")
                  .Append(name.Length == 0 ? "-" : Server.HtmlEncode(name))
                  .Append("</td><td>")
                  .Append(FormatIsoDate(date))
                  .Append("</td>");
            }
            return sb.ToString();
        }

        private static string[] Split(object value)
        {
            string raw = Convert.ToString(value);
            return string.IsNullOrEmpty(raw) ? new string[0] : raw.Split('|');
        }

        private static string FormatIsoDate(string iso)
        {
            DateTime parsed;
            return DateTime.TryParse(iso, out parsed) ? parsed.ToString("dd-MMM-yyyy") : "-";
        }

        /// <summary>Each click adds one more dealer slot - it never removes one.</summary>
        protected void lnkAddDealer_Click(object sender, EventArgs e)
        {
            DataTable typed = pnlEdit.Visible ? CurrentDealerEdits() : null;

            DealerColumns = DealerColumns + 1;

            if (typed != null)
            {
                // keep whatever was typed and add the new empty pair
                while (typed.Rows.Count < DealerColumns)
                    typed.Rows.Add(typed.Rows.Count + 1, string.Empty, string.Empty);
                BindDealerEditor(typed);
            }

            BindGrid();
        }

        #endregion

        #region Filters and paging

        protected void btnSearch_Click(object sender, EventArgs e)
        {
            PageIndex = 0;
            BindGrid();
        }

        protected void btnResetFilter_Click(object sender, EventArgs e)
        {
            ClearFilters();
            BindGrid();
        }

        /// <summary>
        /// Reset clears everything, including the status, expiry window and product
        /// carried over from the dashboard - otherwise those would survive a Reset
        /// invisibly and the grid would look wrong.
        /// </summary>
        private void ClearFilters()
        {
            ddlFilterProduct.SelectedIndex = 0;
            txtFilterCode.Text = string.Empty;
            txtFilterDealer.Text = string.Empty;
            txtFilterCheckDate.Text = string.Empty;
            txtFilterExpiry.Text = string.Empty;
            ddlFilterCheckedBy.SelectedIndex = 0;
            StatusFilter = string.Empty;
            DaysFilter = string.Empty;
            LockedProductId = string.Empty;
            PageIndex = 0;
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

        protected void lnkDone_Click(object sender, EventArgs e)
        {
            DoneMode = !DoneMode;
            PageIndex = 0;
            pnlEdit.Visible = false;

            ApplyRole();
            BindGrid();
        }

        #endregion

        #region Row actions

        protected void rptVoucher_ItemCommand(object source, RepeaterCommandEventArgs e)
        {
            string id = Convert.ToString(e.CommandArgument);

            if (e.CommandName == "EditRow" && CanEdit)
            {
                OpenEditor(id);
            }
            else if (e.CommandName == "HistoryRow" && CanHistory)
            {
                OpenHistory(id);
            }
            else if (e.CommandName == "ReassignRow" && CanReassign)
            {
                OpenReassign(id);
            }
        }

        private void OpenEditor(string id)
        {
            DataTable dt = VoucherBAL.GetData(id);
            if (dt == null || dt.Rows.Count == 0) return;

            DataRow r = dt.Rows[0];

            // A student may only open what is theirs. The proc checks this again
            // on save - the id travels in a hidden field, so this alone would be
            // no protection at all.
            if (UsesStatusButtons
                && Convert.ToString(r["AssignedTo"]) != Convert.ToString(Session["UserId"]))
            {
                ShowMessage("That voucher is not assigned to you.", false);
                return;
            }

            hfId.Value = id;

            bool dealerMode = (Role == RoleTeam);
            bool adminMode = (Role == RoleAdmin);

            pnlEdit.Visible = true;
            pnlEditDealer.Visible = dealerMode;
            pnlEditAdmin.Visible = adminMode;
            pnlEditStatus.Visible = !dealerMode && !adminMode;

            // student picks the status with buttons and sees nothing else;
            // sub-admin keeps the dropdown plus candidate and exam details
            pnlStatusButtons.Visible = UsesStatusButtons;
            pnlStatusDropdown.Visible = !UsesStatusButtons;
            pnlStatusExtras.Visible = !UsesStatusButtons;

            // The dialog is only as wide as the role's fields need. Admin edits
            // nine fields plus dealer pairs; a student picks one of three buttons.
            divEditModal.Attributes["class"] = "modal " +
                (adminMode ? "lg" : dealerMode ? "md" : UsesStatusButtons ? "xs" : "md");

            string title = dealerMode ? "Dealer Details" : (adminMode ? "Edit Voucher" : "Status Entry");
            litEditTitle.Text = title + " - " + Server.HtmlEncode(Convert.ToString(r["VoucherCode"]));

            if (dealerMode)
            {
                BindDealerEditor(BuildDealerRows(r["DealerNames"], r["SaleDates"]));
            }
            else if (adminMode)
            {
                // shown but locked - the proc will not write these either
                txtAdminCode.Text = Convert.ToString(r["VoucherCode"]);
                txtAdminAddedBy.Text = Convert.ToString(r["AddedByName"]);
                txtAdminCandidate.Text = Convert.ToString(r["CandidateName"]);
                txtAdminExamDate.Text = FormatDate(r["ExamDate"]);
                txtAdminExamMode.Text = Convert.ToString(r["ExamMode"]);

                // editable
                txtAdminExpiry.Text = FormatDate(r["ExpiryDate"]);
                txtAdminCheckDate.Text = FormatDate(r["VoucherCheckDate"]);
                txtAdminUsedDate.Text = FormatDate(r["UsedDate"]);
                SelectIfPresent(ddlAdminStatus, Convert.ToString(r["Status"]));

                // exactly as many dealer fields as this voucher already has
                rptAdminDealers.DataSource = ExistingDealerRows(r["DealerNames"], r["SaleDates"]);
                rptAdminDealers.DataBind();
            }
            else if (UsesStatusButtons)
            {
                // student: status only, chosen with buttons
                PickedStatus = Convert.ToString(r["Status"]);
                txtUsedDate.Text = FormatDate(r["UsedDate"]);
                ShowStatusFields(PickedStatus == "Used");
                BindStatusButtons();
            }
            else
            {
                SelectIfPresent(ddlEditStatus, Convert.ToString(r["Status"]));
                txtUsedDate.Text = FormatDate(r["UsedDate"]);
                txtCandidate.Text = Convert.ToString(r["CandidateName"]);
                txtExamDate.Text = FormatDate(r["ExamDate"]);
                SelectIfPresent(ddlExamMode, Convert.ToString(r["ExamMode"]));
                ShowStatusFields(ddlEditStatus.SelectedValue == "Used");
            }
        }

        /// <summary>
        /// Shows the field grid and the used-date box together.
        ///
        /// The parent is set before the child on purpose. Control.Visible reports
        /// false whenever an ancestor is hidden, whatever the control itself was
        /// set to - so deciding the grid by reading pnlUsedDate.Visible always
        /// came back false once the grid had been hidden, and the used date could
        /// never reappear.
        /// </summary>
        private void ShowStatusFields(bool usedDate)
        {
            // a student sees the grid only for the used date; everyone else
            // always has the dropdown and the exam details in it
            divStatusFields.Visible = !UsesStatusButtons || usedDate;
            pnlUsedDate.Visible = usedDate;
        }

        /// <summary>One editor row per dealer slot, padded out to DealerColumns.</summary>
        private DataTable BuildDealerRows(object dealerNames, object saleDates)
        {
            string[] names = Split(dealerNames);
            string[] dates = Split(saleDates);

            if (names.Length > DealerColumns) DealerColumns = names.Length;

            DataTable t = NewDealerTable();
            for (int i = 0; i < DealerColumns; i++)
            {
                t.Rows.Add(i + 1,
                    (i < names.Length) ? names[i] : string.Empty,
                    (i < dates.Length) ? dates[i] : string.Empty);
            }
            return t;
        }

        /// <summary>
        /// One row per dealer this voucher actually has - 1 dealer gives 1 field,
        /// 3 dealers give 3. A voucher with none still gets one empty field so the
        /// admin has somewhere to type.
        /// </summary>
        private DataTable ExistingDealerRows(object dealerNames, object saleDates)
        {
            string[] names = Split(dealerNames);
            string[] dates = Split(saleDates);

            DataTable t = NewDealerTable();
            int count = (names.Length > 0) ? names.Length : 1;

            for (int i = 0; i < count; i++)
                t.Rows.Add(i + 1,
                    (i < names.Length) ? names[i] : string.Empty,
                    (i < dates.Length) ? dates[i] : string.Empty);

            return t;
        }

        private static DataTable NewDealerTable()
        {
            DataTable t = new DataTable();
            t.Columns.Add("Seq", typeof(int));
            t.Columns.Add("DealerName", typeof(string));
            t.Columns.Add("SaleDate", typeof(string));
            return t;
        }

        private void BindDealerEditor(DataTable rows)
        {
            rptDealerEdit.DataSource = rows;
            rptDealerEdit.DataBind();
        }

        /// <summary>Reads whatever is typed in the dealer editor right now.</summary>
        private DataTable CurrentDealerEdits()
        {
            DataTable t = NewDealerTable();
            int seq = 0;

            foreach (RepeaterItem item in rptDealerEdit.Items)
            {
                var name = item.FindControl("txtDealerName") as TextBox;
                var date = item.FindControl("txtSaleDate") as TextBox;
                seq++;
                t.Rows.Add(seq,
                    (name == null) ? string.Empty : name.Text.Trim(),
                    (date == null) ? string.Empty : date.Text.Trim());
            }

            while (t.Rows.Count < DealerColumns)
                t.Rows.Add(t.Rows.Count + 1, string.Empty, string.Empty);

            return t;
        }

        #endregion

        #region Edit save

        protected void ddlEditStatus_SelectedIndexChanged(object sender, EventArgs e)
        {
            ShowStatusFields(ddlEditStatus.SelectedValue == "Used");
        }

        /// <summary>
        /// The status the student has picked with the buttons. Held separately
        /// from the dropdown because the two editors are mutually exclusive.
        /// </summary>
        private string PickedStatus
        {
            get { return (string)(ViewState["PickedStatus"] ?? string.Empty); }
            set { ViewState["PickedStatus"] = value; }
        }

        protected string StatusButtonClass(string status)
        {
            return string.Equals(status, PickedStatus, StringComparison.Ordinal)
                ? "pill-btn on " + voucher_status.StatusColourClass(status)
                : "pill-btn " + voucher_status.StatusColourClass(status);
        }

        /// <summary>
        /// Used / Unused / Invalid. Picking Used reveals the used date, defaulted
        /// to today. Nothing is written until Save - so candidate and exam details
        /// the student cannot see are never touched by an accidental click.
        /// </summary>
        protected void lnkPickStatus_Click(object sender, EventArgs e)
        {
            var btn = sender as LinkButton;
            if (btn == null) return;

            PickedStatus = btn.CommandArgument;

            bool used = (PickedStatus == "Used");
            ShowStatusFields(used);

            if (used && txtUsedDate.Text.Trim().Length == 0)
                txtUsedDate.Text = DateTime.Today.ToString("yyyy-MM-dd");

            BindStatusButtons();
            pnlEdit.Visible = true;
        }

        private void BindStatusButtons()
        {
            lnkStatusUsed.CssClass = StatusButtonClass("Used");
            lnkStatusUnused.CssClass = StatusButtonClass("Unused");
            lnkStatusInvalid.CssClass = StatusButtonClass("Invalid");
        }

        protected void btnSaveEdit_Click(object sender, EventArgs e)
        {
            string id = hfId.Value;
            string userId = Convert.ToString(Session["UserId"]);

            if (Role == RoleTeam)
            {
                DataTable rows = CurrentDealerEdits();
                var sb = new StringBuilder();

                foreach (DataRow r in rows.Rows)
                {
                    if (sb.Length > 0) sb.Append('~');
                    sb.Append(Convert.ToString(r["DealerName"]))
                      .Append('|')
                      .Append(Convert.ToString(r["SaleDate"]));
                }

                VoucherBAL.SaveDealers(id, sb.ToString(), userId);
                ShowMessage("Dealer details saved.", true);
            }
            else if (Role == RoleAdmin)
            {
                if (ddlAdminStatus.SelectedValue == "Used" && txtAdminUsedDate.Text.Trim().Length == 0)
                {
                    ShowMessage("Voucher Used Date is required when the status is 'Used'.", false);
                    return;
                }

                // the voucher code is displayed only - it is never sent
                VoucherBAL.UpdateAdminEntry(id,
                    txtAdminExpiry.Text.Trim(), txtAdminCheckDate.Text.Trim(),
                    ddlAdminStatus.SelectedValue, txtAdminUsedDate.Text.Trim(), userId);

                var dealers = new StringBuilder();
                foreach (RepeaterItem item in rptAdminDealers.Items)
                {
                    var name = item.FindControl("txtDealerName") as TextBox;
                    var date = item.FindControl("txtSaleDate") as TextBox;
                    if (dealers.Length > 0) dealers.Append('~');
                    dealers.Append((name == null) ? string.Empty : name.Text.Trim())
                           .Append('|')
                           .Append((date == null) ? string.Empty : date.Text.Trim());
                }
                VoucherBAL.SaveDealers(id, dealers.ToString(), userId);

                ShowMessage("Voucher updated.", true);
            }
            else if (UsesStatusButtons)
            {
                if (PickedStatus.Length == 0)
                {
                    ShowMessage("Pick a status first.", false);
                    return;
                }

                if (PickedStatus == "Used" && txtUsedDate.Text.Trim().Length == 0)
                {
                    ShowMessage("Voucher Used Date is required when the status is 'Used'.", false);
                    return;
                }

                string checkedBy = Convert.ToString(Session["FullName"]);
                if (string.IsNullOrEmpty(checkedBy)) checkedBy = "System";

                // status and used date only - candidate and exam details are not
                // shown to a student and must not be blanked by this save
                int outcome = VoucherBAL.UpdateStatusOnly(id, PickedStatus,
                    txtUsedDate.Text.Trim(), checkedBy, userId);

                if (outcome == -3)
                {
                    ShowMessage("That voucher is not assigned to you, so nothing was saved.", false);
                    return;
                }

                ShowMessage("Status set to " + PickedStatus
                    + ". This entry moves to the sub admin after midnight.", true);
            }
            else
            {
                if (ddlEditStatus.SelectedValue == "Used" && txtUsedDate.Text.Trim().Length == 0)
                {
                    ShowMessage("Voucher Used Date is required when the status is 'Used'.", false);
                    return;
                }

                string checkedBy = Convert.ToString(Session["FullName"]);
                if (string.IsNullOrEmpty(checkedBy)) checkedBy = "System";

                VoucherBAL.UpdateStatusEntry(id, ddlEditStatus.SelectedValue, txtUsedDate.Text.Trim(),
                    txtCandidate.Text.Trim(), txtExamDate.Text.Trim(), ddlExamMode.SelectedValue,
                    checkedBy, userId);

                ShowMessage("Status updated. Voucher check date set to today.", true);
            }

            pnlEdit.Visible = false;
            BindCheckedBy();
            BindGrid();
        }

        protected void btnCancelEdit_Click(object sender, EventArgs e)
        {
            pnlEdit.Visible = false;
        }

        protected void chkCheckDate_CheckedChanged(object sender, EventArgs e)
        {
            if (!CanCheck) return;

            var box = (CheckBox)sender;
            var item = box.NamingContainer as RepeaterItem;
            if (item == null) return;

            var hf = item.FindControl("hfCheckId") as HiddenField;
            if (hf == null) return;

            string checkedBy = Convert.ToString(Session["FullName"]);
            if (string.IsNullOrEmpty(checkedBy)) checkedBy = "System";

            VoucherBAL.UpdateVoucherCheck(hf.Value, checkedBy, Convert.ToString(Session["UserId"]));
            ShowMessage("Voucher check date stamped with today's date.", true);

            BindCheckedBy();
            BindGrid();
        }

        #endregion

        #region Upload Entry modal

        protected void lnkUpload_Click(object sender, EventArgs e)
        {
            txtPaste.Text = string.Empty;
            pnlUploadMsg.Visible = false;

            if (HasProductLock)
            {
                // opened from a product link - that product is the only choice
                UploadProductId = LockedProductId;
                litUploadHint.Text = "Uploading into " + LockedProductName() + ". Paste the entries below.";
            }
            else
            {
                UploadProductId = string.Empty;
                litUploadHint.Text = "Select a product first.";
            }

            BindUploadProducts();
            pnlUpload.Visible = true;
        }

        /// <summary>
        /// Offers every active product, or just the locked one when the screen was
        /// opened from a product link.
        /// </summary>
        private void BindUploadProducts()
        {
            DataTable dt = VoucherBAL.GetProductDetail(ProviderId, string.Empty, "SelectDropdown");

            if (HasProductLock && dt != null)
            {
                DataTable one = dt.Clone();
                foreach (DataRow r in dt.Rows)
                {
                    if (Convert.ToString(r["Id"]) == LockedProductId)
                        one.ImportRow(r);
                }
                dt = one;
            }

            rptUploadProduct.DataSource = dt;
            rptUploadProduct.DataBind();
        }

        protected void rptUploadProduct_ItemCommand(object source, RepeaterCommandEventArgs e)
        {
            if (e.CommandName != "PickProduct") return;

            string picked = Convert.ToString(e.CommandArgument);

            // with a lock in place the only offered product is the locked one, but
            // never take a posted value on trust
            if (HasProductLock && picked != LockedProductId) return;

            UploadProductId = picked;
            litUploadHint.Text = "Product selected. Now paste the entries.";
            pnlUploadMsg.Visible = false;

            BindUploadProducts();
            pnlUpload.Visible = true;
        }

        protected void btnUploadSave_Click(object sender, EventArgs e)
        {
            pnlUpload.Visible = true;

            if (UploadProductId.Length == 0)
            {
                ShowUploadError("Select a product name first - entries cannot be saved without it.");
                return;
            }

            int unreadableDates;
            string dealerPayload;
            List<string> codes;
            string payload = BuildPayload(txtPaste.Text, out dealerPayload, out unreadableDates, out codes);

            if (payload.Length == 0)
            {
                ShowUploadError("No valid entries found. Put a voucher code and expiry date on each line.");
                return;
            }

            // Refuse rather than save vouchers with a date quietly missing.
            if (unreadableDates > 0)
            {
                ShowUploadError(unreadableDates + " date(s) cannot be read, so nothing was saved. "
                    + "Use dd-MM-yyyy (14-08-2026), dd/MM/yyyy, dd-MMM-yyyy or yyyy-MM-dd "
                    + "for both the expiry date and any sale date.");
                return;
            }

            // The upload is the one screen that hands SQL a whole pasted sheet, so
            // it is the one most able to find a shape the proc cannot take. An
            // error page loses the paste and tells the uploader nothing they can
            // act on; this keeps the modal open with their text still in it.
            //
            // It must never fall through to the success message. A failed upload
            // that reports rows added is worse than the error page it replaces.
            DataTable dt;
            try
            {
                dt = VoucherBAL.BulkInsert(UploadProductId, payload, dealerPayload,
                    Convert.ToString(Session["UserId"]));
            }
            catch (Exception ex)
            {
                // BulkInsert runs no transaction, so vouchers written before the
                // failure stay written - say so rather than implying nothing saved.
                ShowUploadError("The upload was stopped by a database error. Some vouchers "
                    + "may already have been saved, so check the grid before trying again. "
                    + "The database reported: " + ex.Message);
                return;
            }

            int inserted = 0, skipped = 0;
            string skippedCodes = string.Empty;
            if (dt != null && dt.Rows.Count > 0)
            {
                inserted = Convert.ToInt32(dt.Rows[0]["Inserted"]);
                skipped = Convert.ToInt32(dt.Rows[0]["Skipped"]);

                // Added by a later revision of the proc. Checked rather than
                // assumed: the pipeline deploys the site but never the database,
                // so a server can be running new code against an older proc, and
                // that must cost the names rather than throw.
                if (dt.Columns.Contains("SkippedCodes"))
                    skippedCodes = Convert.ToString(dt.Rows[0]["SkippedCodes"]);
            }

            pnlUpload.Visible = false;
            txtPaste.Text = string.Empty;

            // Two different things get called "duplicate" here, so they are
            // reported separately. Skipped comes from the proc and counts codes
            // that were already in the system; DuplicateNote counts lines that
            // repeat inside this one paste, which the proc collapses before it
            // ever gets as far as skipping anything.
            string message = inserted + " voucher(s) added.";
            if (skipped > 0) message += " " + skipped + " skipped - already in the system"
                                      + AlreadyHeldNote(skippedCodes) + ".";
            message += DuplicateNote(codes);
            ShowMessage(message, inserted > 0);

            // Clear the filters so the rows just added are visible straight away.
            ClearFilters();
            BindGrid();
        }

        /// <summary>
        /// Date formats accepted from a paste. Day first, because that is how the
        /// rest of this application reads and writes dates.
        ///
        /// Every date is normalised to ISO before it reaches SQL Server. Handing
        /// SQL the raw text would leave the result at the mercy of the connection's
        /// DATEFORMAT: under the default (mdy), "14-08-2026" is month 14, which
        /// TRY_CONVERT quietly turns into NULL. The voucher would save with no
        /// expiry date and the screen would still say it worked.
        /// </summary>
        private static readonly string[] DateFormats =
        {
            "dd-MM-yyyy", "d-M-yyyy", "dd/MM/yyyy", "d/M/yyyy", "dd.MM.yyyy", "d.M.yyyy",
            "yyyy-MM-dd", "yyyy/MM/dd",
            "dd-MMM-yyyy", "d-MMM-yyyy", "dd MMM yyyy", "d MMM yyyy",
            "dd-MM-yy", "d-M-yy", "dd/MM/yy", "d/M/yy"
        };

        /// <summary>
        /// Reads one pasted date and returns it as yyyy-MM-dd, or blank if it
        /// cannot be read at all.
        /// </summary>
        private static string NormaliseDate(string raw)
        {
            string text = (raw ?? string.Empty).Trim();
            if (text.Length == 0) return string.Empty;

            DateTime parsed;
            if (DateTime.TryParseExact(text, DateFormats,
                    System.Globalization.CultureInfo.InvariantCulture,
                    System.Globalization.DateTimeStyles.None, out parsed))
                return parsed.ToString("yyyy-MM-dd");

            // last resort, still day first
            if (DateTime.TryParse(text, new System.Globalization.CultureInfo("en-GB"),
                    System.Globalization.DateTimeStyles.None, out parsed))
                return parsed.ToString("yyyy-MM-dd");

            return string.Empty;
        }

        /// <summary>Does this look like a date rather than part of a voucher code?</summary>
        private static bool LooksLikeDate(string text)
        {
            return NormaliseDate(text).Length > 0;
        }

        /// <summary>
        /// Turns pasted Excel rows into the two payloads the proc expects:
        /// "code|date~code|date" for the vouchers, and
        /// "code|seq|name|saledate~..." for whatever dealer pairs came with them.
        ///
        /// Columns are, in order: voucher code, expiry date, then any number of
        /// dealer name / sale date pairs. A line that stops after the expiry
        /// date is complete; one that carries three dealers is too.
        ///
        /// Tab, comma, semicolon and pipe separate the columns. Space is
        /// deliberately NOT a separator - real voucher codes contain spaces
        /// ("AWS CODE 246"), and splitting on it would chop them in half. A line
        /// with no separator at all is still given a chance: if its last
        /// whitespace-separated word reads as a date, it is taken as one.
        ///
        /// Empty entries are kept rather than dropped, because the columns are
        /// read by position now: a row with no dealer 1 but a dealer 2 pastes as
        /// two empty cells, and collapsing them would shift dealer 2 into
        /// dealer 1's place.
        ///
        /// <paramref name="unreadableDates"/> counts dates - expiry or sale -
        /// that carried something which could not be read, so the upload can say
        /// so instead of silently dropping them.
        ///
        /// <paramref name="codes"/> collects every voucher code the payload
        /// carries, in the order it was pasted and repeats included, so the
        /// upload can report what came in twice. It has to be gathered here
        /// rather than by re-reading the paste: this is where a line becomes a
        /// code, and a second reading could disagree with what was saved.
        /// </summary>
        private static string BuildPayload(string pasted, out string dealerPayload,
                                           out int unreadableDates, out List<string> codes)
        {
            unreadableDates = 0;
            dealerPayload = string.Empty;
            codes = new List<string>();
            if (string.IsNullOrEmpty(pasted)) return string.Empty;

            var sb = new StringBuilder();
            var dealers = new StringBuilder();

            // Which (code, column) dealer slots have already been filled. A code
            // that repeats is still one voucher, so its slots can only be claimed
            // once - see the note where this is checked.
            var dealerSlots = new HashSet<string>(StringComparer.OrdinalIgnoreCase);

            string[] lines = pasted.Replace("\r\n", "\n").Replace("\r", "\n").Split('\n');

            foreach (string raw in lines)
            {
                string line = raw.Trim();
                if (line.Length == 0) continue;

                string[] parts = line.Split(new[] { '\t', '|', ',', ';' });
                if (parts.Length == 0) continue;

                string code = parts[0].Trim();
                string rawDate = (parts.Length > 1) ? parts[1].Trim() : string.Empty;

                // no separator, but the line may still end in a date
                if (rawDate.Length == 0 && parts.Length == 1)
                {
                    int gap = code.LastIndexOfAny(new[] { ' ', '\t' });
                    if (gap > 0)
                    {
                        string tail = code.Substring(gap + 1).Trim();
                        if (LooksLikeDate(tail))
                        {
                            rawDate = tail;
                            code = code.Substring(0, gap).Trim();
                        }
                    }
                }

                if (code.Length == 0) continue;
                codes.Add(code);

                string date = NormaliseDate(rawDate);
                if (rawDate.Length > 0 && date.Length == 0) unreadableDates++;

                if (sb.Length > 0) sb.Append('~');
                sb.Append(code).Append('|').Append(date);

                // ---- whatever is left: dealer name / sale date, in pairs ----
                int seq = 0;
                for (int i = 2; i < parts.Length; i += 2)
                {
                    seq++;

                    string dealer = parts[i].Trim();
                    string rawSale = (i + 1 < parts.Length) ? parts[i + 1].Trim() : string.Empty;

                    string sale = NormaliseDate(rawSale);
                    if (rawSale.Length > 0 && sale.Length == 0) unreadableDates++;

                    // an empty pair still counts towards seq - the column it sits
                    // in is which dealer it is
                    if (dealer.Length == 0 && sale.Length == 0) continue;

                    // BulkInsert groups @Data by code and then attaches dealers
                    // to the one voucher that code became. So if the same code is
                    // pasted on two lines and both carry a dealer in column 1,
                    // both records arrive for the same voucher with Seq = 1 and
                    // break UQ_VoucherDealer_Seq (VoucherId, Seq) - taking the
                    // whole upload down AFTER the vouchers have been written,
                    // since the proc runs no transaction. First line to fill a
                    // slot keeps it; the repeat is dropped.
                    //
                    // The slot is claimed here rather than above, so a line that
                    // leaves dealer 1 blank does not stop a later line filling it.
                    //
                    // The separator matters: joined without one, code "AWS101" in
                    // column 1 and code "AWS10" in column 11 make the same key.
                    if (!dealerSlots.Add(code + "\u001F" + seq)) continue;

                    if (dealers.Length > 0) dealers.Append('~');
                    dealers.Append(code).Append('|').Append(seq).Append('|')
                           .Append(dealer).Append('|').Append(sale);
                }
            }

            dealerPayload = dealers.ToString();
            return sb.ToString();
        }

        /// <summary>How many repeated codes the upload message names before it stops.</summary>
        private const int MaxNamedDuplicates = 10;

        /// <summary>
        /// Names the codes the upload turned away because they were already held
        /// somewhere in the system. The proc sends them back as a ~ separated
        /// list; it is the only thing that can, since the stored codes are
        /// ciphertext and the duplicate check runs on a hash of them.
        ///
        /// Blank when the deployed proc is older than this and does not return
        /// the list - the count still gets reported, just without the names.
        /// </summary>
        private static string AlreadyHeldNote(string skippedCodes)
        {
            if (string.IsNullOrWhiteSpace(skippedCodes)) return string.Empty;

            string[] parts = skippedCodes.Split('~');
            var named = new List<string>();

            foreach (string part in parts)
            {
                string code = part.Trim();
                if (code.Length == 0) continue;

                named.Add(code);
                if (named.Count == MaxNamedDuplicates) break;
            }

            if (named.Count == 0) return string.Empty;

            int total = 0;
            foreach (string part in parts)
                if (part.Trim().Length > 0) total++;

            string list = string.Join(", ", named.ToArray());
            if (total > named.Count) list += " and " + (total - named.Count) + " more";

            return ": " + list;
        }

        /// <summary>
        /// Names the codes one paste carried more than once, most-repeated first.
        ///
        /// These are invisible everywhere else. BulkInsert groups @Data by code
        /// before it inserts, so three lines of AWS2236582 become one voucher -
        /// and because Skipped counts distinct codes that were already in the
        /// system, the other two are not reported as skipped either. Without
        /// this note a three-line sheet reports "1 voucher(s) added" and never
        /// says why the other two lines went nowhere.
        ///
        /// Compared case-insensitively, because that is what actually collapses
        /// them: the proc groups on a code column whose collation ignores case,
        /// so AWS100 and aws100 are one voucher there and must read as one here.
        ///
        /// Nothing is refused over this - the vouchers still save. The count is
        /// the point: it tells the uploader their sheet has three copies, not
        /// that the system lost two.
        /// </summary>
        private static string DuplicateNote(List<string> codes)
        {
            if (codes == null || codes.Count < 2) return string.Empty;

            var counts = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            var firstSeen = new Dictionary<string, int>(StringComparer.OrdinalIgnoreCase);
            var order = new List<string>();

            foreach (string code in codes)
            {
                int seen;
                if (counts.TryGetValue(code, out seen))
                {
                    counts[code] = seen + 1;
                }
                else
                {
                    counts[code] = 1;
                    firstSeen[code] = order.Count;
                    order.Add(code);   // keeps the casing that was pasted first
                }
            }

            var repeated = new List<string>();
            foreach (string code in order)
                if (counts[code] > 1) repeated.Add(code);

            if (repeated.Count == 0) return string.Empty;

            // Worst first, ties in paste order. The first-seen index is carried
            // rather than looked up because List.Sort is not a stable sort -
            // without it, equal counts would come back in an arbitrary order.
            repeated.Sort(delegate (string a, string b)
            {
                int byCount = counts[b].CompareTo(counts[a]);
                return byCount != 0 ? byCount : firstSeen[a].CompareTo(firstSeen[b]);
            });

            // One line on the screen - naming two hundred codes would bury the
            // counts that matter.
            int named = Math.Min(repeated.Count, MaxNamedDuplicates);
            var list = new StringBuilder();

            for (int i = 0; i < named; i++)
            {
                if (list.Length > 0) list.Append(", ");
                list.Append(repeated[i]).Append(" (").Append(counts[repeated[i]]).Append(" times)");
            }

            if (repeated.Count > named)
                list.Append(" and ").Append(repeated.Count - named).Append(" more");

            return " Repeated in the pasted sheet, saved once each: " + list + ".";
        }

        private void ShowUploadError(string message)
        {
            litUploadMsg.Text = Server.HtmlEncode(message);
            pnlUploadMsg.Visible = true;
            BindUploadProducts();
        }

        protected void lnkUploadClose_Click(object sender, EventArgs e)
        {
            pnlUpload.Visible = false;
        }

        protected string UploadProductClass(object productId)
        {
            return string.Equals(Convert.ToString(productId), UploadProductId, StringComparison.Ordinal)
                ? "pill-btn on"
                : "pill-btn";
        }

        #endregion

        #region History modal

        /// <summary>
        /// One voucher's history. Opened from the row rather than the toolbar:
        /// the old screen listed every change the whole provider had ever seen,
        /// which answered no question anyone actually had.
        /// </summary>
        private void OpenHistory(string id)
        {
            if (!CanHistory) return;

            DataTable dt = VoucherBAL.GetVoucherHistory(id);

            rptHistory.DataSource = dt;
            rptHistory.DataBind();

            litHistCode.Text = Server.HtmlEncode(VoucherCodeOf(id));
            litHistSummary.Text = HistorySummary(dt);

            phHistoryEmpty.Visible = (dt == null || dt.Rows.Count == 0);
            pnlHistory.Visible = true;
        }

        private string VoucherCodeOf(string id)
        {
            DataTable dt = VoucherBAL.GetData(id);
            return (dt == null || dt.Rows.Count == 0)
                ? string.Empty
                : Convert.ToString(dt.Rows[0]["VoucherCode"]);
        }

        /// <summary>
        /// The line above the timeline. Counts hand-offs and checks rather than
        /// rows, because "12 entries" says nothing about how many students have
        /// held this voucher.
        /// </summary>
        private string HistorySummary(DataTable dt)
        {
            if (dt == null || dt.Rows.Count == 0) return string.Empty;

            int assigned = 0, reassigned = 0, checks = 0;

            foreach (DataRow r in dt.Rows)
            {
                switch (Convert.ToString(r["Activity"]))
                {
                    case "Assigned to Student": assigned++; break;
                    case "Reassigned to Student": reassigned++; break;
                    case "Voucher Checked": checks++; break;
                }
            }

            var sb = new StringBuilder();
            sb.Append("<span><b>").Append(assigned + reassigned).Append("</b> hand-off")
              .Append((assigned + reassigned) == 1 ? string.Empty : "s").Append("</span>");
            sb.Append("<span><b>").Append(assigned).Append("</b> assigned</span>");
            sb.Append("<span><b>").Append(reassigned).Append("</b> reassigned</span>");
            sb.Append("<span><b>").Append(checks).Append("</b> checked</span>");
            return sb.ToString();
        }

        /// <summary>
        /// Opens a "Round N" heading each time the voucher changes hands. Round
        /// comes off the proc, which counts the hand-offs in order.
        /// </summary>
        protected string RoundHead(object dataItem, int index)
        {
            var row = dataItem as DataRowView;
            if (row == null) return string.Empty;

            int round = ToInt(row["Round"]);

            // anything before the first hand-off belongs to no round at all
            if (round < 1) return (index == 0) ? "<div class=\"hist-round\">Before assignment</div>" : string.Empty;

            // only the row that opens a round prints the heading
            if (index > 0 && ToInt(PreviousRound(row)) == round) return string.Empty;

            return "<div class=\"hist-round\">Round " + round + "</div>";
        }

        private static object PreviousRound(DataRowView row)
        {
            int index = row.DataView.Table.Rows.IndexOf(row.Row);
            if (index <= 0) return 0;
            return row.DataView.Table.Rows[index - 1]["Round"];
        }

        private static int ToInt(object value)
        {
            return (value == null || value == DBNull.Value) ? 0 : Convert.ToInt32(value);
        }

        /// <summary>The person and, where there is one, the student involved.</summary>
        protected string HistoryWho(object dataItem)
        {
            var row = dataItem as DataRowView;
            if (row == null) return string.Empty;

            string by = Convert.ToString(row["ChangedByName"]).Trim();
            string student = Convert.ToString(row["AssignedToName"]).Trim();
            string checkedBy = Convert.ToString(row["CheckedBy"]).Trim();
            string activity = Convert.ToString(row["Activity"]);

            var parts = new List<string>();

            if (activity == "Assigned to Student" || activity == "Reassigned to Student")
            {
                if (by.Length > 0) parts.Add("by " + Server.HtmlEncode(by));
                if (student.Length > 0) parts.Add("to <b>" + Server.HtmlEncode(student) + "</b>");
            }
            else if (activity == "Voucher Checked")
            {
                string name = (checkedBy.Length > 0) ? checkedBy : student;
                if (name.Length > 0) parts.Add("by <b>" + Server.HtmlEncode(name) + "</b>");
            }
            else
            {
                if (by.Length > 0) parts.Add("by " + Server.HtmlEncode(by));
                if (student.Length > 0) parts.Add("held by " + Server.HtmlEncode(student));
            }

            string status = Convert.ToString(row["Status"]).Trim();
            if (status.Length > 0 && activity != "Assigned to Student"
                                  && activity != "Reassigned to Student")
                parts.Add("status " + Server.HtmlEncode(status));

            // The check stamp is the thing being asked for on these rows, and it
            // is not always the moment the row was written - a status saved days
            // later carries the date the voucher was actually checked.
            if (row["VoucherCheckDate"] != DBNull.Value
                && activity != "Assigned to Student" && activity != "Reassigned to Student")
            {
                parts.Add("checked "
                    + Convert.ToDateTime(row["VoucherCheckDate"]).ToString("dd-MMM-yyyy HH:mm"));
            }

            return string.Join(" &middot; ", parts.ToArray());
        }

        /// <summary>Colours the dot: a hand-off, a check, or anything else.</summary>
        protected string StepKind(object activity)
        {
            switch (Convert.ToString(activity))
            {
                case "Assigned to Student": return "k-assign";
                case "Reassigned to Student": return "k-reassign";
                case "Voucher Checked": return "k-check";
                case "Moved to Sub Admin":
                case "Auto Moved to Sub Admin": return "k-move";
                default: return "k-edit";
            }
        }

        protected void lnkHistoryClose_Click(object sender, EventArgs e)
        {
            pnlHistory.Visible = false;
        }

        #endregion

        #region Assign modal

        protected void lnkAssign_Click(object sender, EventArgs e)
        {
            if (!CanAssign) return;

            PickedVouchers.Clear();
            PickedStudent = string.Empty;
            txtAssignCount.Text = string.Empty;
            pnlAssignMsg.Visible = false;

            BindAssign();
            pnlAssign.Visible = true;
        }

        private void BindAssign()
        {
            bool reassign = ReassignMode;

            DataTable dt = reassign
                ? VoucherBAL.GetForReassign(ProviderId, ddlAssignProduct.SelectedValue)
                : VoucherBAL.GetForAssign(ProviderId, ddlAssignProduct.SelectedValue);

            rptAssignVouchers.DataSource = dt;
            rptAssignVouchers.DataBind();

            litAssignTitle.Text = reassign ? "Reassign Vouchers" : "Assign Vouchers";
            litAssignBox.Text = reassign ? "Done Entries" : "Unassigned Vouchers";
            litAssignEmpty.Text = reassign ? "No done entries." : "No unassigned vouchers.";
            btnAssignSave.Text = reassign ? "Reassign" : "Assign";

            int count = (dt == null) ? 0 : dt.Rows.Count;
            litAssignCount.Text = count.ToString();
            phAssignEmpty.Visible = (count == 0);

            DataTable students = VoucherBAL.GetStudents();
            rptStudents.DataSource = students;
            rptStudents.DataBind();
            phStudentsEmpty.Visible = (students == null || students.Rows.Count == 0);
        }

        protected void ddlAssignProduct_SelectedIndexChanged(object sender, EventArgs e)
        {
            CaptureAssignSelection();
            BindAssign();
            pnlAssign.Visible = true;
        }

        protected void btnAssignPick_Click(object sender, EventArgs e)
        {
            CaptureAssignSelection();

            int wanted;
            if (int.TryParse(txtAssignCount.Text.Trim(), out wanted) && wanted > 0)
            {
                PickedVouchers.Clear();
                int taken = 0;

                foreach (RepeaterItem item in rptAssignVouchers.Items)
                {
                    if (taken >= wanted) break;
                    var hf = item.FindControl("hfVoucherId") as HiddenField;
                    if (hf == null) continue;
                    PickedVouchers.Add(hf.Value);
                    taken++;
                }
            }

            BindAssign();
            pnlAssign.Visible = true;
        }

        private void CaptureAssignSelection()
        {
            var picked = PickedVouchers;
            picked.Clear();

            foreach (RepeaterItem item in rptAssignVouchers.Items)
            {
                var chk = item.FindControl("chkPick") as CheckBox;
                var hf = item.FindControl("hfVoucherId") as HiddenField;
                if (chk != null && hf != null && chk.Checked) picked.Add(hf.Value);
            }

            // The student radios share one name, so the browser posts exactly one
            // value and it is the student id. Only overwrite when something came
            // back - a postback that does not render the list must not clear the
            // choice already made.
            string student = Request.Form["assignStudent"];
            if (!string.IsNullOrEmpty(student)) PickedStudent = student;
        }

        protected void btnAssignSave_Click(object sender, EventArgs e)
        {
            // The button that opens this modal is guarded; the save that writes
            // through it was not. Same check, so a forged postback cannot hand
            // vouchers around.
            if (!CanAssign) return;

            CaptureAssignSelection();
            pnlAssign.Visible = true;

            if (PickedVouchers.Count == 0)
            {
                ShowAssignError("Select at least one voucher.");
                BindAssign();
                return;
            }

            if (PickedStudent.Length == 0)
            {
                ShowAssignError("Select a student.");
                BindAssign();
                return;
            }

            string ids = string.Join(",", PickedVouchers.ToArray());
            string userId = Convert.ToString(Session["UserId"]);
            int done;

            if (ReassignMode)
            {
                DataTable dt = VoucherBAL.ReassignMany(ids, PickedStudent, userId);
                done = (dt != null && dt.Rows.Count > 0) ? Convert.ToInt32(dt.Rows[0]["Reassigned"]) : 0;
            }
            else
            {
                DataTable dt = VoucherBAL.Assign(ids, PickedStudent, userId);
                done = (dt != null && dt.Rows.Count > 0) ? Convert.ToInt32(dt.Rows[0]["Assigned"]) : 0;
            }

            pnlAssign.Visible = false;
            PickedVouchers.Clear();
            PickedStudent = string.Empty;

            ShowMessage(ReassignMode
                ? done + " voucher(s) reassigned. They are back with the student."
                : done + " voucher(s) assigned to the student.", done > 0);
            BindGrid();
        }

        protected void lnkAssignClose_Click(object sender, EventArgs e)
        {
            pnlAssign.Visible = false;
        }

        private void ShowAssignError(string message)
        {
            litAssignMsg.Text = Server.HtmlEncode(message);
            pnlAssignMsg.Visible = true;
        }

        protected bool IsPicked(object voucherId)
        {
            return PickedVouchers.Contains(Convert.ToString(voucherId));
        }

        protected bool IsStudentPicked(object studentId)
        {
            return string.Equals(Convert.ToString(studentId), PickedStudent, StringComparison.Ordinal);
        }

        /// <summary>
        /// Renders the checked attribute for the plain student radio, so the
        /// pick survives the product filter and the Select-first-N postbacks.
        /// </summary>
        protected string StudentChecked(object studentId)
        {
            return IsStudentPicked(studentId) ? "checked=\"checked\"" : string.Empty;
        }

        #endregion

        #region Reassign modal

        /// <summary>
        /// Ids queued for reassignment. This is the single-row path only - a row's
        /// own Reassign button. Reassigning a batch goes through the picker above.
        /// </summary>
        private List<string> ReassignIds
        {
            get
            {
                var list = ViewState["ReassignIds"] as List<string>;
                if (list == null) { list = new List<string>(); ViewState["ReassignIds"] = list; }
                return list;
            }
        }

        private void OpenReassign(string id)
        {
            DataTable dt = VoucherBAL.GetData(id);
            if (dt == null || dt.Rows.Count == 0) return;

            ReassignIds.Clear();
            ReassignIds.Add(id);

            hfReassignId.Value = id;
            litReassignCode.Text = Server.HtmlEncode(Convert.ToString(dt.Rows[0]["VoucherCode"]));

            OpenReassignCommon();
        }

        private void OpenReassignCommon()
        {
            pnlReassignMsg.Visible = false;

            ddlReassignStudent.Items.Clear();
            ddlReassignStudent.Items.Add(new ListItem("-- Select student --", string.Empty));

            DataTable students = VoucherBAL.GetStudents();
            if (students != null)
                foreach (DataRow r in students.Rows)
                    ddlReassignStudent.Items.Add(
                        new ListItem(Convert.ToString(r["FullName"]), Convert.ToString(r["Id"])));

            pnlReassign.Visible = true;
        }

        protected void btnReassignSave_Click(object sender, EventArgs e)
        {
            if (!CanReassign) return;

            if (ddlReassignStudent.SelectedValue.Length == 0)
            {
                litReassignMsg.Text = "Select a student.";
                pnlReassignMsg.Visible = true;
                pnlReassign.Visible = true;
                return;
            }

            if (ReassignIds.Count == 0)
            {
                pnlReassign.Visible = false;
                ShowMessage("Nothing was selected to reassign.", false);
                return;
            }

            string ids = string.Join(",", ReassignIds.ToArray());
            DataTable dt = VoucherBAL.ReassignMany(ids,
                ddlReassignStudent.SelectedValue, Convert.ToString(Session["UserId"]));

            int done = (dt != null && dt.Rows.Count > 0) ? Convert.ToInt32(dt.Rows[0]["Reassigned"]) : 0;

            pnlReassign.Visible = false;
            ReassignIds.Clear();

            ShowMessage(done > 0
                ? done + " voucher(s) reassigned. They are back with the student."
                : "Reassign failed.", done > 0);

            BindGrid();
        }

        protected void lnkReassignClose_Click(object sender, EventArgs e)
        {
            pnlReassign.Visible = false;
        }

        #endregion

        #region Template helpers

        /// <summary>
        /// A checked voucher leaves the student's list at midnight. Showing when
        /// that happens beats it vanishing without explanation.
        /// </summary>
        protected string MoveNote(object autoMoveAfter)
        {
            if (autoMoveAfter == null || autoMoveAfter == DBNull.Value) return string.Empty;

            DateTime due = Convert.ToDateTime(autoMoveAfter);
            return "<span class=\"move-note\" title=\"Moves to the sub admin automatically\">&#8594; "
                 + due.ToString("dd-MMM") + "</span>";
        }

        /// <summary>A fresh upload has no status yet, so it renders as "Not set".</summary>
        protected string StatusBadge(object status)
        {
            string text = Convert.ToString(status);
            if (string.IsNullOrWhiteSpace(text))
                return "<span class=\"st st-none\">Not set</span>";

            string css;
            switch (text.ToLowerInvariant())
            {
                case "used": css = "st st-used"; break;
                case "unused": css = "st st-unused"; break;
                case "expired": css = "st st-expired"; break;
                case "invalid": css = "st st-invalid"; break;
                default: css = "st"; break;
            }
            return "<span class=\"" + css + "\">" + Server.HtmlEncode(text) + "</span>";
        }

        protected string Dash(object value)
        {
            string text = Convert.ToString(value);
            return string.IsNullOrWhiteSpace(text) ? "-" : Server.HtmlEncode(text);
        }

        protected string DateOrDash(object value)
        {
            if (value == null || value == DBNull.Value) return "-";
            return Convert.ToDateTime(value).ToString("dd-MMM-yyyy");
        }

        private static string FormatDate(object value)
        {
            if (value == null || value == DBNull.Value) return string.Empty;
            return Convert.ToDateTime(value).ToString("yyyy-MM-dd");
        }

        private static void SelectIfPresent(ListControl list, string value)
        {
            ListItem item = list.Items.FindByValue(value ?? string.Empty);
            if (item != null) list.SelectedValue = value ?? string.Empty;
        }

        private void ShowMessage(string message, bool success)
        {
            litMsg.Text = Server.HtmlEncode(message);
            pnlMsg.CssClass = success ? "msg msg-ok" : "msg msg-bad";
            pnlMsg.Visible = true;
        }

        #endregion
    }
}
