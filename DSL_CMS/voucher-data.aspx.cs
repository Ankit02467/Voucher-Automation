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

        protected Literal litProvider, litRole, litMsg, litCount, litPageInfo, litEditTitle,
                          litUploadMsg, litUploadHint, litAssignMsg, litAssignCount,
                          litAssignTitle, litAssignBox, litAssignEmpty,
                          litDealerHeaders, litGridTitle, litReassignMsg, litReassignCode;
        protected Panel pnlMsg, pnlRoleNote, pnlRoleSwitch, pnlEdit, pnlEditDealer, pnlEditStatus, pnlEditAdmin,
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
        protected LinkButton lnkUpload, lnkHistory, lnkAssign, lnkDone, lnkAddDealer, lnkPrev, lnkNext;
        protected Repeater rptVoucher, rptPager, rptUploadProduct, rptHistory,
                           rptAssignVouchers, rptStudents, rptDealerEdit, rptAdminDealers;
        protected PlaceHolder phEmpty, phPager, phHistoryEmpty, phAssignEmpty, phStudentsEmpty;
        protected Button btnSearch, btnResetFilter, btnSaveEdit, btnCancelEdit,
                         btnUploadSave, btnAssignPick, btnAssignSave, btnReassignSave;
        protected System.Web.UI.HtmlControls.HtmlTableCell thActions, thAddedBy, thCheckedBy;
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

        #endregion

        #region Permissions

        protected bool CanUpload { get { return Role == RoleAdmin || Role == RoleTeam; } }
        protected bool CanHistory { get { return Role == RoleAdmin; } }
        protected bool CanAssign { get { return Role == RoleSubAdmin; } }
        /// <summary>
        /// The voucher team has no edit rights at all - no Edit button for them.
        /// Admin, sub-admin and student each get their own set of fields.
        /// </summary>
        protected bool CanEdit
        {
            get
            {
                return Role == RoleStudent || Role == RoleSubAdmin || Role == RoleAdmin;
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
        /// The voucher team has neither Edit nor Reassign, so they would otherwise
        /// stare at an empty column with a heading.
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
            DataTable dt = VoucherBAL.GetUserRole(Convert.ToString(Session["UserId"]));

            string role = (dt != null && dt.Rows.Count > 0)
                ? Convert.ToString(dt.Rows[0]["RoleName"]).Trim()
                : string.Empty;

            RoleUnmapped = (role.Length == 0);
            Role = RoleUnmapped ? RoleAdmin : role;
        }

        private void InitDealerColumns()
        {
            DataTable dt = VoucherBAL.GetDealerColumns(ProviderId);
            int max = (dt != null && dt.Rows.Count > 0) ? Convert.ToInt32(dt.Rows[0]["MaxSeq"]) : 1;
            DealerColumns = max;
        }

        private void ApplyRole()
        {
            litRole.Text = Server.HtmlEncode(Role);
            litProvider.Text = ProviderName();

            pnlRoleNote.Visible = RoleUnmapped;
            pnlRoleSwitch.Visible = RoleUnmapped;
            if (RoleUnmapped) SelectIfPresent(ddlRoleSwitch, Role);

            lnkUpload.Visible = CanUpload;
            lnkHistory.Visible = CanHistory;
            lnkAssign.Visible = CanAssign;
            lnkAssign.Text = ReassignMode ? "Reassign" : "+ Assign";
            lnkDone.Visible = (Role == RoleSubAdmin);
            lnkDone.Text = DoneMode ? "View Open Entries" : "View Done Entries";

            // header cells; the matching body cells carry their own Visible binding
            thActions.Visible = ShowActions;
            thAddedBy.Visible = ShowAddedBy;
            thCheckedBy.Visible = ShowCheckedBy;

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
                title += " - " + Server.HtmlEncode(
                    StatusFilter == "NotSet" ? "Not Set" : StatusFilter);

            string product = LockedProductName();
            if (product.Length > 0)
                title += " - " + Server.HtmlEncode(product);

            if (DaysFilter.Length > 0)
                title += " - expiring within " + Server.HtmlEncode(DaysFilter) + " day(s)";

            litGridTitle.Text = title;
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

            litDealerHeaders.Text = DealerHeaders();
            ApplyGridTitle();

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

        #region Dealer columns

        /// <summary>
        /// Header cells for the current number of dealer slots. The voucher team
        /// gets a "+" on the last Dealer Name cell that adds one more pair.
        /// </summary>
        private string DealerHeaders()
        {
            if (!ShowDealers) return string.Empty;

            var sb = new StringBuilder();
            for (int i = 1; i <= DealerColumns; i++)
            {
                sb.Append("<th>Dealer Name ").Append(i);

                if (i == DealerColumns && Role == RoleTeam)
                    sb.Append("<a href=\"javascript:__doPostBack('")
                      .Append(lnkAddDealer.UniqueID)
                      .Append("','')\" class=\"col-add\" title=\"Add another dealer column\">+</a>");

                sb.Append("</th><th>Sale Date ").Append(i).Append("</th>");
            }
            return sb.ToString();
        }

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
            string payload = BuildPayload(txtPaste.Text, out unreadableDates);

            if (payload.Length == 0)
            {
                ShowUploadError("No valid entries found. Put a voucher code and expiry date on each line.");
                return;
            }

            // Refuse rather than save vouchers with the expiry date quietly missing.
            if (unreadableDates > 0)
            {
                ShowUploadError(unreadableDates + " line(s) have an expiry date that cannot be read, "
                    + "so nothing was saved. Use dd-MM-yyyy (14-08-2026), dd/MM/yyyy, "
                    + "dd-MMM-yyyy or yyyy-MM-dd.");
                return;
            }

            DataTable dt = VoucherBAL.BulkInsert(UploadProductId, payload, Convert.ToString(Session["UserId"]));

            int inserted = 0, skipped = 0;
            if (dt != null && dt.Rows.Count > 0)
            {
                inserted = Convert.ToInt32(dt.Rows[0]["Inserted"]);
                skipped = Convert.ToInt32(dt.Rows[0]["Skipped"]);
            }

            pnlUpload.Visible = false;
            txtPaste.Text = string.Empty;

            string message = inserted + " voucher(s) added.";
            if (skipped > 0) message += " " + skipped + " skipped (duplicate code or blank row).";
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
        /// Turns pasted Excel rows into the "code|date~code|date" payload the proc
        /// expects. Tab, comma, semicolon and pipe separate the two columns.
        ///
        /// Space is deliberately NOT a separator - real voucher codes contain
        /// spaces ("AWS CODE 246"), and splitting on it would chop them in half.
        /// A line with no separator at all is still given a chance: if its last
        /// whitespace-separated word reads as a date, it is taken as one.
        ///
        /// <paramref name="unreadableDates"/> counts lines that carried something
        /// in the date position that could not be read, so the upload can say so
        /// instead of silently dropping it.
        /// </summary>
        private static string BuildPayload(string pasted, out int unreadableDates)
        {
            unreadableDates = 0;
            if (string.IsNullOrEmpty(pasted)) return string.Empty;

            var sb = new StringBuilder();
            string[] lines = pasted.Replace("\r\n", "\n").Replace("\r", "\n").Split('\n');

            foreach (string raw in lines)
            {
                string line = raw.Trim();
                if (line.Length == 0) continue;

                string[] parts = line.Split(new[] { '\t', '|', ',', ';' }, StringSplitOptions.RemoveEmptyEntries);
                if (parts.Length == 0) continue;

                string code = parts[0].Trim();
                string rawDate = (parts.Length > 1) ? parts[1].Trim() : string.Empty;

                // no separator, but the line may still end in a date
                if (rawDate.Length == 0)
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

                string date = NormaliseDate(rawDate);
                if (rawDate.Length > 0 && date.Length == 0) unreadableDates++;

                if (sb.Length > 0) sb.Append('~');
                sb.Append(code).Append('|').Append(date);
            }

            return sb.ToString();
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

        protected void lnkHistory_Click(object sender, EventArgs e)
        {
            if (!CanHistory) return;

            DataTable dt = VoucherBAL.GetHistory(ProviderId);
            rptHistory.DataSource = dt;
            rptHistory.DataBind();

            phHistoryEmpty.Visible = (dt == null || dt.Rows.Count == 0);
            pnlHistory.Visible = true;
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

            foreach (RepeaterItem item in rptStudents.Items)
            {
                var rdo = item.FindControl("rdoStudent") as RadioButton;
                var hf = item.FindControl("hfStudentId") as HiddenField;
                if (rdo != null && hf != null && rdo.Checked) PickedStudent = hf.Value;
            }
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
