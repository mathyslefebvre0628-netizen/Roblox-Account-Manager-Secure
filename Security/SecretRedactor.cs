using System;
using System.Text.RegularExpressions;

namespace RobloxAccountManager.Security
{
    internal static class SecretRedactor
    {
        private static readonly Regex Cookie = new Regex(@"(?i)(\.ROBLOSECURITY\s*[=:]\s*)[^\s;]+", RegexOptions.Compiled);
        private static readonly Regex Bearer = new Regex(@"(?i)(Bearer\s+)[A-Za-z0-9._~+/=-]+", RegexOptions.Compiled);
        private static readonly Regex Password = new Regex(@"(?i)(password\s*[=:]\s*)[^\s;]+", RegexOptions.Compiled);
        private static readonly Regex Token = new Regex(@"(?i)((?:api[_-]?key|token|secret)\s*[=:]\s*)[^\s;]+", RegexOptions.Compiled);

        public static string Redact(string value)
        {
            if (string.IsNullOrEmpty(value))
                return value;

            value = Cookie.Replace(value, "$1[REDACTED]");
            value = Bearer.Replace(value, "$1[REDACTED]");
            value = Password.Replace(value, "$1[REDACTED]");
            return Token.Replace(value, "$1[REDACTED]");
        }
    }
}
