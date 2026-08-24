<%@ Page Language="C#" AutoEventWireup="true" MasterPageFile="~/MasterPage.master"
    CodeBehind="product-performance.aspx.cs" Inherits="DSL_CMS.product_performance" %>

<asp:Content ContentPlaceHolderID="TitleContent" runat="server">Product wise Performance - DSL CMS/OSS</asp:Content>

<asp:Content ContentPlaceHolderID="MainContent" runat="server">

    <%-- ---------------- Toolbar ---------------- --%>
    <div class="toolbar">
        <a class="btn-back" href='<%= ResolveUrl("~/voucher-status.aspx") %>'
           title="Back to Voucher Status">&#8592; Back</a>
        <h1>Product wise Performance</h1>
        <span class="role-chip"><asp:Literal ID="litRole" runat="server" /></span>
    </div>

    <asp:Panel ID="pnlDenied" runat="server" Visible="false" CssClass="msg msg-bad">
        Product wise Performance is available to Voucher Admin only.
    </asp:Panel>

    <asp:Panel ID="pnlBody" runat="server">

        <p class="muted" style="margin: 0 0 14px;">
            How many vouchers were checked, per provider. Click a provider to see the
            same figures for each of its products.
            <strong>Today</strong> is today, <strong>Weekly</strong> the last 7 days and
            <strong>Monthly</strong> the last 30 days &ndash; rolling windows, so they do
            not reset on a Monday or on the 1st.
        </p>

        <div class="table-wrap">
            <table class="data">
                <thead>
                    <%-- "Voucher Checked Date" spans the three windows beneath it --%>
                    <tr>
                        <th rowspan="2" style="width: 110px;">S.No.</th>
                        <th rowspan="2">Provider</th>
                        <th colspan="3">Voucher Checked Date</th>
                    </tr>
                    <tr>
                        <th style="width: 150px;">Today</th>
                        <th style="width: 150px;">Weekly</th>
                        <th style="width: 150px;">Monthly</th>
                    </tr>
                </thead>
                <tbody>
                    <asp:Repeater ID="rptProviders" runat="server" OnItemCommand="rptProviders_ItemCommand">
                        <ItemTemplate>
                            <tr>
                                <td><%# Container.ItemIndex + 1 %></td>
                                <td class="left">
                                    <asp:LinkButton runat="server" CssClass="chev" CommandName="ToggleProducts"
                                        CommandArgument='<%# Eval("Id") %>' CausesValidation="false"
                                        ToolTip="Show products">
                                        <span class='<%# ChevronClass(Eval("Id")) %>'>&#9656;</span>
                                        <span><%# Server.HtmlEncode(Convert.ToString(Eval("ProviderName"))) %></span>
                                        <span class="chev-count">(<%# Eval("ProductCount") %>)</span>
                                    </asp:LinkButton>
                                </td>
                                <td><%# Eval("Today") %></td>
                                <td><%# Eval("Weekly") %></td>
                                <td><%# Eval("Monthly") %></td>
                            </tr>

                            <%-- Products come out as rows of their own, so their figures
                                 sit directly under Today / Weekly / Monthly. --%>
                            <asp:PlaceHolder runat="server" Visible='<%# IsExpanded(Eval("Id")) %>'>
                                <asp:Repeater runat="server" DataSource='<%# ProductChecks(Eval("Id")) %>'>
                                    <ItemTemplate>
                                        <tr class="sub-row">
                                            <td></td>
                                            <td class="left sub-name"><%# Server.HtmlEncode(Convert.ToString(Eval("ProductName"))) %></td>
                                            <td><%# Eval("Today") %></td>
                                            <td><%# Eval("Weekly") %></td>
                                            <td><%# Eval("Monthly") %></td>
                                        </tr>
                                    </ItemTemplate>
                                </asp:Repeater>
                                <asp:PlaceHolder runat="server" Visible='<%# !HasProducts(Eval("Id")) %>'>
                                    <tr class="sub-row">
                                        <td></td>
                                        <td colspan="4" class="left sub-name muted">No data to show yet.</td>
                                    </tr>
                                </asp:PlaceHolder>
                            </asp:PlaceHolder>
                        </ItemTemplate>
                    </asp:Repeater>

                    <asp:PlaceHolder ID="phEmpty" runat="server" Visible="false">
                        <tr><td colspan="5" class="empty">No data to show yet.</td></tr>
                    </asp:PlaceHolder>
                </tbody>
            </table>
        </div>

    </asp:Panel>

</asp:Content>
