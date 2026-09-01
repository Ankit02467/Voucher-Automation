<%@ Page Language="C#" AutoEventWireup="true" MasterPageFile="~/MasterPage.master"
    CodeBehind="add-provider.aspx.cs" Inherits="DSL_CMS.add_provider" %>

<asp:Content ContentPlaceHolderID="TitleContent" runat="server">Add Provider - DSL CMS/OSS</asp:Content>

<asp:Content ContentPlaceHolderID="MainContent" runat="server">

    <div class="toolbar">
        <a class="btn-back" href='<%= ResolveUrl("~/voucher-status.aspx") %>'
           title="Back to Voucher Status">&#8592; Back</a>
        <%-- The screen adds a product to a provider that already exists as well
             as making a new one, so the heading says both. Calling it "Add
             Provider" was why adding a product to AWS looked impossible from
             here. --%>
        <h1>Add Provider or Product</h1>
    </div>

    <asp:Panel ID="pnlDenied" runat="server" Visible="false" CssClass="msg msg-bad">
        Adding providers is available to Voucher Admin only.
    </asp:Panel>

    <asp:Panel ID="pnlBody" runat="server">

    <asp:Panel ID="pnlMsg" runat="server" Visible="false" CssClass="msg msg-ok">
        <asp:Literal ID="litMsg" runat="server" />
    </asp:Panel>

    <%-- ---------------- 1. the provider ----------------
         Two ways in, one screen. Making a provider and adding a product to one
         are the same job a step apart, and step two below is identical either
         way - it only ever needed a provider id. Sending the admin to a second
         screen to add a product to AWS would have been a second copy of
         everything under it. --%>
    <div class="card">
        <div class="card-head">
            <h2><asp:Literal ID="litStepOne" runat="server" Text="1. Provider details" /></h2>
            <asp:Panel ID="pnlMode" runat="server" CssClass="pill-row">
                <asp:LinkButton ID="lnkModeNew" runat="server" CssClass="pill-btn on"
                    OnClick="lnkModeNew_Click" CausesValidation="false"
                    ToolTip="Create a provider that is not here yet">New provider</asp:LinkButton>
                <asp:LinkButton ID="lnkModeExisting" runat="server" CssClass="pill-btn"
                    OnClick="lnkModeExisting_Click" CausesValidation="false"
                    ToolTip="Add a product to a provider that already exists">Existing provider</asp:LinkButton>
            </asp:Panel>
        </div>
        <div class="card-body">

        <%-- pick one that is already here, and its products open below --%>
        <asp:Panel ID="pnlPickProvider" runat="server" Visible="false">
            <%-- One field on its own, so it is capped rather than stretched the
                 width of the card the way a grid of four would be. --%>
            <div class="field" style="max-width: 420px;">
                <label>Provider *</label>
                <asp:DropDownList ID="ddlExistingProvider" runat="server" AutoPostBack="true"
                    OnSelectedIndexChanged="ddlExistingProvider_SelectedIndexChanged" />
            </div>
        </asp:Panel>

        <asp:Panel ID="pnlNewProvider" runat="server">
            <div class="form-grid">
                <div class="field">
                    <label>Provider Name *</label>
                    <asp:TextBox ID="txtName" runat="server" placeholder="e.g. CompTIA" />
                </div>
                <div class="field">
                    <label>Category</label>
                    <%-- The categories already in use, plus a way to start a new
                         one: without it the first provider of a category could
                         never be added, and on an empty database no provider
                         could be given a category at all. --%>
                    <asp:DropDownList ID="ddlCategory" runat="server" AutoPostBack="true"
                        OnSelectedIndexChanged="ddlCategory_SelectedIndexChanged" />
                    <asp:TextBox ID="txtNewCategory" runat="server" Visible="false"
                        placeholder="New category name" AutoCompleteType="Disabled" />
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
                        <asp:Button ID="btnSaveProvider" runat="server" CssClass="btn" Text="Save Provider"
                            OnClick="btnSaveProvider_Click" />
                        <asp:Button ID="btnStartOver" runat="server" CssClass="btn btn-light" Text="Add Another"
                            OnClick="btnStartOver_Click" CausesValidation="false" Visible="false" />
                    </div>
                </div>
            </div>
        </asp:Panel>

        </div>
    </div>

    <%-- ---------------- 2. its products ----------------
         Only after the provider exists: a product needs a ProviderId, and
         holding a list in memory to save later would lose it on any slip. --%>
    <asp:Panel ID="pnlProducts" runat="server" Visible="false">

        <div class="card">
            <div class="card-head">
                <h2>2. Products for <asp:Literal ID="litProviderName" runat="server" /></h2>
            </div>
            <div class="card-body">
                <div class="form-grid">
                    <div class="field">
                        <label>Product Name *</label>
                        <asp:TextBox ID="txtProductName" runat="server" placeholder="e.g. CompTIA A+ Voucher" />
                    </div>
                    <div class="field">
                        <label>Status</label>
                        <asp:DropDownList ID="ddlProductStatus" runat="server">
                            <asp:ListItem Text="Active"   Value="A" />
                            <asp:ListItem Text="Inactive" Value="I" />
                        </asp:DropDownList>
                    </div>
                    <div class="field">
                        <label>&nbsp;</label>
                        <div>
                            <asp:Button ID="btnAddProduct" runat="server" CssClass="btn" Text="Add Product"
                                OnClick="btnAddProduct_Click" />
                        </div>
                    </div>
                </div>
            </div>
        </div>

        <div class="card">
            <div class="card-head">
                <h2>Products added (<asp:Literal ID="litCount" runat="server" Text="0" />)</h2>
                <div>
                    <asp:HyperLink ID="lnkViewData" runat="server" CssClass="btn btn-light btn-sm"
                        Text="View Data" />
                    <asp:HyperLink ID="lnkManage" runat="server" CssClass="btn btn-sm"
                        Text="Manage Products" />
                </div>
            </div>
            <div class="grid-wrap">
                <asp:Repeater ID="rptProduct" runat="server">
                    <HeaderTemplate>
                        <table class="grid">
                            <thead>
                                <tr>
                                    <th>S.no</th>
                                    <th>Product Name</th>
                                    <th>Status</th>
                                </tr>
                            </thead>
                            <tbody>
                    </HeaderTemplate>
                    <ItemTemplate>
                        <tr>
                            <td><%# Container.ItemIndex + 1 %></td>
                            <td><strong><%# Server.HtmlEncode(Convert.ToString(Eval("Name"))) %></strong></td>
                            <td>
                                <span class='<%# Convert.ToString(Eval("Status")) == "A" ? "pill pill-ok" : "pill pill-bad" %>'>
                                    <%# Convert.ToString(Eval("Status")) == "A" ? "Active" : "Inactive" %>
                                </span>
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
                        No product yet. Add the first one above.
                    </div>
                </asp:PlaceHolder>
            </div>
        </div>

    </asp:Panel>

    </asp:Panel>

</asp:Content>
