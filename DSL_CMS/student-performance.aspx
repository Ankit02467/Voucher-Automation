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
            One row per student and provider &ndash; a student holding two providers has
            two rows, because those are two piles of work. <strong>All</strong> is what
            they are holding of that provider right now, <strong>Checked</strong> the ones
            they have already set a status on (those move to the sub admin tonight) and
            <strong>Pending</strong> the rest, so All is always the other two added up.
            <strong>Weekly</strong> and <strong>Monthly</strong> count what they have
            checked over the last 7 and 30 days &ndash; rolling windows, so they do not
            reset on a Monday or on the 1st. Open a provider to see the products under it.
        </p>

        <%-- ---------------- Grid ---------------- --%>
        <div class="table-wrap">
            <table class="data sp-table">
                <thead>
                    <tr>
                        <th style="width: 70px;">S.No.</th>
                        <th class="left" style="min-width: 190px;">
                            <asp:LinkButton ID="lnkSortStudent" runat="server" CssClass="sortcol"
                                OnCommand="sort_Command" CommandArgument="StudentName"
                                CausesValidation="false"><asp:Literal runat="server" Text="Student Name" /><asp:Literal ID="litSortStudent" runat="server" /></asp:LinkButton>
                        </th>
                        <th class="left" style="min-width: 210px;">
                            <asp:LinkButton ID="lnkSortProvider" runat="server" CssClass="sortcol"
                                OnCommand="sort_Command" CommandArgument="ProviderName"
                                CausesValidation="false"><asp:Literal runat="server" Text="Provider" /><asp:Literal ID="litSortProvider" runat="server" /></asp:LinkButton>
                        </th>
                        <th style="width: 120px;">
                            <asp:LinkButton ID="lnkSortAll" runat="server" CssClass="sortcol"
                                OnCommand="sort_Command" CommandArgument="AllCount"
                                CausesValidation="false"><asp:Literal runat="server" Text="Today All" /><asp:Literal ID="litSortAll" runat="server" /></asp:LinkButton>
                        </th>
                        <th style="width: 120px;">
                            <asp:LinkButton ID="lnkSortChecked" runat="server" CssClass="sortcol"
                                OnCommand="sort_Command" CommandArgument="CheckedCount"
                                CausesValidation="false"><asp:Literal runat="server" Text="Checked" /><asp:Literal ID="litSortChecked" runat="server" /></asp:LinkButton>
                        </th>
                        <th style="width: 120px;">
                            <asp:LinkButton ID="lnkSortPending" runat="server" CssClass="sortcol"
                                OnCommand="sort_Command" CommandArgument="PendingCount"
                                CausesValidation="false"><asp:Literal runat="server" Text="Pending" /><asp:Literal ID="litSortPending" runat="server" /></asp:LinkButton>
                        </th>
                        <th style="width: 120px;">
                            <asp:LinkButton ID="lnkSortWeekly" runat="server" CssClass="sortcol"
                                OnCommand="sort_Command" CommandArgument="Weekly"
                                CausesValidation="false"><asp:Literal runat="server" Text="Weekly" /><asp:Literal ID="litSortWeekly" runat="server" /></asp:LinkButton>
                        </th>
                        <th style="width: 120px;">
                            <asp:LinkButton ID="lnkSortMonthly" runat="server" CssClass="sortcol"
                                OnCommand="sort_Command" CommandArgument="Monthly"
                                CausesValidation="false"><asp:Literal runat="server" Text="Monthly" /><asp:Literal ID="litSortMonthly" runat="server" /></asp:LinkButton>
                        </th>
                    </tr>
                </thead>
                <tbody>
                    <%-- Everything on the screen added up, so "how much is out with
                         the students altogether" needs no adding up by eye. It sits
                         at the top rather than the bottom because it is the headline,
                         and it follows the provider filter - a total of rows nobody
                         is being shown would answer a question nobody asked. --%>
                    <tr class="sp-total">
                        <td colspan="3" class="left">
                            <b>Total</b>
                            <span class="sp-scope"><asp:Literal ID="litTotalLabel" runat="server" /></span>
                        </td>
                        <td><asp:Literal ID="litTotalAll" runat="server" Text="0" /></td>
                        <td class="sp-done"><asp:Literal ID="litTotalChecked" runat="server" Text="0" /></td>
                        <td class="sp-todo"><asp:Literal ID="litTotalPending" runat="server" Text="0" /></td>
                        <td><asp:Literal ID="litTotalWeekly" runat="server" Text="0" /></td>
                        <td><asp:Literal ID="litTotalMonthly" runat="server" Text="0" /></td>
                    </tr>

                    <asp:Repeater ID="rptPerformance" runat="server" OnItemCommand="rptPerformance_ItemCommand">
                        <ItemTemplate>
                            <tr class='<%# RowClass(Eval("Key")) %>'>
                                <td><%# Container.ItemIndex + 1 %></td>
                                <td class="left"><%# StudentCell(Eval("StudentId"), Eval("StudentName")) %></td>
                                <td class="left">
                                    <%-- The chevron is the only thing on this table that
                                         does anything. Clicking a provider or a product
                                         does not open a screen: this one answers "who has
                                         what" and is not a way through to anywhere. --%>
                                    <asp:LinkButton runat="server" CommandName="ToggleProducts"
                                        CommandArgument='<%# Eval("Key") %>' CausesValidation="false"
                                        CssClass="sp-toggle" ToolTip="Show the products held">
                                        <span class='<%# CaretClass(Eval("Key")) %>'>
                                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"
                                                 stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"
                                                 width="13" height="13"><path d="M9 6l6 6-6 6" /></svg>
                                        </span>
                                        <span class="nm">
                                            <b><%# Server.HtmlEncode(Convert.ToString(Eval("ProviderName"))) %></b>
                                            <small><%# ProductLabel(Eval("ProductCount")) %></small>
                                        </span>
                                    </asp:LinkButton>
                                </td>
                                <td><b><%# Eval("AllCount") %></b></td>
                                <td class="sp-done"><%# Eval("CheckedCount") %></td>
                                <td class="sp-todo"><%# Eval("PendingCount") %></td>
                                <td><%# Eval("Weekly") %></td>
                                <td><%# Eval("Monthly") %></td>
                            </tr>
                            <%# ProductRows(Eval("Key"), Eval("ProductNames"), Eval("ProductAll"),
                                            Eval("ProductChecked"), Eval("ProductPending")) %>
                        </ItemTemplate>
                    </asp:Repeater>

                    <asp:PlaceHolder ID="phEmpty" runat="server" Visible="false">
                        <tr><td colspan="8" class="empty">No student is holding any vouchers just now.</td></tr>
                    </asp:PlaceHolder>
                </tbody>
            </table>
        </div>

    </asp:Panel>

</asp:Content>
