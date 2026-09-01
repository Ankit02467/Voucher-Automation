<%@ Page Language="C#" AutoEventWireup="true" MasterPageFile="~/MasterPage.master"
    CodeBehind="voucher-data.aspx.cs" Inherits="DSL_CMS.voucher_data" %>

<asp:Content ContentPlaceHolderID="TitleContent" runat="server">Voucher Data - DSL CMS/OSS</asp:Content>

<asp:Content ContentPlaceHolderID="MainContent" runat="server">

<asp:Panel ID="pnlDenied" runat="server" Visible="false" CssClass="msg msg-bad">
    No Voucher role is mapped to your user, so the voucher module is not
    available. Ask an administrator to map your account to one of the four
    Voucher roles.
</asp:Panel>

<%-- Everything below is the screen proper. Wrapped so one flag can take it
     away for a caller with no voucher role - see Page_Load. --%>
<asp:Panel ID="pnlBody" runat="server">

    <%-- ---------------- Toolbar ---------------- --%>
    <div class="toolbar">
        <a class="btn-back" href='<%= BackUrl %>'
           title="Back to Voucher Status">&#8592; Back</a>
        <h1><asp:Literal ID="litProvider" runat="server" Text="Voucher Data" /></h1>

        <span class="spacer"></span>

        <asp:Panel ID="pnlRoleSwitch" runat="server" Visible="false" CssClass="field">
            <asp:DropDownList ID="ddlRoleSwitch" runat="server" AutoPostBack="true"
                OnSelectedIndexChanged="ddlRoleSwitch_SelectedIndexChanged">
                <asp:ListItem Text="Voucher Admin"     Value="Voucher Admin" />
                <asp:ListItem Text="Voucher Sub Admin" Value="Voucher Sub Admin" />
                <asp:ListItem Text="Voucher Team"      Value="Voucher Team" />
                <asp:ListItem Text="Voucher Student"   Value="Voucher Student" />
            </asp:DropDownList>
        </asp:Panel>

        <asp:LinkButton ID="lnkDone" runat="server" CssClass="pill-btn" Visible="false"
            OnClick="lnkDone_Click" CausesValidation="false">View Done Entries</asp:LinkButton>
        <asp:LinkButton ID="lnkUpload" runat="server" CssClass="pill-btn" Visible="false"
            OnClick="lnkUpload_Click" CausesValidation="false">Upload Entry</asp:LinkButton>
        <%-- View History used to sit here and list every change the provider had
             ever seen. It is a per-row action now, beside Edit. --%>
        <%-- Same button either way: it assigns unheld vouchers on the open list
             and reassigns finished ones on the done list. --%>
        <asp:LinkButton ID="lnkAssign" runat="server" CssClass="pill-btn" Visible="false"
            OnClick="lnkAssign_Click" CausesValidation="false">+ Assign</asp:LinkButton>
    </div>

    <asp:Panel ID="pnlRoleNote" runat="server" Visible="false" CssClass="note">
        No Voucher role is mapped to your user, so this screen is running as
        <strong>Voucher Admin</strong>. Use the dropdown above to preview the other
        roles (for testing only).
    </asp:Panel>

    <asp:Panel ID="pnlMsg" runat="server" Visible="false" CssClass="msg msg-ok">
        <asp:Literal ID="litMsg" runat="server" />
    </asp:Panel>

    <%-- ---------------- Status ----------------
         This replaced the filter bar. The counts describe whatever this screen
         was opened on - a whole provider, or one product of it - so landing on
         AWS reads against its 17 and landing on Associate reads against its 12.
         The buttons narrow the grid inside that same set, which is why a card
         and the button beside it never disagree: both are counted from one
         fetch, in BindGrid, rather than each asking the database its own
         question.

         The cards are deliberately plain. The dashboard's are the way in to a
         screen and carry a trend line and an arrow; these are only saying how
         much of what is in front of you. --%>
    <div class="vd-status">
        <%-- The cards are the buttons, said a different way, so they click too.
             Somebody who reads "Expiring soon 1" and presses it expects the one
             to appear underneath; before, nothing happened at all.

             Both rows are bound from one array of counts, and every count is
             "how many rows would this button show" - asked of the same
             predicate the button filters with. A card cannot disagree with its
             button, because neither is worked out separately. --%>
        <%-- The label and the figure are built in code and handed over as Text,
             not written here as spans wrapping a Literal.

             A LinkButton given markup and a child control together keeps only
             the child, and the child's own value does not come back on a
             postback that has not re-bound the repeater - which is what opening
             the Edit or View History dialog does. The cards and buttons came
             back as empty outlines. Text is a property of the button itself, so
             it is remembered the same way CssClass is, on every postback. --%>
        <div class="vd-cards">
            <asp:Repeater ID="rptCards" runat="server" OnItemCommand="status_Command">
                <ItemTemplate>
                    <asp:LinkButton runat="server" CommandName="PickStatus"
                        CommandArgument='<%# Eval("Value") %>'
                        CssClass='<%# CardClass(Eval("Value")) %>'
                        Text='<%# CardBody(Container.DataItem) %>'
                        CausesValidation="false" />
                </ItemTemplate>
            </asp:Repeater>
        </div>

        <div class="vd-pills">
            <span class="vd-plab">Status</span>
            <asp:Repeater ID="rptStatusPills" runat="server" OnItemCommand="status_Command">
                <ItemTemplate>
                    <%-- built as Text for the same reason as the cards above --%>
                    <asp:LinkButton runat="server" CommandName="PickStatus"
                        CommandArgument='<%# Eval("Value") %>'
                        CssClass='<%# StatusPillClass(Eval("Value")) %>'
                        Text='<%# PillBody(Container.DataItem) %>'
                        CausesValidation="false" />
                </ItemTemplate>
            </asp:Repeater>

            <%-- The topbar search lands here. With no filter bar left to show
                 the code in, this says what is being looked at and offers the
                 way out of it. --%>
            <asp:Panel ID="pnlSearchChip" runat="server" Visible="false" CssClass="vd-chip">
                <span>Showing results for</span>
                <b><asp:Literal ID="litSearchChip" runat="server" /></b>
                <asp:LinkButton ID="lnkClearSearch" runat="server" OnClick="lnkClearSearch_Click"
                    CausesValidation="false" ToolTip="Clear this search">&#10005;</asp:LinkButton>
            </asp:Panel>
        </div>

        <%-- "Expiring soon" is a question about a span of days as much as a
             status, so picking it asks which span - the same 1 / 3 / 7 / 1 Month
             the dashboard offers behind View Early Expiry. Shown only while that
             button is the lit one: for any other status there is no window to
             choose, and an inert row of days would suggest otherwise. --%>
        <asp:Panel ID="pnlWindows" runat="server" Visible="false" CssClass="vd-pills">
            <span class="vd-plab">Window</span>
            <asp:Repeater ID="rptWindows" runat="server" OnItemCommand="rptWindows_ItemCommand">
                <ItemTemplate>
                    <asp:LinkButton runat="server" CommandName="PickDays"
                        CommandArgument='<%# Eval("Value") %>'
                        CssClass='<%# WindowPillClass(Eval("Value")) %>'
                        Text='<%# Eval("Text") %>' CausesValidation="false" />
                </ItemTemplate>
            </asp:Repeater>
        </asp:Panel>
    </div>

    <%-- ---------------- Edit modal ---------------- --%>
    <asp:Panel ID="pnlEdit" runat="server" Visible="false" CssClass="modal-back">
      <%-- width is set per role in OpenEditor: a student picking one of three
           buttons does not need the same dialog as an admin editing nine fields --%>
      <div runat="server" id="divEditModal" class="modal lg">
        <div class="modal-head">
            <h2><asp:Literal ID="litEditTitle" runat="server" /></h2>
            <asp:LinkButton ID="lnkEditClose" runat="server" CssClass="btn btn-light btn-sm"
                OnClick="btnCancelEdit_Click" CausesValidation="false">Close</asp:LinkButton>
        </div>
        <div class="modal-body">
            <asp:HiddenField ID="hfId" runat="server" Value="0" />

            <%-- Voucher team: any number of dealer / sale date pairs --%>
            <asp:Panel ID="pnlEditDealer" runat="server" Visible="false">
                <asp:Repeater ID="rptDealerEdit" runat="server">
                    <HeaderTemplate><div class="form-grid"></HeaderTemplate>
                    <ItemTemplate>
                        <div class="field">
                            <label>Dealer Name <%# Eval("Seq") %></label>
                            <asp:TextBox runat="server" ID="txtDealerName" Text='<%# Eval("DealerName") %>' />
                        </div>
                        <div class="field">
                            <label>Sale Date <%# Eval("Seq") %></label>
                            <asp:TextBox runat="server" ID="txtSaleDate" TextMode="Date" Text='<%# Eval("SaleDate") %>' />
                        </div>
                    </ItemTemplate>
                    <FooterTemplate></div></FooterTemplate>
                </asp:Repeater>
            </asp:Panel>

            <%-- Admin: everything except the code, added by, candidate and exam
                 details, which are shown greyed out for reference only --%>
            <asp:Panel ID="pnlEditAdmin" runat="server" Visible="false">
                <div class="form-grid">
                    <div class="field">
                        <label>Voucher Code <span class="locked-tag">read only</span></label>
                        <asp:TextBox ID="txtAdminCode" runat="server" Enabled="false" CssClass="locked" />
                    </div>
                    <div class="field">
                        <label>Added By <span class="locked-tag">read only</span></label>
                        <asp:TextBox ID="txtAdminAddedBy" runat="server" Enabled="false" CssClass="locked" />
                    </div>
                    <div class="field">
                        <label>Expiry Date</label>
                        <asp:TextBox ID="txtAdminExpiry" runat="server" TextMode="Date" />
                    </div>
                    <div class="field">
                        <label>Voucher Check Date</label>
                        <asp:TextBox ID="txtAdminCheckDate" runat="server" TextMode="Date" />
                    </div>
                    <div class="field">
                        <label>Voucher Status</label>
                        <asp:DropDownList ID="ddlAdminStatus" runat="server">
                            <asp:ListItem Text="-- Not set --" Value="" />
                            <asp:ListItem Text="Unused"  Value="Unused" />
                            <asp:ListItem Text="Used"    Value="Used" />
                            <asp:ListItem Text="Expired" Value="Expired" />
                            <asp:ListItem Text="Invalid" Value="Invalid" />
                        </asp:DropDownList>
                    </div>
                    <div class="field">
                        <label>Voucher Used Date</label>
                        <asp:TextBox ID="txtAdminUsedDate" runat="server" TextMode="Date" />
                    </div>
                    <%-- The candidate and exam details are the admin's to
                         correct now, so they are fields rather than greyed-out
                         text. Voucher code and Added By stay locked: one
                         identifies the voucher and the other is a record of who
                         put it there, and neither is a correction anybody
                         should be making from here. --%>
                    <div class="field">
                        <label>Candidate Name</label>
                        <asp:TextBox ID="txtAdminCandidate" runat="server" />
                    </div>
                    <div class="field">
                        <label>Exam Date</label>
                        <asp:TextBox ID="txtAdminExamDate" runat="server" TextMode="Date" />
                    </div>
                    <div class="field">
                        <label>Exam Mode</label>
                        <asp:DropDownList ID="ddlAdminExamMode" runat="server">
                            <asp:ListItem Text="-- Select --" Value="" />
                            <asp:ListItem Text="Online"      Value="Online" />
                            <asp:ListItem Text="Test Centre" Value="Test Centre" />
                        </asp:DropDownList>
                    </div>
                    <%-- one name + sale date pair per dealer already on this voucher --%>
                    <asp:Repeater ID="rptAdminDealers" runat="server">
                        <ItemTemplate>
                            <div class="field">
                                <label>Dealer Name <%# Eval("Seq") %></label>
                                <asp:TextBox runat="server" ID="txtDealerName" Text='<%# Eval("DealerName") %>' />
                            </div>
                            <div class="field">
                                <label>Sale Date <%# Eval("Seq") %></label>
                                <asp:TextBox runat="server" ID="txtSaleDate" TextMode="Date" Text='<%# Eval("SaleDate") %>' />
                            </div>
                        </ItemTemplate>
                    </asp:Repeater>
                </div>
            </asp:Panel>

            <%-- Student / sub-admin: status entry --%>
            <asp:Panel ID="pnlEditStatus" runat="server" Visible="false">

                <%-- Student: three buttons instead of a dropdown --%>
                <asp:Panel ID="pnlStatusButtons" runat="server" Visible="false" CssClass="status-picker">
                    <div class="filter-label">Voucher Status</div>
                    <div class="pill-row">
                        <asp:LinkButton ID="lnkStatusUsed" runat="server" CssClass="pill-btn s-used"
                            CommandArgument="Used" OnClick="lnkPickStatus_Click"
                            CausesValidation="false">Used</asp:LinkButton>
                        <asp:LinkButton ID="lnkStatusUnused" runat="server" CssClass="pill-btn s-unused"
                            CommandArgument="Unused" OnClick="lnkPickStatus_Click"
                            CausesValidation="false">Unused</asp:LinkButton>
                        <asp:LinkButton ID="lnkStatusInvalid" runat="server" CssClass="pill-btn s-invalid"
                            CommandArgument="Invalid" OnClick="lnkPickStatus_Click"
                            CausesValidation="false">Invalid</asp:LinkButton>
                    </div>
                </asp:Panel>

                <%-- Hidden outright when nothing inside it is showing - a student
                     with a status other than Used would otherwise get an empty
                     grid holding the dialog open below the buttons. --%>
                <div runat="server" id="divStatusFields" class="form-grid">
                    <%-- Sub-admin / admin: the full dropdown --%>
                    <asp:Panel ID="pnlStatusDropdown" runat="server" CssClass="field">
                        <label>Voucher Status</label>
                        <asp:DropDownList ID="ddlEditStatus" runat="server" AutoPostBack="true"
                            OnSelectedIndexChanged="ddlEditStatus_SelectedIndexChanged">
                            <asp:ListItem Text="-- Not set --" Value="" />
                            <asp:ListItem Text="Unused"  Value="Unused" />
                            <asp:ListItem Text="Used"    Value="Used" />
                            <asp:ListItem Text="Expired" Value="Expired" />
                            <asp:ListItem Text="Invalid" Value="Invalid" />
                        </asp:DropDownList>
                    </asp:Panel>

                    <asp:Panel ID="pnlUsedDate" runat="server" Visible="false" CssClass="field">
                        <label>Voucher Used Date *</label>
                        <asp:TextBox ID="txtUsedDate" runat="server" TextMode="Date" />
                    </asp:Panel>

                    <%-- candidate and exam details are not a student's to set --%>
                    <asp:Panel ID="pnlStatusExtras" runat="server" CssClass="field-group">
                        <div class="field">
                            <label>Candidate Name</label>
                            <asp:TextBox ID="txtCandidate" runat="server" />
                        </div>
                        <div class="field">
                            <label>Exam Date</label>
                            <asp:TextBox ID="txtExamDate" runat="server" TextMode="Date" />
                        </div>
                        <div class="field">
                            <label>Exam Mode</label>
                            <asp:DropDownList ID="ddlExamMode" runat="server">
                                <asp:ListItem Text="-- Select --" Value="" />
                                <asp:ListItem Text="Online"      Value="Online" />
                                <asp:ListItem Text="Test Centre" Value="Test Centre" />
                            </asp:DropDownList>
                        </div>
                    </asp:Panel>
                </div>
            </asp:Panel>

        </div>
        <div class="modal-foot">
            <asp:Button ID="btnSaveEdit" runat="server" CssClass="btn" Text="Save"
                OnClick="btnSaveEdit_Click" />
            <asp:Button ID="btnCancelEdit" runat="server" CssClass="btn btn-light" Text="Cancel"
                OnClick="btnCancelEdit_Click" CausesValidation="false" />
        </div>
      </div>
    </asp:Panel>

    <%-- Target for the "+" rendered into the last Dealer Name header cell --%>
    <asp:LinkButton ID="lnkAddDealer" runat="server" OnClick="lnkAddDealer_Click"
        CausesValidation="false" style="display:none;">+</asp:LinkButton>

    <%-- ---------------- Grid ---------------- --%>
    <div class="card">
        <div class="card-head">
            <h2><asp:Literal ID="litGridTitle" runat="server" Text="Voucher List" />
                (<asp:Literal ID="litCount" runat="server" Text="0" />)</h2>
        </div>
        <%-- "freeze" gives this wrapper its own vertical scroll so the header row
             can stick to the top of it. Sticky against the page would not work:
             the wrapper already scrolls sideways for the dealer columns, and a
             box that scrolls in one axis is the scroll container for both. --%>
        <div class="table-wrap freeze">
            <table class="data">
                <%-- Built in code, not written out here: which columns exist
                     depends on the role and on how many dealer pairs the rows
                     carry, and every one of them has to sort the same way. --%>
                <thead>
                    <tr>
                        <asp:Repeater ID="rptHead" runat="server" OnItemCommand="rptHead_ItemCommand">
                            <ItemTemplate>
                                <th style='<%# Eval("Width") %>'>
                                    <asp:LinkButton runat="server" CssClass="sortcol" CommandName="Sort"
                                        CommandArgument='<%# Eval("Key") %>' CausesValidation="false"
                                        Visible='<%# SortableCell(Container.DataItem) %>'
                                        ToolTip='<%# SortTip(Container.DataItem) %>'>
                                        <%# Server.HtmlEncode(Convert.ToString(Eval("Label"))) %><%# SortArrow(Eval("Key")) %>
                                    </asp:LinkButton>
                                    <asp:Literal runat="server" Mode="PassThrough"
                                        Visible='<%# !SortableCell(Container.DataItem) %>'
                                        Text='<%# Server.HtmlEncode(Convert.ToString(Eval("Label"))) %>' />
                                    <%# Eval("Extra") %>
                                </th>
                            </ItemTemplate>
                        </asp:Repeater>
                    </tr>
                </thead>
                <tbody>
                    <asp:Repeater ID="rptVoucher" runat="server" OnItemCommand="rptVoucher_ItemCommand">
                        <ItemTemplate>
                            <tr>
                                <%-- Icons, not words. These three repeat on every
                                     row, and "Edit  View History  Reassign"
                                     spelled out on each one took more width than
                                     the voucher code beside it. The name moves to
                                     the tooltip and to aria-label, so it is still
                                     there for anyone who needs it read out.

                                     Each button holds nothing but its icon
                                     markup. A LinkButton handed loose text
                                     alongside a child control loses the text at
                                     parse time and renders an empty anchor - the
                                     failure that once emptied the Provider
                                     heading on Voucher Status. --%>
                                <td runat="server" visible='<%# ShowActions %>' class="rowacts">
                                    <asp:LinkButton runat="server" CssClass="rowact" CommandName="EditRow"
                                        CommandArgument='<%# Eval("Id") %>'
                                        Visible='<%# CanEdit %>' aria-label="Edit"
                                        ToolTip="Edit this voucher"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M4 20.5h4L19 9.5a2.8 2.8 0 0 0-4-4L4 16.5v4z" /><path d="M14 6.5l4 4" /></svg></asp:LinkButton>
                                    <asp:LinkButton runat="server" CssClass="rowact" CommandName="HistoryRow"
                                        CommandArgument='<%# Eval("Id") %>'
                                        Visible='<%# CanHistory %>' aria-label="View History"
                                        ToolTip="View History - who held this voucher, and when"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M3.5 12a8.5 8.5 0 1 0 2.6-6.1" /><path d="M3.2 3.4v4.3h4.3" /><path d="M12 7.8V12l3 1.8" /></svg></asp:LinkButton>
                                    <asp:LinkButton runat="server" CssClass="rowact go" CommandName="ReassignRow"
                                        CommandArgument='<%# Eval("Id") %>'
                                        Visible='<%# CanReassign %>' aria-label="Reassign"
                                        ToolTip="Reassign this voucher to a student"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"><path d="M4 8.5h14" /><path d="M14.5 5l3.5 3.5-3.5 3.5" /><path d="M20 15.5H6" /><path d="M9.5 12L6 15.5 9.5 19" /></svg></asp:LinkButton>
                                </td>
                                <td><%# Container.ItemIndex + 1 + RowOffset %></td>
                                <td class="left"><%# Eval("ProductName") %></td>
                                <td class="left"><strong><%# Eval("VoucherCode") %></strong></td>
                                <td><%# DateOrDash(Eval("ExpiryDate")) %></td>
                                <td runat="server" visible='<%# ShowAddedBy %>'><%# Dash(Eval("AddedByName")) %></td>
                                <%# DealerCells(Eval("DealerNames"), Eval("SaleDates")) %>
                                <td><%# StatusBadge(Eval("Status")) %></td>
                                <%-- check date, then who checked it, then the used
                                     date - the cells must stay in the order
                                     BindHead lists them --%>
                                <td>
                                    <asp:HiddenField runat="server" ID="hfCheckId" Value='<%# Eval("Id") %>' />
                                    <asp:CheckBox runat="server" ID="chkCheckDate" AutoPostBack="true"
                                        Checked='<%# Eval("VoucherCheckDate") != DBNull.Value %>'
                                        Enabled='<%# CanCheck && Eval("VoucherCheckDate") == DBNull.Value %>'
                                        OnCheckedChanged="chkCheckDate_CheckedChanged"
                                        ToolTip="Tick to stamp today's date"
                                        Text='<%# " " + DateOrDash(Eval("VoucherCheckDate")) %>' />
                                    <%# MoveNote(Eval("AutoMoveAfter")) %>
                                </td>
                                <td runat="server" visible='<%# ShowCheckedBy %>'><%# Dash(Eval("CheckedBy")) %></td>
                                <td><%# DateOrDash(Eval("UsedDate")) %></td>
                                <td class="left"><%# Dash(Eval("CandidateName")) %></td>
                                <td><%# DateOrDash(Eval("ExamDate")) %></td>
                                <td><%# Dash(Eval("ExamMode")) %></td>
                            </tr>
                        </ItemTemplate>
                    </asp:Repeater>
                    <asp:PlaceHolder ID="phEmpty" runat="server" Visible="false">
                        <tr><td class="empty" colspan="20">No voucher found for the selected filters.</td></tr>
                    </asp:PlaceHolder>
                </tbody>
            </table>
        </div>

        <asp:PlaceHolder ID="phPager" runat="server" Visible="false">
            <div class="pager" style="padding: 0 18px 16px;">
                <span class="info"><asp:Literal ID="litPageInfo" runat="server" /></span>

                <%-- How many rows to a page. Ten is a page of a screen; a hundred
                     is the whole provider at once for anyone reading down a
                     column. Beside the count it changes, rather than up with the
                     status buttons, which narrow what is listed rather than how
                     much of it is shown at a time. --%>
                <span class="psize">
                    <span class="lab">Rows</span>
                    <asp:DropDownList ID="ddlPageSize" runat="server" AutoPostBack="true"
                        CssClass="psel" CausesValidation="false"
                        OnSelectedIndexChanged="ddlPageSize_SelectedIndexChanged"
                        ToolTip="How many rows to show on a page">
                        <asp:ListItem Text="10"  Value="10" />
                        <asp:ListItem Text="20"  Value="20" />
                        <asp:ListItem Text="50"  Value="50" />
                        <asp:ListItem Text="100" Value="100" />
                    </asp:DropDownList>
                </span>

                <asp:LinkButton ID="lnkPrev" runat="server" CssClass="pg" OnClick="lnkPrev_Click"
                    CausesValidation="false">Prev</asp:LinkButton>
                <asp:Repeater ID="rptPager" runat="server" OnItemCommand="rptPager_ItemCommand">
                    <ItemTemplate>
                        <asp:LinkButton runat="server" CommandName="Go"
                            CommandArgument='<%# Eval("Index") %>'
                            CssClass='<%# Eval("CssClass") %>'
                            Text='<%# Eval("Label") %>' CausesValidation="false" />
                    </ItemTemplate>
                </asp:Repeater>
                <asp:LinkButton ID="lnkNext" runat="server" CssClass="pg" OnClick="lnkNext_Click"
                    CausesValidation="false">Next</asp:LinkButton>
            </div>
        </asp:PlaceHolder>
    </div>

    <%-- ================= Upload Entry modal ================= --%>
    <asp:Panel ID="pnlUpload" runat="server" Visible="false" CssClass="modal-back">
        <div class="modal sm">
            <div class="modal-head">
                <h2>Add vouchers</h2>
                <asp:LinkButton ID="lnkUploadClose" runat="server" CssClass="btn btn-light btn-sm"
                    OnClick="lnkUploadClose_Click" CausesValidation="false">Close</asp:LinkButton>
            </div>
            <div class="modal-body">
                <div class="filter-label">Product Name *</div>
                <div class="pill-row" style="margin-bottom: 18px;">
                    <asp:Repeater ID="rptUploadProduct" runat="server" OnItemCommand="rptUploadProduct_ItemCommand">
                        <ItemTemplate>
                            <asp:LinkButton runat="server" CommandName="PickProduct"
                                CommandArgument='<%# Eval("Id") %>'
                                CssClass='<%# UploadProductClass(Eval("Id")) %>'
                                Text='<%# Eval("Name") %>' CausesValidation="false" />
                        </ItemTemplate>
                    </asp:Repeater>
                </div>

                <asp:Panel ID="pnlUploadMsg" runat="server" Visible="false" CssClass="msg msg-bad">
                    <asp:Literal ID="litUploadMsg" runat="server" />
                </asp:Panel>

                <div class="paste-help">
                    Paste from Excel, one voucher per line, columns in this order:<br />
                    <code>Voucher Code</code> &rarr; <code>Expiry Date</code> &rarr;
                    <code>Dealer Name 1</code> &rarr; <code>Sale Date 1</code> &rarr;
                    <code>Dealer Name 2</code> &rarr; <code>Sale Date 2</code> &rarr; &hellip;<br />
                    Only the first two are needed. Add as many dealer pairs as a voucher has &ndash;
                    one line may carry one dealer and the next three, and both save.
                    Leave a pair blank to skip it.<br />
                    Tab, comma, semicolon or pipe all work as the separator &ndash; not a space,
                    because voucher codes may contain spaces.<br />
                    Dates are read <strong>day first</strong>:
                    <code>14-08-2026</code>, <code>14/08/2026</code>, <code>14-Aug-2026</code>
                    and <code>2026-08-14</code> all mean 14 August 2026.
                </div>

                <asp:TextBox ID="txtPaste" runat="server" TextMode="MultiLine" CssClass="paste-area"
                    placeholder="AWS-FN-100001&#9;31-12-2026&#9;Dealer A&#9;05-01-2026&#10;AWS-FN-100002&#9;31-12-2026&#9;Dealer A&#9;05-01-2026&#9;Dealer B&#9;09-02-2026&#10;AWS-FN-100003&#9;31-12-2026" />
            </div>
            <div class="modal-foot">
                <span class="spacer"><asp:Literal ID="litUploadHint" runat="server" /></span>
                <asp:Button ID="btnUploadSave" runat="server" CssClass="btn" Text="Save"
                    OnClick="btnUploadSave_Click" />
            </div>
        </div>
    </asp:Panel>

    <%-- ================= View History modal =================
         One voucher's life, oldest first, so it reads as a story: assigned to
         a student, checked, reassigned, checked again. Grouped by hand-off so
         the number of rounds is countable at a glance rather than inferred. --%>
    <asp:Panel ID="pnlHistory" runat="server" Visible="false" CssClass="modal-back">
        <div class="modal lg">
            <div class="modal-head">
                <h2>Voucher History &mdash; <asp:Literal ID="litHistCode" runat="server" /></h2>
                <asp:LinkButton ID="lnkHistoryClose" runat="server" CssClass="btn btn-light btn-sm"
                    OnClick="lnkHistoryClose_Click" CausesValidation="false">Close</asp:LinkButton>
            </div>
            <div class="modal-body">
                <div class="hist-sum"><asp:Literal ID="litHistSummary" runat="server" /></div>

                <asp:Repeater ID="rptHistory" runat="server">
                    <ItemTemplate>
                        <%# RoundHead(Container.DataItem, Container.ItemIndex) %>
                        <div class='<%# "hist-step " + StepKind(Eval("Activity")) %>'>
                            <span class="dot"></span>
                            <div class="what">
                                <b><%# Server.HtmlEncode(Convert.ToString(Eval("Activity"))) %></b>
                                <span class="who"><%# HistoryWho(Container.DataItem) %></span>
                            </div>
                            <span class="when"><%# Eval("ChangedDate", "{0:dd-MMM-yyyy  HH:mm}") %></span>
                        </div>
                    </ItemTemplate>
                </asp:Repeater>

                <asp:PlaceHolder ID="phHistoryEmpty" runat="server" Visible="false">
                    <div class="hist-empty">
                        Nothing recorded against this voucher yet. History starts the
                        first time it is assigned, checked or edited.
                    </div>
                </asp:PlaceHolder>
            </div>
        </div>
    </asp:Panel>

    <%-- ================= Assign modal ================= --%>
    <asp:Panel ID="pnlAssign" runat="server" Visible="false" CssClass="modal-back">
        <div class="modal xl">
            <div class="modal-head">
                <h2><asp:Literal ID="litAssignTitle" runat="server" Text="Assign Vouchers" /></h2>
                <asp:LinkButton ID="lnkAssignClose" runat="server" CssClass="btn btn-light btn-sm"
                    OnClick="lnkAssignClose_Click" CausesValidation="false">Close</asp:LinkButton>
            </div>
            <div class="modal-body">
                <asp:Panel ID="pnlAssignMsg" runat="server" Visible="false" CssClass="msg msg-bad">
                    <asp:Literal ID="litAssignMsg" runat="server" />
                </asp:Panel>

                <div class="filters" style="margin-bottom: 16px;">
                    <div class="field">
                        <label>Product Name</label>
                        <asp:DropDownList ID="ddlAssignProduct" runat="server" AutoPostBack="true"
                            OnSelectedIndexChanged="ddlAssignProduct_SelectedIndexChanged" />
                    </div>
                    <div class="field">
                        <label>Select first N entries</label>
                        <asp:TextBox ID="txtAssignCount" runat="server" TextMode="Number" placeholder="100" />
                    </div>
                    <div class="field">
                        <asp:Button ID="btnAssignPick" runat="server" CssClass="btn btn-light" Text="Select"
                            OnClick="btnAssignPick_Click" CausesValidation="false" />
                    </div>
                </div>

                <div class="assign-split">
                    <div class="box">
                        <h3><asp:Literal ID="litAssignBox" runat="server" Text="Unassigned Vouchers" />
                            (<asp:Literal ID="litAssignCount" runat="server" Text="0" />)</h3>
                        <div class="scroll">
                            <table class="data" style="border: 0;">
                                <thead>
                                    <tr>
                                        <th style="width: 60px;">Pick</th>
                                        <th>Product Name</th>
                                        <th>Voucher Code</th>
                                        <th>Expiry Date</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <asp:Repeater ID="rptAssignVouchers" runat="server">
                                        <ItemTemplate>
                                            <tr>
                                                <td>
                                                    <asp:CheckBox runat="server" ID="chkPick"
                                                        Checked='<%# IsPicked(Eval("Id")) %>' />
                                                    <asp:HiddenField runat="server" ID="hfVoucherId" Value='<%# Eval("Id") %>' />
                                                </td>
                                                <td class="left"><%# Eval("ProductName") %></td>
                                                <td class="left"><strong><%# Eval("VoucherCode") %></strong></td>
                                                <td><%# DateOrDash(Eval("ExpiryDate")) %></td>
                                            </tr>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                    <asp:PlaceHolder ID="phAssignEmpty" runat="server" Visible="false">
                                        <tr><td colspan="4" class="empty">
                                            <asp:Literal ID="litAssignEmpty" runat="server" Text="No unassigned vouchers." />
                                        </td></tr>
                                    </asp:PlaceHolder>
                                </tbody>
                            </table>
                        </div>
                    </div>

                    <div class="box">
                        <h3>Students</h3>
                        <div class="scroll">
                            <table class="data" style="border: 0;">
                                <thead>
                                    <tr>
                                        <th style="width: 60px;">Pick</th>
                                        <th>Student Name</th>
                                        <th>Email</th>
                                    </tr>
                                </thead>
                                <tbody>
                                    <asp:Repeater ID="rptStudents" runat="server">
                                        <ItemTemplate>
                                            <tr>
                                                <td>
                                                    <%-- A plain input, deliberately not asp:RadioButton. Every
                                                         RepeaterItem is its own naming container, so ASP.NET gives
                                                         each row a different name - ctl00$student, ctl01$student -
                                                         and the browser then treats every row as a group of one.
                                                         That is how five students came to be selected at once.
                                                         One literal name across the whole list is what makes it a
                                                         single choice, and the value carries the id, so the hidden
                                                         field is no longer needed. --%>
                                                    <input type="radio" name="assignStudent"
                                                           value='<%# Eval("Id") %>' <%# StudentChecked(Eval("Id")) %> />
                                                </td>
                                                <td class="left"><%# Eval("FullName") %></td>
                                                <td class="left"><%# Eval("Email") %></td>
                                            </tr>
                                        </ItemTemplate>
                                    </asp:Repeater>
                                    <asp:PlaceHolder ID="phStudentsEmpty" runat="server" Visible="false">
                                        <tr><td colspan="3" class="empty">
                                            No user is mapped to the "Voucher Student" role.
                                        </td></tr>
                                    </asp:PlaceHolder>
                                </tbody>
                            </table>
                        </div>
                    </div>
                </div>
            </div>
            <div class="modal-foot">
                <asp:Button ID="btnAssignSave" runat="server" CssClass="btn" Text="Assign"
                    OnClick="btnAssignSave_Click" />
            </div>
        </div>
    </asp:Panel>

    <%-- ================= Reassign modal ================= --%>
    <asp:Panel ID="pnlReassign" runat="server" Visible="false" CssClass="modal-back">
        <div class="modal sm">
            <div class="modal-head">
                <h2>Reassign Voucher</h2>
                <asp:LinkButton ID="lnkReassignClose" runat="server" CssClass="btn btn-light btn-sm"
                    OnClick="lnkReassignClose_Click" CausesValidation="false">Close</asp:LinkButton>
            </div>
            <div class="modal-body">
                <asp:HiddenField ID="hfReassignId" runat="server" />
                <asp:Panel ID="pnlReassignMsg" runat="server" Visible="false" CssClass="msg msg-bad">
                    <asp:Literal ID="litReassignMsg" runat="server" />
                </asp:Panel>
                <p style="margin-top: 0; color: #64748b;">
                    Voucher <strong><asp:Literal ID="litReassignCode" runat="server" /></strong>
                    goes back to the selected student for another check.
                </p>
                <div class="field">
                    <label>Student</label>
                    <asp:DropDownList ID="ddlReassignStudent" runat="server" />
                </div>
            </div>
            <div class="modal-foot">
                <asp:Button ID="btnReassignSave" runat="server" CssClass="btn" Text="Reassign"
                    OnClick="btnReassignSave_Click" />
            </div>
        </div>
    </asp:Panel>


</asp:Panel>
</asp:Content>
