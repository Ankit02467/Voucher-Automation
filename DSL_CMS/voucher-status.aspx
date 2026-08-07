<%@ Page Language="C#" AutoEventWireup="true" MasterPageFile="~/MasterPage.master"
    CodeBehind="voucher-status.aspx.cs" Inherits="DSL_CMS.voucher_status" %>

<asp:Content ContentPlaceHolderID="TitleContent" runat="server">Voucher Status - DSL CMS/OSS</asp:Content>

<asp:Content ContentPlaceHolderID="MainContent" runat="server">

    <%-- ---------------- Status ---------------- --%>
    <div class="filter-block">
        <div class="filter-label">Status</div>
        <div class="pill-row">
            <asp:Repeater ID="rptStatus" runat="server" OnItemCommand="rptStatus_ItemCommand">
                <ItemTemplate>
                    <asp:LinkButton runat="server" CommandName="PickStatus"
                        CommandArgument='<%# Eval("Value") %>'
                        CssClass='<%# StatusPillClass(Eval("Value")) %>'
                        Text='<%# Eval("Text") %>' CausesValidation="false" />
                </ItemTemplate>
            </asp:Repeater>
        </div>

        <%-- Expiry windows: only offered while Unused is the selected status --%>
        <asp:Panel ID="pnlWindows" runat="server" Visible="false" CssClass="pill-row" style="margin-top: 14px;">
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

    <%-- ---------------- Category ---------------- --%>
    <div class="filter-block">
        <div class="filter-label">Category</div>
        <div class="pill-row">
            <asp:Repeater ID="rptCategory" runat="server" OnItemCommand="rptCategory_ItemCommand">
                <ItemTemplate>
                    <asp:LinkButton runat="server" CommandName="PickCategory"
                        CommandArgument='<%# Eval("Category") %>'
                        CssClass='<%# CategoryPillClass(Eval("Category")) %>'
                        Text='<%# Eval("Category") %>' CausesValidation="false" />
                </ItemTemplate>
            </asp:Repeater>
        </div>
    </div>

    <%-- ---------------- Grid ---------------- --%>
    <div class="table-wrap">
        <table class="data">
            <thead>
                <tr>
                    <th style="width: 110px;">S.No.</th>
                    <th>Provider</th>
                    <th style="width: 170px;"><asp:Literal ID="litCountHead" runat="server" Text="All" /></th>
                    <th style="width: 380px;">Actions</th>
                </tr>
            </thead>
            <tbody>
                <asp:Repeater ID="rptSummary" runat="server" OnItemCommand="rptSummary_ItemCommand">
                    <ItemTemplate>
                        <tr>
                            <td><%# Container.ItemIndex + 1 + RowOffset %></td>
                            <td class="left">
                                <asp:LinkButton runat="server" CssClass="chev" CommandName="ToggleProducts"
                                    CommandArgument='<%# Eval("Id") %>' CausesValidation="false"
                                    ToolTip="Show products">
                                    <span class='<%# ChevronClass(Eval("Id")) %>'>&#9656;</span>
                                    <span><%# Eval("Name") %></span>
                                    <span class="chev-count">(<%# Eval("ProductCount") %>)</span>
                                </asp:LinkButton>
                                <%-- products open inside this same cell, not on a new row --%>
                                <asp:PlaceHolder runat="server" Visible='<%# IsExpanded(Eval("Id")) %>'>
                                    <div class="prod-list"><%# ProductChips(Eval("ProductNames")) %></div>
                                </asp:PlaceHolder>
                            </td>
                            <td><%# Eval("StatusCount", "{0:00}") %></td>
                            <td>
                                <span class="act">
                                    <a class="btn-fill" href='<%# ViewDataUrl(Eval("Id")) %>'>View Data</a>
                                    <asp:HyperLink runat="server" CssClass="btn-out"
                                        NavigateUrl='<%# ManageProductUrl(Eval("Id")) %>'
                                        Visible='<%# CanManageProduct %>' Text="Manage Product" />
                                </span>
                            </td>
                        </tr>
                    </ItemTemplate>
                </asp:Repeater>
                <asp:PlaceHolder ID="phEmpty" runat="server" Visible="false">
                    <tr><td colspan="4" class="empty">No provider found for the selected filters.</td></tr>
                </asp:PlaceHolder>
            </tbody>
        </table>
    </div>

    <%-- ---------------- Pagination ---------------- --%>
    <asp:PlaceHolder ID="phPager" runat="server" Visible="false">
        <div class="pager">
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

</asp:Content>
