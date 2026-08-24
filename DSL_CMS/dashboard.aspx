<%@ Page Language="C#" AutoEventWireup="true" MasterPageFile="~/MasterPage.master"
    CodeBehind="dashboard.aspx.cs" Inherits="DSL_CMS.dashboard" %>

<asp:Content ContentPlaceHolderID="TitleContent" runat="server">Dashboard - DSL CMS/OSS</asp:Content>

<asp:Content ContentPlaceHolderID="MainContent" runat="server">

    <div class="tiles">
        <div class="tile">     <div class="k">Total Vouchers</div> <div class="v"><asp:Literal ID="litTotal"   runat="server" Text="0" /></div></div>
        <div class="tile ok">  <div class="k">Used</div>           <div class="v"><asp:Literal ID="litUsed"    runat="server" Text="0" /></div></div>
        <div class="tile warn"><div class="k">Unused</div>         <div class="v"><asp:Literal ID="litUnused"  runat="server" Text="0" /></div></div>
        <div class="tile bad"> <div class="k">Expired</div>        <div class="v"><asp:Literal ID="litExpired" runat="server" Text="0" /></div></div>
        <div class="tile">     <div class="k">Checked</div>        <div class="v"><asp:Literal ID="litChecked" runat="server" Text="0" /></div></div>
    </div>

    <div class="card">
        <div class="card-head"><h2>Voucher Module</h2></div>
        <div class="card-body">
            <p style="margin-top:0; color:#64748b;">Quick links for the voucher workflow.</p>
            <a class="btn" href="voucher-status.aspx">Voucher Status</a>
            <a class="btn" href="voucher-data.aspx">Voucher Data</a>
            <a class="btn btn-light" href="manage-product.aspx">Manage Product</a>
        </div>
    </div>

</asp:Content>
