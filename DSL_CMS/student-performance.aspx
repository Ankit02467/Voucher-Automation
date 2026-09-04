<%@ Page Language="C#" AutoEventWireup="true" MasterPageFile="~/MasterPage.master"
    CodeBehind="student-performance.aspx.cs" Inherits="DSL_CMS.student_performance" %>

<asp:Content ContentPlaceHolderID="TitleContent" runat="server">Student Performance - DSL CMS/OSS</asp:Content>

<asp:Content ContentPlaceHolderID="MainContent" runat="server">

<%-- The student's own Voucher Status screen, read from above: same panel, same
     head row, same counts. The two are read against each other - an admin
     checking a figure a student has queried - and two tables that answer the
     same question should not look like two different products. --%>
<div class="vs-page">

    <div class="vs-head">
        <div class="vs-headline">
            <a class="btn-back" href='<%= ResolveUrl("~/voucher-status.aspx") %>'
               title="Back to Voucher Status">&#8592; Back</a>
            <h1>Student wise Performance</h1>
        </div>
    </div>

    <asp:Panel ID="pnlDenied" runat="server" Visible="false" CssClass="msg msg-bad">
        This screen is available to Voucher Admin and Voucher Sub Admin only.
    </asp:Panel>

    <asp:Panel ID="pnlBody" runat="server">

        <%-- Everything below, added up. It was a row of the table and is a band
             of its own now: a total is not one more student, and reading it as
             the first row meant the eye had to stop and work out that this one
             was different. Out here it is the headline the screen is opened for,
             and the table underneath is a list again.

             Each figure stands in the width of the column it totals, so the
             eye reads it straight down instead of matching it up by its label.
             That only holds because the columns below are pinned - the colgroup
             and table-layout: fixed. Change a width there and the same width
             has to change in .sp-sum-figs, or the band drifts off its column.

             Weekly and Monthly are not totalled. They are the other question -
             work got through over a week and a month, not what is in hand this
             minute - and one number over every student for two overlapping
             windows answers nothing anybody asked. The band stops two columns
             short of the table's right edge rather than filling them, which is
             what the padding on .sp-sum-figs is for.

             The wrapper is not a spare div. Below the table's min-width the
             columns scroll, and a band that cannot scroll would sit still
             while the thing it is lined up with slid out from under it. Same
             min-width, same starting edge, its own scroller. --%>
        <div class="sp-sumwrap">
            <div class="sp-sum">
                <div class="sp-sum-lab">
                    <span class="ic">
                        <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"
                             stroke-linecap="round" stroke-linejoin="round" width="18" height="18">
                            <path d="M3 6h18M3 12h18M3 18h12" /></svg>
                    </span>
                    <span class="tx">
                        <b>Total Provider</b>
                        <small>Every Student, Every Provider</small>
                    </span>
                </div>
                <%-- .fig is the column and .box is the chip inside it: the column
                     has to be exactly the table's width, and a chip that wide would
                     leave the three of them touching. --%>
                <div class="sp-sum-figs">
                    <div class="fig">
                        <span class="box">
                            <span class="v vs-num"><asp:Literal ID="litTotalAll" runat="server" Text="0" /></span>
                            <span class="k">Today All</span>
                        </span>
                    </div>
                    <div class="fig done">
                        <span class="box">
                            <span class="v vs-num"><asp:Literal ID="litTotalChecked" runat="server" Text="0" /></span>
                            <span class="k">Checked</span>
                        </span>
                    </div>
                    <div class="fig todo">
                        <span class="box">
                            <span class="v vs-num"><asp:Literal ID="litTotalPending" runat="server" Text="0" /></span>
                            <span class="k">Pending</span>
                        </span>
                    </div>
                </div>
            </div>
        </div>

        <div class="vs-panel">
            <div class="vs-tablewrap">
                <table class="sp-table">
                    <%-- Every column sorts. S.No is a row number rather than a
                         field, so it does not - the rule the other two tables
                         follow.

                         Each heading's label is a Literal rather than loose
                         text: a LinkButton handed text alongside a child control
                         swallows that text into its own Text property while the
                         page is parsed, and the heading then comes back empty on
                         the first postback. --%>
                    <%-- The geometry lives here rather than on the headings,
                         and it is fixed rather than left to the content,
                         because the band above lines its figures up with these
                         columns. Auto layout hands the slack to whichever
                         column asks loudest, so a long provider name moves the
                         numbers - and the band cannot follow that.

                         Change a width here and change .sp-sum-figs with it. --%>
                    <colgroup>
                        <col style="width: 64px;" />
                        <col style="width: 180px;" />
                        <col />
                        <col style="width: 126px;" />
                        <col style="width: 126px;" />
                        <col style="width: 126px;" />
                        <col style="width: 126px;" />
                        <col style="width: 126px;" />
                    </colgroup>
                    <thead>
                        <tr>
                            <th>S.No</th>
                            <th>
                                <asp:LinkButton ID="lnkSortStudent" runat="server" CssClass="vs-sortcol"
                                    OnCommand="sort_Command" CommandArgument="StudentName"
                                    CausesValidation="false"><asp:Literal runat="server" Text="Student Name" /><asp:Literal ID="litSortStudent" runat="server" /></asp:LinkButton>
                            </th>
                            <th>
                                <asp:LinkButton ID="lnkSortProvider" runat="server" CssClass="vs-sortcol"
                                    OnCommand="sort_Command" CommandArgument="ProviderName"
                                    CausesValidation="false"><asp:Literal runat="server" Text="Provider" /><asp:Literal ID="litSortProvider" runat="server" /></asp:LinkButton>
                            </th>
                            <th class="c">
                                <asp:LinkButton ID="lnkSortAll" runat="server" CssClass="vs-sortcol"
                                    OnCommand="sort_Command" CommandArgument="AllCount"
                                    CausesValidation="false"><asp:Literal runat="server" Text="Today All" /><asp:Literal ID="litSortAll" runat="server" /></asp:LinkButton>
                            </th>
                            <th class="c">
                                <asp:LinkButton ID="lnkSortChecked" runat="server" CssClass="vs-sortcol"
                                    OnCommand="sort_Command" CommandArgument="CheckedCount"
                                    CausesValidation="false"><asp:Literal runat="server" Text="Checked" /><asp:Literal ID="litSortChecked" runat="server" /></asp:LinkButton>
                            </th>
                            <th class="c">
                                <asp:LinkButton ID="lnkSortPending" runat="server" CssClass="vs-sortcol"
                                    OnCommand="sort_Command" CommandArgument="PendingCount"
                                    CausesValidation="false"><asp:Literal runat="server" Text="Pending" /><asp:Literal ID="litSortPending" runat="server" /></asp:LinkButton>
                            </th>
                            <th class="c">
                                <asp:LinkButton ID="lnkSortWeekly" runat="server" CssClass="vs-sortcol"
                                    OnCommand="sort_Command" CommandArgument="Weekly"
                                    CausesValidation="false"><asp:Literal runat="server" Text="Weekly" /><asp:Literal ID="litSortWeekly" runat="server" /></asp:LinkButton>
                            </th>
                            <th class="c">
                                <asp:LinkButton ID="lnkSortMonthly" runat="server" CssClass="vs-sortcol"
                                    OnCommand="sort_Command" CommandArgument="Monthly"
                                    CausesValidation="false"><asp:Literal runat="server" Text="Monthly" /><asp:Literal ID="litSortMonthly" runat="server" /></asp:LinkButton>
                            </th>
                        </tr>
                    </thead>
                    <tbody>
                        <asp:Repeater ID="rptPerformance" runat="server" OnItemCommand="rptPerformance_ItemCommand">
                            <ItemTemplate>
                                <tr class='<%# RowClass(Eval("Key")) %>'>
                                    <td class="vs-sn vs-num"><%# Container.ItemIndex + 1 %></td>
                                    <td><%# StudentCell(Eval("StudentId"), Eval("StudentName")) %></td>
                                    <td>
                                        <%-- The whole block is the toggle, the way the
                                             provider table on Voucher Status has it.
                                             Nothing here opens a screen: this one
                                             answers "who has what" and is not a way
                                             through to anywhere, so there is one thing
                                             to aim at and it does the one thing. --%>
                                        <div class="vs-prov">
                                            <asp:LinkButton runat="server" CommandName="ToggleProducts"
                                                CommandArgument='<%# Eval("Key") %>' CausesValidation="false"
                                                CssClass="vs-provtoggle" ToolTip="Show the products held">
                                                <span class='<%# CaretClass(Eval("Key")) %>'>
                                                    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor"
                                                         stroke-width="2.8" stroke-linecap="round" stroke-linejoin="round"
                                                         width="15" height="15"><path d="M9 6l6 6-6 6" /></svg>
                                                </span>
                                                <%# ProviderTile(Eval("ProviderId"), Eval("ProviderName")) %>
                                                <span class="nm">
                                                    <b><%# Server.HtmlEncode(Convert.ToString(Eval("ProviderName"))) %></b>
                                                    <small><%# ProductLabel(Eval("ProductCount")) %></small>
                                                </span>
                                            </asp:LinkButton>
                                        </div>
                                    </td>
                                    <td class="c"><span class="vs-total vs-num"><%# Eval("AllCount") %></span></td>
                                    <td class="c"><span class="vs-num vs-done"><%# Eval("CheckedCount") %></span></td>
                                    <td class="c"><span class="vs-num vs-todo"><%# Eval("PendingCount") %></span></td>
                                    <td class="c vs-num"><%# Eval("Weekly") %></td>
                                    <td class="c vs-num"><%# Eval("Monthly") %></td>
                                </tr>
                                <%# ProductRows(Eval("Key"), Eval("ProductNames"), Eval("ProductAll"),
                                                Eval("ProductChecked"), Eval("ProductPending")) %>
                            </ItemTemplate>
                        </asp:Repeater>

                        <asp:PlaceHolder ID="phEmpty" runat="server" Visible="false">
                            <tr><td colspan="8" class="vs-empty">No student is holding any vouchers just now.</td></tr>
                        </asp:PlaceHolder>
                    </tbody>
                </table>
            </div>
        </div>
    </asp:Panel>

</div>

</asp:Content>
