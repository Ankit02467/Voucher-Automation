<%@ Page Language="C#" AutoEventWireup="true" MasterPageFile="~/MasterPage.master"
    CodeBehind="voucher-status.aspx.cs" Inherits="DSL_CMS.voucher_status" %>

<asp:Content ContentPlaceHolderID="TitleContent" runat="server">Voucher Status - DSL CMS/OSS</asp:Content>

<asp:Content ContentPlaceHolderID="MainContent" runat="server">

<div class="vs-page">

    <div class="vs-head">
        <h1>Voucher status</h1>
    </div>

    <asp:Panel ID="pnlDenied" runat="server" Visible="false" CssClass="msg msg-bad">
        No Voucher role is mapped to your user, so the voucher module is not
        available. Ask an administrator to map your account to one of the four
        Voucher roles.
    </asp:Panel>

<asp:Panel ID="pnlFilters" runat="server" CssClass="vs-stack">

    <%-- ---------------- KPI cards ----------------
         Each one is a LinkButton, not a div: every card lands on the rows it
         counted, so it has to be something you can click. --%>
    <div class="vs-kpis">
        <asp:LinkButton ID="kpiTotal" runat="server" CssClass="vs-kpi k-total"
            OnCommand="kpi_Command" CommandArgument="All" CausesValidation="false">
            <span class="top">
                <span class="lab">Total vouchers</span>
                <span class="ic"><svg viewBox="0 0 24 24"><path d="M4 6h16v4a2 2 0 000 4v4H4v-4a2 2 0 000-4zM10 6v12" /></svg></span>
            </span>
            <span class="val vs-num"><asp:Literal ID="litKpiTotal" runat="server" Text="0" /></span>
            <span class="sub"><asp:Literal ID="litKpiTrend" runat="server" /></span>
            <span class="go"><svg viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6" /></svg></span>
        </asp:LinkButton>

        <asp:LinkButton ID="kpiUsed" runat="server" CssClass="vs-kpi k-used"
            OnCommand="kpi_Command" CommandArgument="Used" CausesValidation="false">
            <span class="top">
                <span class="lab">Used</span>
                <span class="ic"><svg viewBox="0 0 24 24"><path d="M20 6L9 17l-5-5" /></svg></span>
            </span>
            <span class="val vs-num"><asp:Literal ID="litKpiUsed" runat="server" Text="0" /></span>
            <span class="sub"><b><asp:Literal ID="litKpiUsedPct" runat="server" Text="0%" /></b> redeemed</span>
            <span class="go"><svg viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6" /></svg></span>
        </asp:LinkButton>

        <asp:LinkButton ID="kpiUnused" runat="server" CssClass="vs-kpi k-unused"
            OnCommand="kpi_Command" CommandArgument="Unused" CausesValidation="false">
            <span class="top">
                <span class="lab">Unused</span>
                <span class="ic"><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 3" /></svg></span>
            </span>
            <span class="val vs-num"><asp:Literal ID="litKpiUnused" runat="server" Text="0" /></span>
            <span class="sub"><b><asp:Literal ID="litKpiUnusedPct" runat="server" Text="0%" /></b> ready to allocate</span>
            <span class="go"><svg viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6" /></svg></span>
        </asp:LinkButton>

        <asp:LinkButton ID="kpiExpiring" runat="server" CssClass="vs-kpi k-expiring"
            OnCommand="kpi_Command" CommandArgument="Expiring" CausesValidation="false">
            <span class="top">
                <span class="lab">Expiring soon</span>
                <span class="ic"><svg viewBox="0 0 24 24"><path d="M12 9v4M12 17h.01M10.3 3.9L2 18a2 2 0 002 3h16a2 2 0 002-3L13.7 3.9a2 2 0 00-3.4 0z" /></svg></span>
            </span>
            <span class="val vs-num"><asp:Literal ID="litKpiExpiring" runat="server" Text="0" /></span>
            <span class="sub">within 30 days</span>
            <span class="go"><svg viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6" /></svg></span>
        </asp:LinkButton>

        <asp:LinkButton ID="kpiInvalid" runat="server" CssClass="vs-kpi k-invalid"
            OnCommand="kpi_Command" CommandArgument="Invalid" CausesValidation="false">
            <span class="top">
                <span class="lab">Invalid</span>
                <span class="ic"><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" /><path d="M15 9l-6 6M9 9l6 6" /></svg></span>
            </span>
            <span class="val vs-num"><asp:Literal ID="litKpiInvalid" runat="server" Text="0" /></span>
            <span class="sub">flagged for review</span>
            <span class="go"><svg viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6" /></svg></span>
        </asp:LinkButton>

        <%-- Fresh uploads nobody has triaged yet - Status IS NULL. The proc has
             always counted these; only the card was missing, so the one status
             that most needs chasing was the one with no figure on the page. --%>
        <asp:LinkButton ID="kpiNotSet" runat="server" CssClass="vs-kpi k-notset"
            OnCommand="kpi_Command" CommandArgument="NotSet" CausesValidation="false">
            <span class="top">
                <span class="lab">Not set</span>
                <span class="ic"><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" /><path d="M12 8v4M12 16h.01" /></svg></span>
            </span>
            <span class="val vs-num"><asp:Literal ID="litKpiNotSet" runat="server" Text="0" /></span>
            <span class="sub">not triaged yet</span>
            <span class="go"><svg viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6" /></svg></span>
        </asp:LinkButton>
    </div>

    <%-- ---------------- Filters ----------------
         Category is not here any more - the sidebar owns it. What is left is
         the one row the design asks for, with early expiry pushed to the end
         because it replaces the status rather than narrowing it. --%>
    <div class="vs-panel vs-filters">
        <div class="vs-frow">
            <span class="vs-flab">Status</span>
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

            <asp:Literal ID="litCategoryNote" runat="server" />

            <asp:LinkButton ID="lnkEarlyExpiry" runat="server" CssClass="vs-chip ghost"
                OnClick="lnkEarlyExpiry_Click" CausesValidation="false"
                ToolTip="Show vouchers lapsing within a chosen window">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
                     width="14" height="14"><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 3" /></svg>
                View Early Expiry
            </asp:LinkButton>
        </div>

        <asp:Panel ID="pnlWindows" runat="server" Visible="false" CssClass="vs-frow">
            <span class="vs-flab">Window</span>
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

</asp:Panel>

<asp:Panel ID="pnlProviderGrid" runat="server">

    <%-- ---------------- Provider table ---------------- --%>
    <div class="vs-panel">
        <div class="vs-tablewrap">
            <table>
                <thead>
                    <tr>
                        <th style="width: 64px;">S.No</th>
                        <%-- Provider and the count both sort. The heading itself is
                             the control, so there is nothing extra to aim at. --%>
                        <%-- The spare width of the table goes to Actions, not here -
                             see that column below. This one used to take it, which
                             carried the count all the way over to the buttons, a long
                             way from the provider it counts. The floor keeps a short
                             gap after the name; it is a floor rather than a set width
                             so a longer provider name widens the column instead of
                             being cut off. --%>
                        <th style="min-width: 420px;">
                            <%-- The label is a Literal, not bare text. A LinkButton
                                 that is handed loose text alongside a child control
                                 pulls that text into its Text property during
                                 parsing, and the heading came back EMPTY on every
                                 postback - which is what made the Provider column
                                 look like it had disappeared. The count heading
                                 beside it was never affected because it was already
                                 built out of controls only. --%>
                            <asp:LinkButton ID="lnkSortName" runat="server" CssClass="vs-sortcol"
                                OnCommand="sort_Command" CommandArgument="Name"
                                CausesValidation="false"><asp:Literal ID="litNameHead" runat="server" Text="Provider" /><asp:Literal ID="litSortName" runat="server" /></asp:LinkButton>
                        </th>
                        <th class="c" style="width: 140px;">
                            <asp:LinkButton ID="lnkSortCount" runat="server" CssClass="vs-sortcol"
                                OnCommand="sort_Command" CommandArgument="StatusCount"
                                CausesValidation="false"><asp:Literal ID="litCountHead" runat="server" Text="All" /><asp:Literal ID="litSortCount" runat="server" /></asp:LinkButton>
                        </th>
                        <th class="r" style="width: 100%; min-width: 250px;">Actions</th>
                    </tr>
                </thead>
                <tbody>
                    <asp:Repeater ID="rptSummary" runat="server" OnItemCommand="rptSummary_ItemCommand">
                        <ItemTemplate>
                            <%-- the anchor the Back link on the other screens returns to --%>
                            <tr id='<%# "prov-" + Eval("Id") %>' class='<%# RowClass(Eval("Id")) %>'>
                                <td class="vs-sn vs-num"><%# string.Format("{0:00}", Container.ItemIndex + 1 + RowOffset) %></td>
                                <td>
                                    <div class="vs-prov">
                                        <asp:LinkButton runat="server" CommandName="ToggleProducts"
                                            CommandArgument='<%# Eval("Id") %>' CausesValidation="false"
                                            CssClass="vs-provtoggle" ToolTip="Show products">
                                            <%-- A chevron that turns, not a plus. The plus was tried here
                                                 and read worse against the provider logo beside it; the
                                                 sidebar keeps its own, which is a different control in a
                                                 different place. --%>
                                            <span class='<%# CaretClass(Eval("Id")) %>'>
                                                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"
                                                     stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"
                                                     width="15" height="15"><path d="M9 6l6 6-6 6" /></svg>
                                            </span>
                                            <%# ProviderTile(Eval("Id"), Eval("Name")) %>
                                            <span class="nm">
                                                <b><%# Server.HtmlEncode(Convert.ToString(Eval("Name"))) %></b>
                                                <small><%# Eval("ProductCount") %> products</small>
                                            </span>
                                        </asp:LinkButton>
                                    </div>
                                </td>
                                <td class="c"><span class="vs-total vs-num"><%# Eval("StatusCount") %></span></td>
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
                            <%-- Products of an opened provider, as rows of this same
                                 table. Emitted whole rather than templated because a
                                 nested Repeater cannot break out of its parent's
                                 <td> to line up with these columns. --%>
                            <%# ProductRows(Eval("Id"), Eval("ProductNames"), Eval("ProductIds"), Eval("ProductCounts")) %>
                        </ItemTemplate>
                    </asp:Repeater>
                    <asp:PlaceHolder ID="phEmpty" runat="server" Visible="false">
                        <tr><td colspan="4" class="vs-empty">No data to show yet.</td></tr>
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
                            <th style="width: 64px;">S.No</th>
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
                                    <td class="vs-sn vs-num"><%# string.Format("{0:00}", Container.ItemIndex + 1) %></td>
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
