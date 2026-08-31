<%@ Page Language="C#" AutoEventWireup="true" MasterPageFile="~/MasterPage.master"
    CodeBehind="student-performance.aspx.cs" Inherits="DSL_CMS.student_performance" %>

<asp:Content ContentPlaceHolderID="TitleContent" runat="server">Student Performance - DSL CMS/OSS</asp:Content>

<asp:Content ContentPlaceHolderID="MainContent" runat="server">

    <%-- ---------------- Toolbar ---------------- --%>
    <div class="toolbar">
        <a class="btn-back" href='<%= ResolveUrl("~/voucher-status.aspx") %>'
           title="Back to Voucher Status">&#8592; Back</a>
        <h1>Student wise Performance</h1>
    </div>

    <asp:Panel ID="pnlDenied" runat="server" Visible="false" CssClass="msg msg-bad">
        This screen is available to Voucher Admin and Voucher Sub Admin only.
    </asp:Panel>

    <asp:Panel ID="pnlBody" runat="server">

        <%-- ---------------- Provider filter ---------------- --%>
        <div class="filter-block">
            <div class="filter-label">Provider</div>
            <div class="pill-row">
                <asp:Repeater ID="rptProvider" runat="server" OnItemCommand="rptProvider_ItemCommand">
                    <ItemTemplate>
                        <asp:LinkButton runat="server" CommandName="PickProvider"
                            CommandArgument='<%# Eval("Value") %>'
                            CssClass='<%# ProviderPillClass(Eval("Value")) %>'
                            Text='<%# Eval("Text") %>' CausesValidation="false" />
                    </ItemTemplate>
                </asp:Repeater>
            </div>
        </div>

        <p class="muted" style="margin: 0 0 14px;">
            Counts how many vouchers each student has checked.
            <strong>Today</strong> is today, <strong>Weekly</strong> the last 7 days and
            <strong>Monthly</strong> the last 30 days &ndash; rolling windows, so they do
            not reset on a Monday or on the 1st.
        </p>

        <%-- ---------------- Grid ---------------- --%>
        <div class="table-wrap">
            <table class="data">
                <thead>
                    <tr>
                        <th style="width: 110px;">S.No.</th>
                        <th>Student Name</th>
                        <th style="width: 150px;">Today</th>
                        <th style="width: 150px;">Weekly</th>
                        <th style="width: 150px;">Monthly</th>
                    </tr>
                </thead>
                <tbody>
                    <asp:Repeater ID="rptPerformance" runat="server">
                        <ItemTemplate>
                            <tr>
                                <td><%# Container.ItemIndex + 1 %></td>
                                <td class="left"><%# Server.HtmlEncode(Convert.ToString(Eval("StudentName"))) %></td>
                                <td><%# Eval("Today") %></td>
                                <td><%# Eval("Weekly") %></td>
                                <td><%# Eval("Monthly") %></td>
                            </tr>
                        </ItemTemplate>
                    </asp:Repeater>
                    <asp:PlaceHolder ID="phEmpty" runat="server" Visible="false">
                        <tr><td colspan="5" class="empty">No students found.</td></tr>
                    </asp:PlaceHolder>
                </tbody>
            </table>
        </div>

    </asp:Panel>

</asp:Content>
