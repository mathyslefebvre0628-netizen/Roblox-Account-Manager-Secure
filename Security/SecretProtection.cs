using System;
using System.Security.Cryptography;
using System.Text;

namespace RobloxAccountManager.Security
{
    /// <summary>
    /// Protects local secrets with Windows DPAPI, scoped to the current Windows user.
    /// The plaintext secret is never persisted by this class.
    /// </summary>
    internal static class SecretProtection
    {
        private static readonly byte[] Entropy = Encoding.UTF8.GetBytes("RobloxAccountManager.Secure.v1");

        public static byte[] Protect(byte[] plaintext)
        {
            if (plaintext == null || plaintext.Length == 0)
                throw new ArgumentException("A non-empty secret is required.", nameof(plaintext));

            return ProtectedData.Protect(plaintext, Entropy, DataProtectionScope.CurrentUser);
        }

        public static byte[] Unprotect(byte[] protectedData)
        {
            if (protectedData == null || protectedData.Length == 0)
                throw new ArgumentException("Protected data is required.", nameof(protectedData));

            return ProtectedData.Unprotect(protectedData, Entropy, DataProtectionScope.CurrentUser);
        }

        public static void Zero(byte[] buffer)
        {
            if (buffer != null)
                CryptographicOperations.ZeroMemory(buffer);
        }
    }
}
