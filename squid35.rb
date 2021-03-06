require "formula"

class Squid35 < Formula
  homepage "http://www.squid-cache.org/"
  url "http://www.squid-cache.org/Versions/v3/3.5/squid-3.5.3.tar.bz2"
  sha1 "d9478459c9d4d1eb8d13bb48213602f78e3b1f4a"

  depends_on "openssl"

  patch :p0, :DATA

  def install
    # http://stackoverflow.com/questions/20910109/building-squid-cache-on-os-x-mavericks
    ENV.append "LDFLAGS",  "-lresolv"

    # For --disable-eui, see:
    # http://squid-web-proxy-cache.1019090.n4.nabble.com/ERROR-ARP-MAC-EUI-operations-not-supported-on-this-operating-system-td4659335.html
    args = %W[
      --disable-debug
      --disable-dependency-tracking
      --prefix=#{prefix}
      --localstatedir=#{var}
      --enable-ssl
      --enable-ssl-crtd
      --with-openssl
      --disable-eui
      --enable-pf-transparent
      --with-included-ltdl
    ]

    system "./configure", *args
    system "make install"
  end

  def plist; <<-EOS.undent
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
      <key>KeepAlive</key>
      <true/>
      <key>Label</key>
      <string>#{plist_name}</string>
      <key>ProgramArguments</key>
      <array>
        <string>#{opt_sbin}/squid</string>
        <string>-N</string>
        <string>-d 1</string>
      </array>
      <key>RunAtLoad</key>
      <true/>
      <key>WorkingDirectory</key>
      <string>#{var}</string>
    </dict>
    </plist>
    EOS
  end
end

__END__
=== modified file 'acinclude/krb5.m4'
--- acinclude/krb5.m4	2015-01-13 07:25:36 +0000
+++ acinclude/krb5.m4	2015-03-06 21:36:54 +0000
@@ -79,6 +79,9 @@
 KRB5INT_BEGIN_DECLS
 #endif
 #endif
+#if USE_APPLE_KRB5
+#define KERBEROS_APPLE_DEPRECATED(x)
+#endif
 #include <krb5.h>
 krb5_context kc; kc->max_skew = 1;
       ]])
@@ -100,6 +103,9 @@
 KRB5INT_BEGIN_DECLS
 #endif
 #endif
+#if USE_APPLE_KRB5
+#define KERBEROS_APPLE_DEPRECATED(x)
+#endif
 #include <krb5.h>
 int main(int argc, char *argv[])
 {
@@ -127,6 +133,9 @@
 KRB5INT_BEGIN_DECLS
 #endif
 #endif
+#if USE_APPLE_KRB5
+#define KERBEROS_APPLE_DEPRECATED(x)
+#endif
 #include <krb5.h>
 int main(int argc, char *argv[])
 {
@@ -157,6 +166,9 @@
 #include <gss.h>
 #endif
 #else
+#if USE_APPLE_KRB5
+#define GSSKRB_APPLE_DEPRECATED(x)
+#endif
 #if HAVE_GSSAPI_GSSAPI_H
 #include <gssapi/gssapi.h>
 #elif HAVE_GSSAPI_H
@@ -200,6 +212,9 @@
 #include <gss.h>
 #endif
 #else
+#if USE_APPLE_KRB5
+#define GSSKRB_APPLE_DEPRECATED(x)
+#endif
 #if HAVE_GSSAPI_GSSAPI_H
 #include <gssapi/gssapi.h>
 #elif HAVE_GSSAPI_H
@@ -239,6 +254,9 @@
 AC_DEFUN([SQUID_CHECK_WORKING_KRB5],[
   AC_CACHE_CHECK([for working krb5], squid_cv_working_krb5, [
     AC_RUN_IFELSE([AC_LANG_SOURCE([[
+#if USE_APPLE_KRB5
+#define KERBEROS_APPLE_DEPRECATED(x)
+#endif
 #if HAVE_KRB5_H
 #if HAVE_BROKEN_SOLARIS_KRB5_H
 #if defined(__cplusplus)
@@ -338,6 +356,9 @@
       [Define to 1 if you have krb5_get_init_creds_opt_alloc]),)
   AC_MSG_CHECKING([for krb5_get_init_creds_free requires krb5_context])
   AC_COMPILE_IFELSE([AC_LANG_PROGRAM([[
+        #if USE_APPLE_KRB5
+        #define KERBEROS_APPLE_DEPRECATED(x)
+        #endif
 	#include <krb5.h>
     ]],[[krb5_context context;
 	 krb5_get_init_creds_opt *options;

=== modified file 'configure.ac'
--- configure.ac	2015-02-26 10:25:12 +0000
+++ configure.ac	2015-03-06 21:36:23 +0000
@@ -1399,6 +1399,7 @@
     with_mit_krb5=yes
 esac
 ])
+AH_TEMPLATE(USE_APPLE_KRB5,[Apple Kerberos support is available])
 AH_TEMPLATE(USE_MIT_KRB5,[MIT Kerberos support is available])
 AH_TEMPLATE(USE_SOLARIS_KRB5,[Solaris Kerberos support is available])
 
@@ -1489,6 +1490,7 @@
       krb5confpath="`dirname $ac_cv_path_krb5_config`"
       ac_heimdal="`$ac_cv_path_krb5_config --version 2>/dev/null | grep -c -i heimdal`"
       ac_solaris="`$ac_cv_path_krb5_config --version 2>/dev/null | grep -c -i solaris`"
+      ac_apple="`$ac_cv_path_krb5_config --vendor 2>/dev/null | grep -c -i apple`"
       if test $ac_heimdal -gt 0 ; then
 	with_heimdal_krb5=yes
         ac_with_krb5_count=1
@@ -1497,7 +1499,11 @@
 	with_solaris_krb5=yes
         ac_with_krb5_count=1
       fi
-      if test $ac_heimdal -eq 0 && test $ac_solaris -eq 0 ; then
+      if test $ac_apple -gt 0 ; then
+	with_apple_krb5=yes
+        ac_with_krb5_count=1
+      fi
+      if test $ac_heimdal -eq 0 && test $ac_solaris -eq 0 && test $ac_apple -eq 0; then
 	with_mit_krb5=yes
         ac_with_krb5_count=1
       fi
@@ -1507,7 +1513,7 @@
   fi
 fi
 
-if test "x$with_mit_krb5" = "xyes"; then
+if test "x$with_mit_krb5" = "xyes" || test "x$with_apple_krb5" = "xyes" ; then
   SQUID_STATE_SAVE([squid_krb5_save])
   LIBS="$LIBS $LIB_KRB5_PATH"
 
@@ -1558,10 +1564,15 @@
   ])
 
   if test "x$LIB_KRB5_LIBS" != "x"; then
+    if test "x$with_apple_krb5" = "xyes" ; then
+      AC_DEFINE(USE_APPLE_KRB5,1,[Apple Kerberos support is available])
+      KRB5_FLAVOUR="Apple" 
+    else
+      AC_DEFINE(USE_MIT_KRB5,1,[MIT Kerberos support is available])
+      KRB5_FLAVOUR="MIT" 
+    fi
     KRB5LIBS="$LIB_KRB5_PATH $LIB_KRB5_LIBS $KRB5LIBS"
     KRB5INCS="$LIB_KRB5_CFLAGS"
-    AC_DEFINE(USE_MIT_KRB5,1,[MIT Kerberos support is available])
-    KRB5_FLAVOUR="MIT" 
     
     # check for other specific broken implementations
     CXXFLAGS="$CXXFLAGS $KRB5INCS"

=== modified file 'helpers/external_acl/kerberos_ldap_group/required.m4'
--- helpers/external_acl/kerberos_ldap_group/required.m4	2015-01-13 07:25:36 +0000
+++ helpers/external_acl/kerberos_ldap_group/required.m4	2015-03-06 21:36:12 +0000
@@ -7,5 +7,10 @@
 
 if test "x$with_krb5" == "xyes"; then
   BUILD_HELPER="kerberos_ldap_group"
+  if test "x$with_apple_krb5" = "xyes" ; then
+    AC_CHECK_LIB(resolv, [main], [XTRA_LIBS="$XTRA_LIBS -lresolv"],[
+      AC_MSG_ERROR([library 'resolv' is required for Apple Kerberos])
+    ])
+  fi
   SQUID_CHECK_SASL
 fi

=== modified file 'helpers/external_acl/kerberos_ldap_group/support.h'
--- helpers/external_acl/kerberos_ldap_group/support.h	2015-02-18 02:30:34 +0000
+++ helpers/external_acl/kerberos_ldap_group/support.h	2015-03-05 21:52:26 +0000
@@ -34,6 +34,10 @@
 
 #include <cstring>
 
+#if USE_APPLE_KRB5
+#define KERBEROS_APPLE_DEPRECATED(x)
+#endif
+
 #if HAVE_KRB5_H
 #if HAVE_BROKEN_SOLARIS_KRB5_H
 #warn "Warning! You have a broken Solaris <krb5.h> system header"

=== modified file 'helpers/external_acl/kerberos_ldap_group/support_ldap.cc'
--- helpers/external_acl/kerberos_ldap_group/support_ldap.cc	2015-01-13 07:25:36 +0000
+++ helpers/external_acl/kerberos_ldap_group/support_ldap.cc	2015-03-05 21:52:26 +0000 @@ -114,11 +114,16 @@
     void *params)
 {
     struct ldap_creds *cp = (struct ldap_creds *) params;
+    struct berval cred;
+    if (cp->pw) {
+        cred.bv_val=cp->pw;
+	cred.bv_len=strlen(cp->pw);
+    }
     whop = whop;
     credp = credp;
     methodp = methodp;
     freeit = freeit;
-    return ldap_bind_s(ld, cp->dn, cp->pw, LDAP_AUTH_SIMPLE);
+    return ldap_sasl_bind_s(ld, cp->dn, LDAP_SASL_SIMPLE, &cred, NULL, NULL, NULL);
 }
 #elif HAVE_LDAP_REBIND_PROC
 #if HAVE_SASL_H || HAVE_SASL_SASL_H || HAVE_SASL_DARWIN
@@ -148,7 +153,12 @@
     void *params)
 {
     struct ldap_creds *cp = (struct ldap_creds *) params;
-    return ldap_bind_s(ld, cp->dn, cp->pw, LDAP_AUTH_SIMPLE);
+    struct berval cred;
+    if (cp->pw) {
+        cred.bv_val=cp->pw;
+	cred.bv_len=strlen(cp->pw);
+    }
+    return ldap_sasl_bind_s(ld, cp->dn, LDAP_SASL_SIMPLE, &cred, NULL, NULL, NULL);
 }
 
 #elif HAVE_LDAP_REBIND_FUNCTION
@@ -188,11 +198,16 @@
     void *params)
 {
     struct ldap_creds *cp = (struct ldap_creds *) params;
+    struct berval cred;
+    if (cp->pw) {
+        cred.bv_val=cp->pw;
+	cred.bv_len=strlen(cp->pw);
+    }
     whop = whop;
     credp = credp;
     methodp = methodp;
     freeit = freeit;
-    return ldap_bind_s(ld, cp->dn, cp->pw, LDAP_AUTH_SIMPLE);
+    return ldap_sasl_bind_s(ld, cp->dn, LDAP_SASL_SIMPLE, &cred, NULL, NULL, NULL);
 }
 #else
 #error "No rebind functione defined"
@@ -202,9 +217,9 @@
 static LDAP_REBIND_PROC ldap_sasl_rebind;
 
 static int
 ldap_sasl_rebind(
-    LDAP * ld,
-    LDAP_CONST char *url,
+    LDAP *ld,
+    LDAP_CONST char *,
     ber_tag_t request,
     ber_int_t msgid,
     void *params)
@@ -218,8 +227,8 @@
 
 static int
 ldap_simple_rebind(
-    LDAP * ld,
-    LDAP_CONST char *url,
+    LDAP *ld,
+    LDAP_CONST char *,
     ber_tag_t request,
     ber_int_t msgid,
     void *params)
@@ -231,7 +246,12 @@
 {
 
     struct ldap_creds *cp = (struct ldap_creds *) params;
-    return ldap_bind_s(ld, cp->dn, cp->pw, LDAP_AUTH_SIMPLE);
+    struct berval cred;
+    if (cp->pw) {
+        cred.bv_val=cp->pw;
+	cred.bv_len=strlen(cp->pw);
+    }
+    return ldap_sasl_bind_s(ld, cp->dn, LDAP_SASL_SIMPLE, &cred, NULL, NULL, NULL);
 }
 
 #endif
@@ -745,7 +765,7 @@
     xfree(ldapuri);
     if (rc != LDAP_SUCCESS) {
         error((char *) "%s| %s: ERROR: Error while initialising connection to ldap server: %s\n", LogTime(), PROGRAM, ldap_err2string(rc));
-        ldap_unbind(ld);
+        ldap_unbind_ext(ld,NULL,NULL);
         ld = NULL;
         return NULL;
     }
@@ -755,7 +775,7 @@
     rc = ldap_set_defaults(ld);
     if (rc != LDAP_SUCCESS) {
         error((char *) "%s| %s: ERROR: Error while setting default options for ldap server: %s\n", LogTime(), PROGRAM, ldap_err2string(rc));
-        ldap_unbind(ld);
+        ldap_unbind_ext(ld, NULL, NULL);
         ld = NULL;
         return NULL;
     }
@@ -767,7 +787,7 @@
         rc = ldap_set_ssl_defaults(margs);
         if (rc != LDAP_SUCCESS) {
             error((char *) "%s| %s: ERROR: Error while setting SSL default options for ldap server: %s\n", LogTime(), PROGRAM, ldap_err2string(rc));
-            ldap_unbind(ld);
+            ldap_unbind_ext(ld, NULL, NULL);
             ld = NULL;
             return NULL;
         }
@@ -778,7 +798,7 @@
         rc = ldap_start_tls_s(ld, NULL, NULL);
         if (rc != LDAP_SUCCESS) {
             error((char *) "%s| %s: ERROR: Error while setting start_tls for ldap server: %s\n", LogTime(), PROGRAM, ldap_err2string(rc));
-            ldap_unbind(ld);
+            ldap_unbind_ext(ld, NULL, NULL);
             ld = NULL;
             url = (LDAPURLDesc *) xmalloc(sizeof(*url));
             memset(url, 0, sizeof(*url));
@@ -810,14 +830,14 @@
             xfree(ldapuri);
             if (rc != LDAP_SUCCESS) {
                 error((char *) "%s| %s: ERROR: Error while initialising connection to ldap server: %s\n", LogTime(), PROGRAM, ldap_err2string(rc));
-                ldap_unbind(ld);
+                ldap_unbind_ext(ld, NULL, NULL);
                 ld = NULL;
                 return NULL;
             }
             rc = ldap_set_defaults(ld);
             if (rc != LDAP_SUCCESS) {
                 error((char *) "%s| %s: ERROR: Error while setting default options for ldap server: %s\n", LogTime(), PROGRAM, ldap_err2string(rc));
-                ldap_unbind(ld);
+                ldap_unbind_ext(ld, NULL, NULL);
                 ld = NULL;
                 return NULL;
             }
@@ -826,14 +846,14 @@
         ld = ldapssl_init(host, port, 1);
         if (!ld) {
             error((char *) "%s| %s: ERROR: Error while setting SSL for ldap server: %s\n", LogTime(), PROGRAM, ldapssl_err2string(rc));
-            ldap_unbind(ld);
+            ldap_unbind_ext(ld, NULL, NULL);
             ld = NULL;
             return NULL;
         }
         rc = ldap_set_defaults(ld);
         if (rc != LDAP_SUCCESS) {
             error((char *) "%s| %s: ERROR: Error while setting default options for ldap server: %s\n", LogTime(), PROGRAM, ldap_err2string(rc));
-            ldap_unbind(ld);
+            ldap_unbind_ext(ld, NULL, NULL);
             ld = NULL;
             return NULL;
         }
@@ -940,7 +960,7 @@
             rc = tool_sasl_bind(ld, bindp, margs->ssl);
             if (rc != LDAP_SUCCESS) {
                 error((char *) "%s| %s: ERROR: Error while binding to ldap server with SASL/GSSAPI: %s\n", LogTime(), PROGRAM, ldap_err2string(rc));
-                ldap_unbind(ld);
+                ldap_unbind_ext(ld, NULL, NULL);
                 ld = NULL;
                 continue;
             }
@@ -953,7 +973,7 @@
                 break;
             }
 #else
-            ldap_unbind(ld);
+            ldap_unbind_ext(ld, NULL, NULL);
             ld = NULL;
             error((char *) "%s| %s: ERROR: SASL not supported on system\n", LogTime(), PROGRAM);
             continue;
@@ -993,7 +1013,11 @@
         nhosts = get_hostname_list(&hlist, 0, host);
         xfree(host);
         for (size_t i = 0; i < nhosts; ++i) {
-
+	    struct berval cred;
+	    if (margs->lpass) {
+                cred.bv_val=margs->lpass;
+                cred.bv_len=strlen(margs->lpass);
+	    }
             ld = tool_ldap_open(margs, hlist[i].host, port, ssl);
             if (!ld)
                 continue;
@@ -1002,10 +1026,10 @@
              */
 
             debug((char *) "%s| %s: DEBUG: Bind to ldap server with Username/Password\n", LogTime(), PROGRAM);
-            rc = ldap_simple_bind_s(ld, margs->luser, margs->lpass);
+	    rc = ldap_sasl_bind_s(ld, margs->luser, LDAP_SASL_SIMPLE, &cred, NULL, NULL, NULL);
             if (rc != LDAP_SUCCESS) {
                 error((char *) "%s| %s: ERROR: Error while binding to ldap server with Username/Password: %s\n", LogTime(), PROGRAM, ldap_err2string(rc));
-                ldap_unbind(ld);
+                ldap_unbind_ext(ld, NULL, NULL);
                 ld = NULL;
                 continue;
             }
@@ -1040,7 +1064,7 @@
     rc = check_AD(margs, ld);
     if (rc != LDAP_SUCCESS) {
         error((char *) "%s| %s: ERROR: Error determining ldap server type: %s\n", LogTime(), PROGRAM, ldap_err2string(rc));
-        ldap_unbind(ld);
+        ldap_unbind_ext(ld, NULL, NULL);
         ld = NULL;
         retval = 0;
         goto cleanup;
@@ -1066,7 +1090,7 @@
 
     if (rc != LDAP_SUCCESS) {
         error((char *) "%s| %s: ERROR: Error searching ldap server: %s\n", LogTime(), PROGRAM, ldap_err2string(rc));
-        ldap_unbind(ld);
+        ldap_unbind_ext(ld, NULL, NULL);
         ld = NULL;
         retval = 0;
         goto cleanup;
@@ -1151,7 +1175,7 @@
         ldap_msgfree(res);
     } else if (ldap_count_entries(ld, res) == 0 && margs->AD) {
         ldap_msgfree(res);
-        ldap_unbind(ld);
+        ldap_unbind_ext(ld, NULL, NULL);
         ld = NULL;
         retval = 0;
         goto cleanup;
@@ -1363,7 +1387,7 @@
             safe_free(attr_value);
         }
     }
-    rc = ldap_unbind(ld);
+    rc = ldap_unbind_ext(ld, NULL, NULL);
     ld = NULL;
     if (rc != LDAP_SUCCESS) {
         error((char *) "%s| %s: ERROR: Error unbind ldap server: %s\n", LogTime(), PROGRAM, ldap_err2string(rc));

=== modified file 'helpers/negotiate_auth/kerberos/negotiate_kerberos.h'
--- helpers/negotiate_auth/kerberos/negotiate_kerberos.h	2015-01-13 07:25:36 +0000
+++ helpers/negotiate_auth/kerberos/negotiate_kerberos.h	2015-03-05 21:52:26 +0000
@@ -47,6 +47,11 @@
 #include "base64.h"
 #include "util.h"
 
+#if USE_APPLE_KRB5
+#define KERBEROS_APPLE_DEPRECATED(x)
+#define GSSKRB_APPLE_DEPRECATED(x)
+#endif
+
 #if HAVE_KRB5_H
 #if HAVE_BROKEN_SOLARIS_KRB5_H
 #warn "Warning! You have a broken Solaris <krb5.h> system header"
@@ -144,7 +149,6 @@
     uint32_t pointer;
 } RPC_UNICODE_STRING;
 
-int check_k5_err(krb5_context context, const char *msg, krb5_error_code code);
 void align(int n);
 void getustr(RPC_UNICODE_STRING *string);
 char **getgids(char **Rids, uint32_t GroupIds, uint32_t GroupCount);
@@ -161,4 +165,4 @@
 #else
 #define HAVE_PAC_SUPPORT 0
 #endif
-
+int check_k5_err(krb5_context context, const char *msg, krb5_error_code code);

=== modified file 'helpers/negotiate_auth/kerberos/negotiate_kerberos_auth.cc'
--- helpers/negotiate_auth/kerberos/negotiate_kerberos_auth.cc	2015-02-06 10:04:11 +0000
+++ helpers/negotiate_auth/kerberos/negotiate_kerberos_auth.cc	2015-03-05 21:52:26 +0000 @@ -65,7 +65,6 @@
                                  krb5_kt_list *kt_list);
 #endif /* HAVE_KRB5_MEMORY_KEYTAB */
 
-#if HAVE_PAC_SUPPORT || HAVE_KRB5_MEMORY_KEYTAB
 int
 check_k5_err(krb5_context context, const char *function, krb5_error_code code)
 {
@@ -85,7 +84,6 @@
     }
     return code;
 }
-#endif
 
 char *
 gethost_name(void)

=== modified file 'helpers/negotiate_auth/kerberos/negotiate_kerberos_auth_test.cc'
--- helpers/negotiate_auth/kerberos/negotiate_kerberos_auth_test.cc	2015-01-13 07:25:36 +0000
+++ helpers/negotiate_auth/kerberos/negotiate_kerberos_auth_test.cc	2015-03-05 21:52:26 +0000 @@ -33,6 +33,9 @@
 #include "squid.h"
 
 #if HAVE_GSSAPI
+#if USE_APPLE_KRB5
+#define GSSKRB_APPLE_DEPRECATED(x)
+#endif
 
 #include <cerrno>
 #include <cstring>

=== modified file 'src/peer_proxy_negotiate_auth.cc'
--- src/peer_proxy_negotiate_auth.cc	2015-01-13 07:25:36 +0000
+++ src/peer_proxy_negotiate_auth.cc	2015-03-05 21:52:26 +0000
@@ -13,6 +13,10 @@
 #include "squid.h"
 
 #if HAVE_KRB5 && HAVE_GSSAPI
+#if USE_APPLE_KRB5
+#define KERBEROS_APPLE_DEPRECATED(x)
+#define GSSKRB_APPLE_DEPRECATED(x)
+#endif
 
 #include "base64.h"
 #include "Debug.h"

=== modified file 'tools/squidclient/gssapi_support.h'
--- tools/squidclient/gssapi_support.h	2015-01-13 07:25:36 +0000
+++ tools/squidclient/gssapi_support.h	2015-03-05 21:52:26 +0000
@@ -10,6 +10,9 @@
 #define _SQUID_TOOLS_SQUIDCLIENT_GSSAPI_H
 
 #if HAVE_GSSAPI
+#if USE_APPLE_KRB5
+#define GSSKRB_APPLE_DEPRECATED(x)
+#endif
 
 #if USE_HEIMDAL_KRB5
 #if HAVE_GSSAPI_GSSAPI_H
