<%@ Page Language="C#" AutoEventWireup="true" MasterPageFile="~/MasterPage.master"
    CodeBehind="voucher-status.aspx.cs" Inherits="DSL_CMS.voucher_status" %>

<asp:Content ContentPlaceHolderID="TitleContent" runat="server">Voucher Status - DSL CMS/OSS</asp:Content>

<asp:Content ContentPlaceHolderID="MainContent" runat="server">

<div class="vs-page">

    <div class="vs-head">
        <div>
            <h1>Voucher status</h1>
            <p>Live inventory across
               <asp:Literal ID="litProviderCount" runat="server" Text="0" /> providers and
               <asp:Literal ID="litProductCount" runat="server" Text="0" /> products</p>
        </div>
        <div class="vs-acts">
            <asp:HyperLink ID="lnkProductPerf" runat="server" CssClass="vs-btn" Visible="false">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9"
                     stroke-linecap="round" width="16" height="16"><path d="M3 3v18h18M7 15l4-5 3 3 5-7" /></svg>
                Product wise Performance
            </asp:HyperLink>
            <asp:HyperLink ID="lnkStudentPerf" runat="server" CssClass="vs-btn solid" Visible="false">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.9"
                     stroke-linecap="round" width="16" height="16"><path d="M16 11a4 4 0 10-8 0M4 20a8 8 0 0116 0" /></svg>
                Student wise Performance
            </asp:HyperLink>
        </div>
    </div>

<asp:Panel ID="pnlFilters" runat="server" CssClass="vs-stack">

    <%-- ---------------- KPI cards ---------------- --%>
    <div class="vs-kpis">
        <div class="vs-kpi">
            <div class="top">
                <span class="lab">Total vouchers</span>
                <span class="ic" style="background: var(--brand-soft); color: var(--brand);">
                    <svg viewBox="0 0 24 24"><path d="M4 6h16v4a2 2 0 000 4v4H4v-4a2 2 0 000-4zM10 6v12" /></svg>
                </span>
            </div>
            <div class="val vs-num"><asp:Literal ID="litKpiTotal" runat="server" Text="0" /></div>
            <div class="sub"><asp:Literal ID="litKpiTrend" runat="server" /></div>
        </div>

        <div class="vs-kpi">
            <div class="top">
                <span class="lab">Used</span>
                <span class="ic" style="background: var(--st-used-bg); color: var(--st-used);">
                    <svg viewBox="0 0 24 24"><path d="M20 6L9 17l-5-5" /></svg>
                </span>
            </div>
            <div class="val vs-num" style="color: var(--st-used);"><asp:Literal ID="litKpiUsed" runat="server" Text="0" /></div>
            <div class="sub"><b><asp:Literal ID="litKpiUsedPct" runat="server" Text="0%" /></b> of inventory redeemed</div>
        </div>

        <div class="vs-kpi">
            <div class="top">
                <span class="lab">Unused</span>
                <span class="ic" style="background: var(--st-unused-bg); color: var(--st-unused);">
                    <svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 3" /></svg>
                </span>
            </div>
            <div class="val vs-num" style="color: var(--st-unused);"><asp:Literal ID="litKpiUnused" runat="server" Text="0" /></div>
            <div class="sub"><b><asp:Literal ID="litKpiUnusedPct" runat="server" Text="0%" /></b> ready to allocate</div>
        </div>

        <div class="vs-kpi">
            <div class="top">
                <span class="lab">Expiring soon</span>
                <span class="ic" style="background: var(--st-expired-bg); color: var(--st-expired);">
                    <svg viewBox="0 0 24 24"><path d="M12 9v4M12 17h.01M10.3 3.9L2 18a2 2 0 002 3h16a2 2 0 002-3L13.7 3.9a2 2 0 00-3.4 0z" /></svg>
                </span>
            </div>
            <div class="val vs-num" style="color: var(--st-expired);"><asp:Literal ID="litKpiExpiring" runat="server" Text="0" /></div>
            <div class="sub"><span class="vs-down">within 30 days</span></div>
        </div>

        <div class="vs-kpi">
            <div class="top">
                <span class="lab">Invalid</span>
                <span class="ic" style="background: var(--st-invalid-bg); color: var(--st-invalid);">
                    <svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" /><path d="M15 9l-6 6M9 9l6 6" /></svg>
                </span>
            </div>
            <div class="val vs-num" style="color: var(--st-invalid);"><asp:Literal ID="litKpiInvalid" runat="server" Text="0" /></div>
            <div class="sub">flagged for review</div>
        </div>
    </div>

    <%-- ---------------- Filters ---------------- --%>
    <div class="vs-panel vs-filters">
        <div class="vs-frow">
            <span class="vs-flab">Status</span>
            <div class="vs-chips">
                <asp:Repeater ID="rptStatus" runat="server" OnItemCommand="rptStatus_ItemCommand">
                    <ItemTemplate>
                        <asp:LinkButton runat="server" CommandName="PickStatus"
                            CommandArgument='<%# Eval("Value") %>'
                            CssClass='<%# StatusPillClass(Eval("Value")) %>'
                            CausesValidation="false">
                            <span class="pip" style='<%# StatusPipStyle(Eval("Value")) %>'></span><%# Eval("Text") %>
                        </asp:LinkButton>
                    </ItemTemplate>
                </asp:Repeater>

                <span class="vs-divider"></span>

                <asp:LinkButton ID="lnkEarlyExpiry" runat="server" CssClass="vs-chip"
                    OnClick="lnkEarlyExpiry_Click" CausesValidation="false"
                    ToolTip="Show vouchers lapsing within a chosen window">
                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
                         width="14" height="14"><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 3" /></svg>
                    View Early Expiry
                </asp:LinkButton>
            </div>
        </div>

        <asp:Panel ID="pnlWindows" runat="server" Visible="false" CssClass="vs-frow">
            <span class="vs-flab">Window</span>
            <div class="vs-chips">
                <asp:Repeater ID="rptWindows" runat="server" OnItemCommand="rptWindows_ItemCommand">
                    <ItemTemplate>
                        <asp:LinkButton runat="server" CommandName="PickDays"
                            CommandArgument='<%# Eval("Value") %>'
                            CssClass='<%# WindowPillClass(Eval("Value")) %>'
                            Text='<%# Eval("Text") %>' CausesValidation="false" />
                    </ItemTemplate>
                </asp:Repeater>
            </div>
        </asp:Panel>

        <div class="vs-frow">
            <span class="vs-flab">Category</span>
            <div class="vs-chips">
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
    </div>

</asp:Panel>

<asp:Panel ID="pnlProviderGrid" runat="server">

    <%-- ---------------- Provider table ---------------- --%>
    <div class="vs-panel">
        <div class="vs-tablewrap">
            <table>
                <thead>
                    <tr>
                        <th style="width: 60px;">S.No</th>
                        <th>Provider</th>
                        <th class="c" style="width: 90px;"><asp:Literal ID="litCountHead" runat="server" Text="All" /></th>
                        <th style="width: 250px;">Status distribution</th>
                        <th class="r" style="width: 240px;">Actions</th>
                    </tr>
                </thead>
                <tbody>
                    <asp:Repeater ID="rptSummary" runat="server" OnItemCommand="rptSummary_ItemCommand">
                        <ItemTemplate>
                            <tr>
                                <td class="vs-sn"><%# string.Format("{0:00}", Container.ItemIndex + 1 + RowOffset) %></td>
                                <td>
                                    <div class="vs-prov">
                                        <%# ProviderTile(Eval("Id"), Eval("Name")) %>
                                        <span class="nm">
                                            <asp:LinkButton runat="server" CommandName="ToggleProducts"
                                                CommandArgument='<%# Eval("Id") %>' CausesValidation="false"
                                                ToolTip="Show products" style="text-decoration:none;">
                                                <b><%# Server.HtmlEncode(Convert.ToString(Eval("Name"))) %></b>
                                                <span class="sub">
                                                    <span class='<%# CaretClass(Eval("Id")) %>'>&#9656;</span>
                                                    <%# Eval("ProductCount") %> products
                                                </span>
                                            </asp:LinkButton>
                                        </span>
                                    </div>

                                    <asp:PlaceHolder runat="server" Visible='<%# IsExpanded(Eval("Id")) %>'>
                                        <div class="vs-prodlist"><%# ProductLinks(Eval("Id"), Eval("ProductNames"), Eval("ProductIds"), Eval("ProductCounts")) %></div>
                                    </asp:PlaceHolder>
                                </td>
                                <td class="c"><span class="vs-total vs-num"><%# Eval("StatusCount") %></span></td>
                                <td><%# DistributionCell(Container.DataItem) %></td>
                                <td>
                                    <div class="vs-rowacts">
                                        <a class="vs-mini solid" href='<%# ViewDataUrl(Eval("Id")) %>'>
                                            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" width="14" height="14"><path d="M1 12s4-7 11-7 11 7 11 7-4 7-11 7S1 12 1 12z" /><circle cx="12" cy="12" r="3" /></svg>
                                            View Data</a>
                                        <asp:HyperLink runat="server" CssClass="vs-mini"
                                            NavigateUrl='<%# ManageProductUrl(Eval("Id")) %>'
                                            Visible='<%# CanManageProduct %>' Text="Manage Product" />
                                    </div>
                                </td>
                            </tr>
                        </ItemTemplate>
                    </asp:Repeater>
                    <asp:PlaceHolder ID="phEmpty" runat="server" Visible="false">
                        <tr><td colspan="5" class="vs-empty">No data to show yet.</td></tr>
                    </asp:PlaceHolder>
                </tbody>
            </table>
        </div>

        <asp:PlaceHolder ID="phPager" runat="server" Visible="false">
            <div class="vs-tfoot">
                <span><asp:Literal ID="litPageInfo" runat="server" /></span>
                <div class="vs-pager">
                    <asp:LinkButton ID="lnkPrev" runat="server" CssClass="vs-pg" OnClick="lnkPrev_Click"
                        CausesValidation="false">&lsaquo;</asp:LinkButton>
                    <asp:Repeater ID="rptPager" runat="server" OnItemCommand="rptPager_ItemCommand">
                        <ItemTemplate>
                            <asp:LinkButton runat="server" CommandName="Go"
                                CommandArgument='<%# Eval("Index") %>'
                                CssClass='<%# PagerClass(Eval("CssClass")) %>'
                                Text='<%# Eval("Label") %>' CausesValidation="false" />
                        </ItemTemplate>
                    </asp:Repeater>
                    <asp:LinkButton ID="lnkNext" runat="server" CssClass="vs-pg" OnClick="lnkNext_Click"
                        CausesValidation="false">&rsaquo;</asp:LinkButton>
                </div>
            </div>
        </asp:PlaceHolder>
    </div>

</asp:Panel>

    <%-- ---------------- Student's own performance ---------------- --%>
    <asp:Panel ID="pnlPerformance" runat="server" Visible="false">
        <div class="vs-panel">
            <div class="vs-tablewrap">
                <table>
                    <thead>
                        <tr>
                            <th style="width: 60px;">S.No</th>
                            <th>Provider</th>
                            <th class="c" style="width: 130px;">Today</th>
                            <th class="c" style="width: 130px;">Weekly</th>
                            <th class="c" style="width: 130px;">Monthly</th>
                            <th class="r" style="width: 160px;">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        <asp:Repeater ID="rptPerformance" runat="server">
                            <ItemTemplate>
                                <tr>
                                    <td class="vs-sn"><%# string.Format("{0:00}", Container.ItemIndex + 1) %></td>
                                    <td><b><%# Server.HtmlEncode(Convert.ToString(Eval("ProviderName"))) %></b></td>
                                    <td class="c vs-num"><%# Eval("Today") %></td>
                                    <td class="c vs-num"><%# Eval("Weekly") %></td>
                                    <td class="c vs-num"><%# Eval("Monthly") %></td>
                                    <td>
                                        <div class="vs-rowacts">
                                            <a class="vs-mini solid" href='<%# ViewDataUrl(Eval("Id")) %>'>View Data</a>
                                        </div>
                                    </td>
                                </tr>
                            </ItemTemplate>
                        </asp:Repeater>
                        <asp:PlaceHolder ID="phPerfEmpty" runat="server" Visible="false">
                            <tr><td colspan="6" class="vs-empty">No data to show yet.</td></tr>
                        </asp:PlaceHolder>
                    </tbody>
                </table>
            </div>
        </div>
    </asp:Panel>

</div>

</asp:Content>
