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
        <%-- Every voucher there is, whatever state it is in - the stock figure,
             and the one card here that is not a way in.

             It cannot be. Every other card presses the button of its own name,
             and on this screen a status is ALWAYS in force: each pill sets one
             and there is no "no status" state for a card meaning "all of them"
             to select. So it does not lift, carries no arrow and takes no
             pointer - a card that looks clickable and is not is worse than one
             that never offered.

             A div rather than a LinkButton, so there is nothing to click even
             for a keyboard or a screen reader, and no postback target for a
             forged one to aim at. --%>
        <div class="vs-kpi k-total is-flat">
            <span class="top">
                <span class="lab">Total vouchers</span>
                <span class="ic"><svg viewBox="0 0 24 24"><path d="M4 6h16v4a2 2 0 000 4v4H4v-4a2 2 0 000-4zM10 6v12" /></svg></span>
            </span>
            <span class="val vs-num"><asp:Literal ID="litKpiTotal" runat="server" Text="0" /></span>
            <span class="sub"><asp:Literal ID="litKpiTrend" runat="server" /></span>
        </div>

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
            <%-- Says what it counts, because it no longer counts everything: used,
                 expired and invalid vouchers are past chasing and are left out. --%>
            <span class="sub">unused &amp; not set, 30 days</span>
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
            <span class="sub">excludes expired</span>
            <span class="go"><svg viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6" /></svg></span>
        </asp:LinkButton>

        <%-- Past its date, whatever anybody typed against it - the same rule the
             Expired pill has always asked. It had a pill and no card, so the
             vouchers the other cards stopped counting had nowhere to be seen.
             Last in the row, well away from "Expiring soon": one is a warning
             about vouchers that can still be saved, this one is the ones that
             cannot, and side by side in the same amber they would read as a
             pair. --%>
        <asp:LinkButton ID="kpiExpired" runat="server" CssClass="vs-kpi k-expired"
            OnCommand="kpi_Command" CommandArgument="Expired" CausesValidation="false">
            <span class="top">
                <span class="lab">Expired</span>
                <span class="ic"><svg viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" /><path d="M12 7v5l3 3M5 5l14 14" /></svg></span>
            </span>
            <span class="val vs-num"><asp:Literal ID="litKpiExpired" runat="server" Text="0" /></span>
            <span class="sub">date already gone</span>
            <span class="go"><svg viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6" /></svg></span>
        </asp:LinkButton>

        <%-- The question View Data's "No dealer" pill asks, asked of the whole
             stock: nobody has written a dealer against the voucher, whatever its
             status. Admin and team only - ShowDealerCard, set in BindKpis and
             checked again in kpi_Command. Pressing it turns the provider column
             into the no-dealer figure, and View Data opens with the pill on.

             Shown and hidden through phNoDealer, never through the card's own
             Visible. A LinkButton whose content opens with markup and holds a
             server control empties itself when it reloads a view state of its
             own, and setting Visible gave it one: the card drew blank after the
             first click, and after every click from then on. The placeholder
             renders no tag, so the card is still a direct child of the grid. --%>
        <asp:PlaceHolder ID="phNoDealer" runat="server" Visible="false">
        <asp:LinkButton ID="kpiNoDealer" runat="server" CssClass="vs-kpi k-nodealer"
            OnCommand="kpi_Command" CommandArgument="NoDealer" CausesValidation="false">
            <span class="top">
                <span class="lab">No dealer</span>
                <span class="ic"><svg viewBox="0 0 24 24"><circle cx="9" cy="8" r="3.5" /><path d="M3 20c0-3.3 2.7-6 6-6s6 2.7 6 6M16 8l5 5M21 8l-5 5" /></svg></span>
            </span>
            <span class="val vs-num"><asp:Literal ID="litKpiNoDealer" runat="server" Text="0" /></span>
            <span class="sub">no dealer entered</span>
            <span class="go"><svg viewBox="0 0 24 24"><path d="M5 12h14M13 6l6 6-6 6" /></svg></span>
        </asp:LinkButton>
        </asp:PlaceHolder>
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
                ToolTip="Unused and not-set vouchers lapsing within a chosen window">
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
        <asp:Panel ID="pnlDragMsg" runat="server" Visible="false" CssClass="msg msg-bad">
            <asp:Literal ID="litDragMsg" runat="server" />
        </asp:Panel>
        <%-- Where a dragged list is posted from. The hidden field carries
             "providerId|id:place~..." and the button is what makes it a
             postback; neither is anything to look at, and only the admin's
             page renders rows that can fill them in. --%>
        <asp:HiddenField ID="hidOrder" runat="server" />
        <asp:LinkButton ID="lnkReorder" runat="server" OnClick="lnkReorder_Click"
            CausesValidation="false" CssClass="vs-hidden" />
        <div class="vs-tablewrap">
            <table id="provTable">
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

    <%-- ---------------- Student's own screen ----------------
         What they are holding, what they have done with it, and how much work
         the last week and month came to. There is no Actions column: the
         provider and the product are themselves the way through to the
         vouchers, which is one thing to aim at instead of two, and this is the
         one role whose rows all lead to the same place. --%>
    <asp:Panel ID="pnlPerformance" runat="server" Visible="false">
        <div class="vs-panel">
            <div class="vs-tablewrap">
                <table>
                    <%-- Every column sorts, the same way the provider table
                         above does. S.No is a row number rather than a field, so
                         it does not - the same rule the View Data grid follows.

                         Each heading's label is a Literal rather than loose
                         text: a LinkButton handed text alongside a child control
                         swallows that text into its own Text property while the
                         page is parsed, and the heading then comes back empty on
                         the first postback. --%>
                    <thead>
                        <tr>
                            <th style="width: 64px;">S.No</th>
                            <th style="min-width: 320px;">
                                <asp:LinkButton ID="lnkPerfName" runat="server" CssClass="vs-sortcol"
                                    OnCommand="perfSort_Command" CommandArgument="ProviderName"
                                    CausesValidation="false"><asp:Literal runat="server" Text="Provider" /><asp:Literal ID="litPerfName" runat="server" /></asp:LinkButton>
                            </th>
                            <th class="c" style="width: 120px;">
                                <asp:LinkButton ID="lnkPerfAll" runat="server" CssClass="vs-sortcol"
                                    OnCommand="perfSort_Command" CommandArgument="AllCount"
                                    CausesValidation="false"><asp:Literal runat="server" Text="Today All" /><asp:Literal ID="litPerfAll" runat="server" /></asp:LinkButton>
                            </th>
                            <th class="c" style="width: 120px;">
                                <asp:LinkButton ID="lnkPerfChecked" runat="server" CssClass="vs-sortcol"
                                    OnCommand="perfSort_Command" CommandArgument="CheckedCount"
                                    CausesValidation="false"><asp:Literal runat="server" Text="Checked" /><asp:Literal ID="litPerfChecked" runat="server" /></asp:LinkButton>
                            </th>
                            <th class="c" style="width: 120px;">
                                <asp:LinkButton ID="lnkPerfPending" runat="server" CssClass="vs-sortcol"
                                    OnCommand="perfSort_Command" CommandArgument="PendingCount"
                                    CausesValidation="false"><asp:Literal runat="server" Text="Pending" /><asp:Literal ID="litPerfPending" runat="server" /></asp:LinkButton>
                            </th>
                            <th class="c" style="width: 120px;">
                                <asp:LinkButton ID="lnkPerfWeekly" runat="server" CssClass="vs-sortcol"
                                    OnCommand="perfSort_Command" CommandArgument="Weekly"
                                    CausesValidation="false"><asp:Literal runat="server" Text="Weekly" /><asp:Literal ID="litPerfWeekly" runat="server" /></asp:LinkButton>
                            </th>
                            <th class="c" style="width: 120px;">
                                <asp:LinkButton ID="lnkPerfMonthly" runat="server" CssClass="vs-sortcol"
                                    OnCommand="perfSort_Command" CommandArgument="Monthly"
                                    CausesValidation="false"><asp:Literal runat="server" Text="Monthly" /><asp:Literal ID="litPerfMonthly" runat="server" /></asp:LinkButton>
                            </th>
                        </tr>
                    </thead>
                    <tbody>
                        <asp:Repeater ID="rptPerformance" runat="server" OnItemCommand="rptPerformance_ItemCommand">
                            <ItemTemplate>
                                <tr class='<%# RowClass(Eval("Id")) %>'>
                                    <td class="vs-sn vs-num"><%# string.Format("{0:00}", Container.ItemIndex + 1) %></td>
                                    <td>
                                        <%-- Two targets, not one. The chevron opens the
                                             products; the name opens the vouchers. The
                                             other table makes the whole thing a toggle
                                             because it has an Actions column to travel
                                             from, and this one does not. --%>
                                        <div class="vs-prov">
                                            <asp:LinkButton runat="server" CommandName="ToggleProducts"
                                                CommandArgument='<%# Eval("Id") %>' CausesValidation="false"
                                                CssClass="vs-carettoggle" ToolTip="Show products">
                                                <span class='<%# CaretClass(Eval("Id")) %>'>
                                                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"
                                                         stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"
                                                         width="15" height="15"><path d="M9 6l6 6-6 6" /></svg>
                                                </span>
                                            </asp:LinkButton>
                                            <a class="vs-provtoggle vs-golink" title="Open these vouchers"
                                               href='<%# ViewDataUrl(Eval("Id")) %>'>
                                                <%# ProviderTile(Eval("Id"), Eval("ProviderName")) %>
                                                <span class="nm">
                                                    <b><%# Server.HtmlEncode(Convert.ToString(Eval("ProviderName"))) %></b>
                                                    <small><%# ProductLabel(Eval("ProductCount")) %></small>
                                                </span>
                                            </a>
                                        </div>
                                    </td>
                                    <td class="c"><span class="vs-total vs-num"><%# Eval("AllCount") %></span></td>
                                    <td class="c"><span class="vs-num vs-done"><%# Eval("CheckedCount") %></span></td>
                                    <td class="c"><span class="vs-num vs-todo"><%# Eval("PendingCount") %></span></td>
                                    <td class="c vs-num"><%# Eval("Weekly") %></td>
                                    <td class="c vs-num"><%# Eval("Monthly") %></td>
                                </tr>
                                <%# PerfProductRows(Eval("Id"), Eval("ProductNames"), Eval("ProductIds"),
                                                    Eval("ProductAll"), Eval("ProductChecked"), Eval("ProductPending")) %>
                            </ItemTemplate>
                        </asp:Repeater>
                        <%-- Says which slice is empty rather than "no data": this
                             table only ever lists providers the student is holding
                             something of, so an empty one has a plain meaning. --%>
                        <asp:PlaceHolder ID="phPerfEmpty" runat="server" Visible="false">
                            <tr><td colspan="7" class="vs-empty">You are not holding any vouchers just now.</td></tr>
                        </asp:PlaceHolder>
                    </tbody>
                </table>
            </div>
        </div>
    </asp:Panel>

</div>

<%-- Dragging a product up or down its provider's list.

     Rows move in the page as the pointer passes them, so the list shows what
     it will become rather than only what it was; the postback happens once, on
     drop, and only if the order actually changed - a click that began a drag
     and went nowhere must not reload the screen.

     A drop into another provider's list is refused rather than corrected: the
     two lists are different questions and a product has no place in the wrong
     one. Moving a product between providers is Manage Product's job. --%>
<script type="text/javascript">
(function () {
    var table = document.getElementById('provTable');
    var field = document.getElementById('<%= hidOrder.ClientID %>');
    if (!table || !field) return;

    var dragged = null, wasBefore = '';

    // No closest(): this page is old enough to meet a browser without it, and
    // walking three parents costs nothing.
    function rowOf(node) {
        while (node && node !== table) {
            if (node.nodeType === 1 && node.getAttribute &&
                node.getAttribute('data-pid')) return node;
            node = node.parentNode;
        }
        return null;
    }

    function orderOf(provider) {
        var rows = table.querySelectorAll('tr.vs-drag[data-prov="' + provider + '"]');
        var parts = [];
        for (var i = 0; i < rows.length; i++)
            parts.push(rows[i].getAttribute('data-pid') + ':' + (i + 1));
        return parts.join('~');
    }

    table.addEventListener('dragstart', function (e) {
        var row = rowOf(e.target);
        if (!row) return;

        dragged = row;
        wasBefore = orderOf(row.getAttribute('data-prov'));
        row.className += ' dragging';
        if (e.dataTransfer) {
            e.dataTransfer.effectAllowed = 'move';
            // Firefox will not start a drag without something on the clipboard.
            try { e.dataTransfer.setData('text/plain', row.getAttribute('data-pid')); } catch (x) { }
        }
    });

    table.addEventListener('dragover', function (e) {
        if (!dragged) return;

        var over = rowOf(e.target);
        if (!over || over === dragged) return;
        if (over.getAttribute('data-prov') !== dragged.getAttribute('data-prov')) return;

        e.preventDefault();

        // Past the halfway line means below it - so a row can be dropped at the
        // very end of the list and not only above the last one.
        var box = over.getBoundingClientRect();
        var below = (e.clientY - box.top) > (box.height / 2);
        over.parentNode.insertBefore(dragged, below ? over.nextSibling : over);
    });

    table.addEventListener('drop', function (e) { e.preventDefault(); });

    table.addEventListener('dragend', function () {
        if (!dragged) return;

        dragged.className = dragged.className.replace(/ *dragging/, '');
        var provider = dragged.getAttribute('data-prov');
        dragged = null;

        var now = orderOf(provider);
        if (now === wasBefore) return;

        field.value = provider + '|' + now;
        __doPostBack('<%= lnkReorder.UniqueID %>', '');
    });
})();
</script>

</asp:Content>
