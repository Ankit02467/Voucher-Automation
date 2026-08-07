<%@ Page Language="C#" AutoEventWireup="true" MasterPageFile="~/MasterPage.master"
    CodeBehind="manage-product.aspx.cs" Inherits="DSL_CMS.manage_product" %>

<asp:Content ContentPlaceHolderID="TitleContent" runat="server">Manage Product - DSL CMS/OSS</asp:Content>

<asp:Content ContentPlaceHolderID="MainContent" runat="server">

    <asp:Panel ID="pnlMsg" runat="server" Visible="false" CssClass="msg msg-ok">
        <asp:Literal ID="litMsg" runat="server" />
    </asp:Panel>

    <div class="card">
        <div class="card-head">
            <h2><asp:Literal ID="litFormTitle" runat="server" Text="Add Product" /></h2>
        </div>
        <div class="card-body">
            <asp:HiddenField ID="hfId" runat="server" Value="0" />
            <div class="form-grid">
                <div class="field">
                    <label>Provider *</label>
                    <asp:DropDownList ID="ddlProvider" runat="server" />
                </div>
                <div class="field">
                    <label>Product Name *</label>
                    <asp:TextBox ID="txtName" runat="server" placeholder="e.g. CompTIA A+ Voucher" />
                </div>
                <div class="field">
                    <label>Validity (Days)</label>
                    <asp:TextBox ID="txtValidityDays" runat="server" TextMode="Number" placeholder="365" />
                </div>
                <div class="field">
                    <label>Status</label>
                    <asp:DropDownList ID="ddlStatus" runat="server">
                        <asp:ListItem Text="Active"   Value="A" />
                        <asp:ListItem Text="Inactive" Value="I" />
                    </asp:DropDownList>
                </div>
                <div class="field">
                    <label>&nbsp;</label>
                    <div>
                        <asp:Button ID="btnSave" runat="server" CssClass="btn" Text="Save" OnClick="btnSave_Click" />
                        <asp:Button ID="btnCancel" runat="server" CssClass="btn btn-light" Text="Cancel"
                            OnClick="btnCancel_Click" CausesValidation="false" />
                    </div>
                </div>
            </div>
        </div>
    </div>

    <div class="card">
        <div class="card-head"><h2>Search</h2></div>
        <div class="card-body">
            <div class="filters">
                <div class="field">
                    <label>Provider</label>
                    <asp:DropDownList ID="ddlFilterProvider" runat="server" />
                </div>
                <div class="field">
                    <label>Search</label>
                    <asp:TextBox ID="txtSearch" runat="server" placeholder="Product or provider name" />
                </div>
                <div class="field">
                    <asp:Button ID="btnSearch" runat="server" CssClass="btn" Text="Search"
                        OnClick="btnSearch_Click" CausesValidation="false" />
                </div>
                <div class="field">
                    <asp:Button ID="btnReset" runat="server" CssClass="btn btn-light" Text="Reset"
                        OnClick="btnReset_Click" CausesValidation="false" />
                </div>
            </div>
        </div>
    </div>

    <div class="card">
        <div class="card-head">
            <h2>Product List (<asp:Literal ID="litCount" runat="server" Text="0" />)</h2>
        </div>
        <div class="grid-wrap">
            <asp:Repeater ID="rptProduct" runat="server" OnItemCommand="rptProduct_ItemCommand">
                <HeaderTemplate>
                    <table class="grid">
                        <thead>
                            <tr>
                                <th>#</th>
                                <th>Product Name</th>
                                <th>Provider</th>
                                <th>Validity (Days)</th>
                                <th>Vouchers</th>
                                <th>Status</th>
                                <th>Action</th>
                            </tr>
                        </thead>
                        <tbody>
                </HeaderTemplate>
                <ItemTemplate>
                    <tr>
                        <td><%# Container.ItemIndex + 1 %></td>
                        <td><strong><%# Eval("Name") %></strong></td>
                        <td><%# Eval("ProviderName") %></td>
                        <td><%# Eval("ValidityDays") %></td>
                        <td><%# Eval("VoucherCount") %></td>
                        <td>
                            <span class='<%# Convert.ToString(Eval("Status")) == "A" ? "pill pill-ok" : "pill pill-bad" %>'>
                                <%# Convert.ToString(Eval("Status")) == "A" ? "Active" : "Inactive" %>
                            </span>
                        </td>
                        <td>
                            <asp:LinkButton runat="server" CssClass="btn btn-light btn-sm" CommandName="EditRow"
                                CommandArgument='<%# Eval("Id") %>'>Edit</asp:LinkButton>
                        </td>
                    </tr>
                </ItemTemplate>
                <FooterTemplate>
                        </tbody>
                    </table>
                </FooterTemplate>
            </asp:Repeater>

            <asp:PlaceHolder ID="phEmpty" runat="server" Visible="false">
                <div style="padding: 30px; text-align: center; color: #64748b;">
                    No product found. Add one above or change the filters.
                </div>
            </asp:PlaceHolder>
        </div>
    </div>

</asp:Content>
