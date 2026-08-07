<%@ Page Language="C#" AutoEventWireup="true" CodeBehind="login.aspx.cs" Inherits="DSL_CMS.login" %>

<!DOCTYPE html>
<html lang="en">
<head runat="server">
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1" />
    <title>DSL | Login Page</title>
    <link rel="stylesheet" href="<%= ResolveUrl("~/assets/css/login.css") %>?v=<%= AssetVersion %>" />
</head>
<body>
    <form id="form1" runat="server">
    <div class="login-page">
        <div class="login-card">

            <div class="card-top">
                <h1>Login Detail</h1>

                <asp:Panel ID="pnlMsg" runat="server" Visible="false" CssClass="login-msg">
                    <asp:Literal ID="litMsg" runat="server" />
                </asp:Panel>

                <div class="fld">
                    <span class="ico" aria-hidden="true">
                        <svg width="21" height="21" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                             stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                            <circle cx="12" cy="8" r="4" />
                            <path d="M4 21c0-4.4 3.6-7 8-7s8 2.6 8 7" />
                        </svg>
                    </span>
                    <asp:TextBox ID="txtEmail" runat="server" TextMode="Email" placeholder="Email" />
                </div>

                <div class="fld">
                    <span class="ico" aria-hidden="true">
                        <svg width="21" height="21" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                             stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                            <circle cx="7.5" cy="12" r="3.5" />
                            <path d="M11 12h10M17.5 12v3.5M20.5 12v2.5" />
                        </svg>
                    </span>
                    <asp:TextBox ID="txtPassword" runat="server" TextMode="Password" placeholder="Password" />
                    <button type="button" class="eye" id="btnEye" aria-label="Show password">
                        <svg width="21" height="21" viewBox="0 0 24 24" fill="none" stroke="currentColor"
                             stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round">
                            <path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7-10-7-10-7z" />
                            <circle cx="12" cy="12" r="3" />
                        </svg>
                    </button>
                </div>
            </div>

            <div class="card-bottom">
                <asp:Button ID="btnLogin" runat="server" CssClass="btn-signin" Text="Sign In" OnClick="btnLogin_Click" />
            </div>

        </div>
    </div>
    </form>

    <script type="text/javascript">
        (function () {
            var eye = document.getElementById('btnEye');
            var pwd = document.getElementById('<%= txtPassword.ClientID %>');
            if (!eye || !pwd) return;
            eye.addEventListener('click', function () {
                var show = pwd.type === 'password';
                pwd.type = show ? 'text' : 'password';
                eye.setAttribute('aria-label', show ? 'Hide password' : 'Show password');
            });
        })();
    </script>
</body>
</html>
