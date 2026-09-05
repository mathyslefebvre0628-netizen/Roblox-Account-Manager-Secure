$ErrorActionPreference = 'Stop'
$upstream = 'https://github.com/ic3w0lf22/Roblox-Account-Manager.git'
$work = Join-Path $env:RUNNER_TEMP 'roblox-account-manager-upstream'
if (Test-Path $work) { Remove-Item $work -Recurse -Force }
git clone --depth 1 --branch master $upstream $work

# Keep the legacy CefSharp dependency set internally consistent: the project references
# CefSharp.Common 109.1.110, while upstream packages.config currently lists 117.2.20.
# Pin Common to the version required by the project and its WinForms integration.
$packagesConfig = Join-Path $work 'RBX Alt Manager/packages.config'
if (Test-Path $packagesConfig) {
    $packagesText = Get-Content $packagesConfig -Raw
    $packagesText = $packagesText -replace '<package id="CefSharp.Common" version="117\.2\.20"', '<package id="CefSharp.Common" version="109.1.110"'
    Set-Content -LiteralPath $packagesConfig -Value $packagesText -Encoding UTF8
}

# Security hardening: replace the legacy WebServer implementation with a localhost-only,
# authenticated listener. The auth token is supplied at runtime via RAM_API_TOKEN.
$webServer = @'
using System;
using System.Net;
using System.Text;
using System.Threading;

namespace RBX_Alt_Manager
{
    public class WebServer
    {
        private readonly HttpListener _listener = new HttpListener();
        private readonly Func<HttpListenerContext, string> _responderMethod;
        private readonly string _token;
        private const int MaxResponseBytes = 1024 * 1024;

        public WebServer(string[] prefixes, Func<HttpListenerContext, string> method)
        {
            if (!HttpListener.IsSupported) throw new NotSupportedException("HttpListener is not supported.");
            if (prefixes == null || prefixes.Length == 0) throw new ArgumentException("prefixes");
            _responderMethod = method ?? throw new ArgumentNullException("method");
            _token = Environment.GetEnvironmentVariable("RAM_API_TOKEN");
            if (string.IsNullOrWhiteSpace(_token)) throw new InvalidOperationException("RAM_API_TOKEN must be configured.");

            foreach (var prefix in prefixes)
            {
                if (!Uri.TryCreate(prefix, UriKind.Absolute, out var uri) || !IPAddress.TryParse(uri.Host, out var ip) || !IPAddress.IsLoopback(ip))
                    throw new ArgumentException("Only loopback HTTP prefixes are permitted.", "prefixes");
                _listener.Prefixes.Add(prefix);
            }
            _listener.Start();
        }

        public WebServer(Func<HttpListenerContext, string> method, params string[] prefixes) : this(prefixes, method) { }

        private bool Authorized(HttpListenerContext ctx)
        {
            var supplied = ctx.Request.Headers["X-RAM-API-Token"];
            return !string.IsNullOrEmpty(supplied) && supplied.Length == _token.Length && CryptographicEquals(supplied, _token);
        }

        private static bool CryptographicEquals(string a, string b)
        {
            var aa = Encoding.UTF8.GetBytes(a);
            var bb = Encoding.UTF8.GetBytes(b);
            if (aa.Length != bb.Length) return false;
            var diff = 0;
            for (var i = 0; i < aa.Length; i++) diff |= aa[i] ^ bb[i];
            return diff == 0;
        }

        public void Run()
        {
            ThreadPool.QueueUserWorkItem((o) =>
            {
                try
                {
                    while (_listener.IsListening)
                    {
                        var ctx = _listener.GetContext();
                        ThreadPool.QueueUserWorkItem((c) => Handle((HttpListenerContext)c), ctx);
                    }
                }
                catch (HttpListenerException) { }
                catch (ObjectDisposedException) { }
            });
        }

        private void Handle(HttpListenerContext ctx)
        {
            try
            {
                if (!Authorized(ctx))
                {
                    ctx.Response.StatusCode = 401;
                    ctx.Response.Close();
                    return;
                }
                var result = _responderMethod(ctx) ?? string.Empty;
                var bytes = Encoding.UTF8.GetBytes(result);
                if (bytes.Length > MaxResponseBytes)
                {
                    ctx.Response.StatusCode = 413;
                    ctx.Response.Close();
                    return;
                }
                ctx.Response.ContentType = "text/plain; charset=utf-8";
                ctx.Response.ContentLength64 = bytes.Length;
                ctx.Response.OutputStream.Write(bytes, 0, bytes.Length);
            }
            catch (Exception ex)
            {
                Program.Logger.Error("WebServer request failed: " + ex.GetType().Name);
                try { ctx.Response.StatusCode = 500; } catch { }
            }
            finally { try { ctx.Response.Close(); } catch { } }
        }

        public void Stop() { _listener.Stop(); _listener.Close(); }
    }
}
'@
Set-Content -LiteralPath (Join-Path $work 'RBX Alt Manager/Classes/WebServer.cs') -Value $webServer -Encoding UTF8

# Harden WebSocket entry point: require a per-install token and validate numeric IDs.
$ws = @'
using RBX_Alt_Manager.Forms;
using System;
using System.Linq;
using System.Threading;
using WebSocketSharp;
using WebSocketSharp.Server;

namespace RBX_Alt_Manager.Nexus
{
    public class WebsocketServer : WebSocketBehavior
    {
        private static int _num = 0;
        private string _name;
        private string _prefix;
        private static string Token => Environment.GetEnvironmentVariable("RAM_API_TOKEN");

        public WebsocketServer() : this("anon#") { }
        public WebsocketServer(string prefix) => _prefix = prefix;
        private string getName() => Context.QueryString["name"] ?? (_prefix + getNum());
        private int getNum() => Interlocked.Increment(ref _num);

        protected override void OnOpen()
        {
            var supplied = Context.QueryString["token"];
            if (string.IsNullOrWhiteSpace(Token) || string.IsNullOrEmpty(supplied) || supplied != Token ||
                string.IsNullOrEmpty(Context.QueryString["name"]) || !long.TryParse(Context.QueryString["id"], out _))
            { Context.WebSocket.Close(CloseStatusCode.PolicyViolation, "Unauthorized"); return; }

            string jobID = string.IsNullOrEmpty(Context.QueryString["jobId"]) ? "UNKNOWN" : Context.QueryString["jobId"];
            _name = getName();
            ControlledAccount account = AccountControl.Instance.Accounts.FirstOrDefault(x => x.Username == Context.QueryString["name"]);
            if (account != null)
            {
                account.Connect(Context);
                account.InGameJobId = jobID;
                AccountControl.Instance.AccountsView.RefreshObject(account);
            }
            else Context.WebSocket.Close(CloseStatusCode.PolicyViolation, "Unknown account");
        }

        protected override void OnMessage(MessageEventArgs e)
        {
            if (e == null || e.Data == null || e.Data.Length > 64 * 1024) { Context.WebSocket.Close(CloseStatusCode.MessageTooBig); return; }
            if (AccountControl.Instance.ContextList.TryGetValue(Context, out ControlledAccount account)) account.HandleMessage(e.Data);
        }

        protected override void OnClose(CloseEventArgs e)
        {
            if (AccountControl.Instance.ContextList.TryGetValue(Context, out ControlledAccount account)) account.Disconnect();
        }

        protected override void OnError(ErrorEventArgs e) => Program.Logger.Error("WebsocketServer error: " + e.Message);
    }
}
'@
Set-Content -LiteralPath (Join-Path $work 'RBX Alt Manager/Nexus/WebsocketServer.cs') -Value $ws -Encoding UTF8

# Remove the explicitly unsafe no-encryption option from the settings UI/source when present.
$settings = Join-Path $work 'RBX Alt Manager/Forms/SettingsForm.cs'
if (Test-Path $settings) {
    $text = Get-Content $settings -Raw
    $text = $text -replace 'NoEncryption\.IUnderstandTheRisks\.iautamor', 'EncryptedOnly'
    Set-Content $settings $text -Encoding UTF8
}

# Keep account/session data out of source control and build output.
Add-Content -LiteralPath (Join-Path $work '.gitignore') -Value "`nAccountData.json`n*.ROBLOSECURITY`n*.cookie`n*.secret`n.env`n"

Write-Host "Secure source prepared at $work"
Write-Output $work
