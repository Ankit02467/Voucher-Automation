<%@ Page Language="C#" AutoEventWireup="true" MasterPageFile="~/MasterPage.master"
    CodeBehind="voucher-data.aspx.cs" Inherits="DSL_CMS.voucher_data" %>

<asp:Content ContentPlaceHolderID="TitleContent" runat="server">Voucher Data - DSL CMS/OSS</asp:Content>

<asp:Content ContentPlaceHolderID="MainContent" runat="server">

    <%-- ---------------- Toolbar ---------------- --%>
    <div class="toolbar">
        <a class="btn-back" href='<%= BackUrl %>'
           title="Back to Voucher Status">&#8592; Back</a>
        <h1><asp:Literal ID="litProvider" runat="server" Text="Voucher Data" /></h1>
        <span class="role-chip"><asp:Literal ID="litRole" runat="server" /></span>

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
        <asp:LinkButton ID="lnkHistory" runat="server" CssClass="pill-btn" Visible="false"
            OnClick="lnkHistory_Click" CausesValidation="false">View History</asp:LinkButton>
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

    <%-- ---------------- Filters ---------------- --%>
    <div class="card">
        <div class="card-head"><h2>Filters</h2></div>
        <div class="card-body">
            <div class="filters">
                <div class="field">
                    <label>Product Name</label>
                    <asp:DropDownList ID="ddlFilterProduct" runat="server" />
                </div>
                <div class="field">
                    <label>Voucher Code</label>
                    <asp:TextBox ID="txtFilterCode" runat="server" />
                </div>
                <asp:Panel ID="pnlFilterDealer" runat="server" CssClass="field">
                    <label>Dealer Name</label>
                    <asp:TextBox ID="txtFilterDealer" runat="server" />
                </asp:Panel>
                <div class="field">
                    <label>Expiry Date</label>
                    <asp:TextBox ID="txtFilterExpiry" runat="server" TextMode="Date" />
                </div>
                <div class="field">
                    <label>Voucher Check Date</label>
                    <asp:TextBox ID="txtFilterCheckDate" runat="server" TextMode="Date" />
                </div>
                <div class="field">
                    <label>Checked By</label>
                    <asp:DropDownList ID="ddlFilterCheckedBy" runat="server" />
                </div>
                <div class="field">
                    <asp:Button ID="btnSearch" runat="server" CssClass="btn" Text="Search"
                        OnClick="btnSearch_Click" CausesValidation="false" />
                </div>
                <div class="field">
                    <asp:Button ID="btnResetFilter" runat="server" CssClass="btn btn-light" Text="Reset"
                        OnClick="btnResetFilter_Click" CausesValidation="false" />
                </div>
            </div>
        </div>
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
                    <div class="field">
                        <label>Candidate Name <span class="locked-tag">read only</span></label>
                        <asp:TextBox ID="txtAdminCandidate" runat="server" Enabled="false" CssClass="locked" />
                    </div>
                    <div class="field">
                        <label>Exam Date <span class="locked-tag">read only</span></label>
                        <asp:TextBox ID="txtAdminExamDate" runat="server" Enabled="false" CssClass="locked" />
                    </div>
                    <div class="field">
                        <label>Exam Mode <span class="locked-tag">read only</span></label>
                        <asp:TextBox ID="txtAdminExamMode" runat="server" Enabled="false" CssClass="locked" />
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
        <div class="table-wrap">
            <table class="data">
                <thead>
                    <tr>
                        <th runat="server" id="thActions" style="width: 150px;">Actions</th>
                        <th style="width: 70px;">S.No</th>
                        <th>Product Name</th>
                        <th>Voucher Code</th>
                        <th>Expiry Date</th>
                        <th runat="server" id="thAddedBy">Added By</th>
                        <asp:Literal ID="litDealerHeaders" runat="server" Mode="PassThrough" />
                        <th>Voucher Status</th>
                        <th>Voucher Used Date</th>
                        <th>Voucher Check Date</th>
                        <th runat="server" id="thCheckedBy">Checked By</th>
                        <th>Candidate Name</th>
                        <th>Exam Date</th>
                        <th>Exam Mode</th>
                    </tr>
                </thead>
                <tbody>
                    <asp:Repeater ID="rptVoucher" runat="server" OnItemCommand="rptVoucher_ItemCommand">
                        <ItemTemplate>
                            <tr>
                                <td runat="server" visible='<%# ShowActions %>' style="white-space: nowrap;">
                                    <asp:LinkButton runat="server" CssClass="btn-out btn-sm" CommandName="EditRow"
                                        CommandArgument='<%# Eval("Id") %>'
                                        Visible='<%# CanEdit %>'>Edit</asp:LinkButton>
                                    <asp:LinkButton runat="server" CssClass="btn-fill btn-sm" CommandName="ReassignRow"
                                        CommandArgument='<%# Eval("Id") %>'
                                        Visible='<%# CanReassign %>'>Reassign</asp:LinkButton>
                                </td>
                                <td><%# Container.ItemIndex + 1 + RowOffset %></td>
                                <td class="left"><%# Eval("ProductName") %></td>
                                <td class="left"><strong><%# Eval("VoucherCode") %></strong></td>
                                <td><%# DateOrDash(Eval("ExpiryDate")) %></td>
                                <td runat="server" visible='<%# ShowAddedBy %>'><%# Dash(Eval("AddedByName")) %></td>
                                <%# DealerCells(Eval("DealerNames"), Eval("SaleDates")) %>
                                <td><%# StatusBadge(Eval("Status")) %></td>
                                <td><%# DateOrDash(Eval("UsedDate")) %></td>
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
                    Copy the <code>Voucher Code</code> and <code>Expiry Date</code> columns from Excel
                    and paste them here, one voucher per line. Tab, comma, semicolon or pipe all work
                    as the separator &ndash; not a space, because voucher codes may contain spaces.<br />
                    Dates are read <strong>day first</strong>:
                    <code>14-08-2026</code>, <code>14/08/2026</code>, <code>14-Aug-2026</code>
                    and <code>2026-08-14</code> all mean 14 August 2026.
                </div>

                <asp:TextBox ID="txtPaste" runat="server" TextMode="MultiLine" CssClass="paste-area"
                    placeholder="AWS-FN-100001&#9;31-12-2026&#10;AWS-FN-100002&#9;31-12-2026" />
            </div>
            <div class="modal-foot">
                <span class="spacer"><asp:Literal ID="litUploadHint" runat="server" /></span>
                <asp:Button ID="btnUploadSave" runat="server" CssClass="btn" Text="Save"
                    OnClick="btnUploadSave_Click" />
            </div>
        </div>
    </asp:Panel>

    <%-- ================= View History modal ================= --%>
    <asp:Panel ID="pnlHistory" runat="server" Visible="false" CssClass="modal-back">
        <div class="modal xl">
            <div class="modal-head">
                <h2>Voucher History</h2>
                <asp:LinkButton ID="lnkHistoryClose" runat="server" CssClass="btn btn-light btn-sm"
                    OnClick="lnkHistoryClose_Click" CausesValidation="false">Close</asp:LinkButton>
            </div>
            <div class="modal-body">
                <div class="table-wrap">
                    <table class="data">
                        <thead>
                            <tr>
                                <th style="width: 80px;">S.No</th>
                                <th>Product Name</th>
                                <th>Voucher Code</th>
                                <th>Voucher Status</th>
                                <th>Activity</th>
                                <th>Student</th>
                                <th>Checked By</th>
                                <th>Voucher Check Date</th>
                            </tr>
                        </thead>
                        <tbody>
                            <asp:Repeater ID="rptHistory" runat="server">
                                <ItemTemplate>
                                    <tr>
                                        <td><%# Container.ItemIndex + 1 %></td>
                                        <td class="left"><%# Dash(Eval("ProductName")) %></td>
                                        <td class="left"><strong><%# Eval("VoucherCode") %></strong></td>
                                        <td><%# StatusBadge(Eval("Status")) %></td>
                                        <td><%# Dash(Eval("Activity")) %></td>
                                        <td><%# Dash(Eval("AssignedToName")) %></td>
                                        <td><%# Dash(Eval("CheckedBy")) %></td>
                                        <td><%# Eval("ChangedDate", "{0:dd-MMM-yyyy HH:mm}") %></td>
                                    </tr>
                                </ItemTemplate>
                            </asp:Repeater>
                            <asp:PlaceHolder ID="phHistoryEmpty" runat="server" Visible="false">
                                <tr><td colspan="8" class="empty">No status changes recorded yet.</td></tr>
                            </asp:PlaceHolder>
                        </tbody>
                    </table>
                </div>
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

</asp:Content>
