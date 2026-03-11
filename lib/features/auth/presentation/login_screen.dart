import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme.dart';
import '../data/auth_repository.dart';

enum _AuthMode { login, register, verifyEmail }

String _friendlyError(Object error) {
  if (error is EmailNotVerifiedException) {
    return 'Please verify your email before signing in.';
  }
  if (error is FirebaseAuthException) {
    switch (error.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return error.message ?? 'Authentication error.';
    }
  }
  final msg = error.toString().replaceAll('Exception: ', '').trim();
  return msg.isNotEmpty ? msg : 'An unexpected error occurred.';
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  _AuthMode _mode = _AuthMode.login;
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorText;

  // Stored temporarily in memory for the resend functionality
  String _pendingEmail = '';
  String _pendingPassword = '';

  final _loginFormKey = GlobalKey<FormState>();
  final _registerFormKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  AuthRepository get _repo => ref.read(authRepositoryProvider);

  Future<void> _signIn() async {
    if (!(_loginFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await _repo.signInWithEmailAndPassword(
        _emailCtrl.text.trim(),
        _passwordCtrl.text.trim(),
      );
      // On success, authStateProvider stream updates and router navigates automatically.
    } on EmailNotVerifiedException catch (e) {
      setState(() {
        _pendingEmail = e.email;
        _pendingPassword = _passwordCtrl.text.trim();
        _mode = _AuthMode.verifyEmail;
      });
    } catch (e) {
      setState(() => _errorText = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _register() async {
    if (!(_registerFormKey.currentState?.validate() ?? false)) return;
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await _repo.createUserWithEmailAndPassword(
        _emailCtrl.text.trim(),
        _passwordCtrl.text.trim(),
        _nameCtrl.text.trim(),
      );
    } on EmailNotVerifiedException catch (e) {
      setState(() {
        _pendingEmail = e.email;
        _pendingPassword = _passwordCtrl.text.trim();
        _mode = _AuthMode.verifyEmail;
      });
    } catch (e) {
      setState(() => _errorText = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await _repo.signInWithGoogle();
    } catch (e) {
      if (mounted) setState(() => _errorText = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _errorText = 'Enter your email address above first.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await _repo.sendPasswordResetEmail(email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Password reset email sent!')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorText = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendVerification() async {
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await _repo.resendVerificationEmail(
        email: _pendingEmail,
        password: _pendingPassword,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent!')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _errorText = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _switchMode(_AuthMode mode) {
    setState(() {
      _mode = mode;
      _errorText = null;
    });
  }

  Future<void> _exitVerifyEmail() async {
    await _repo.signOut();
    _switchMode(_AuthMode.login);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Intercept hardware/gesture back on the verify screen to sign out first.
      canPop: _mode != _AuthMode.verifyEmail,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _mode == _AuthMode.verifyEmail) {
          _exitVerifyEmail();
        }
      },
      child: Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: _mode == _AuthMode.verifyEmail
              ? _exitVerifyEmail
              : () => context.go('/'),
        ),
      ),
      body: SafeArea(
        child: _mode == _AuthMode.verifyEmail
            ? _buildVerifyEmailScreen()
            : _buildAuthForm(),
      ),
    ),
    );
  }

  Widget _buildAuthForm() {
    final isLogin = _mode == _AuthMode.login;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Form(
        key: isLogin ? _loginFormKey : _registerFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Hero(
              tag: 'logo',
              child: Image.asset('assets/logo.png', height: 72, fit: BoxFit.contain),
            ),
            const SizedBox(height: 28),
            Text(
              isLogin ? 'Welcome back' : 'Create account',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.secondaryColor,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              isLogin
                  ? 'Sign in to continue.'
                  : 'Join us and start booking your games.',
              style: TextStyle(color: Colors.grey[600], fontSize: 15),
            ),
            const SizedBox(height: 32),

            // Name field (register only)
            if (!isLogin) ...[
              _fieldWidget(
                controller: _nameCtrl,
                label: 'Full Name',
                icon: Icons.person_outline,
                validator: (v) =>
                    (v?.trim().isEmpty ?? true) ? 'Please enter your name' : null,
              ),
              const SizedBox(height: 16),
            ],

            // Email field
            _fieldWidget(
              controller: _emailCtrl,
              label: 'Email',
              icon: Icons.email_outlined,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Please enter your email';
                final reg = RegExp(
                    r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$');
                if (!reg.hasMatch(v.trim())) return 'Please enter a valid email';
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Password field
            _fieldWidget(
              controller: _passwordCtrl,
              label: 'Password',
              icon: Icons.lock_outline,
              obscureText: _obscurePassword,
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_outlined
                      : Icons.visibility_outlined,
                  color: Colors.grey[500],
                ),
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Please enter your password';
                if (v.length < 6) return 'Password must be at least 6 characters';
                return null;
              },
            ),

            // Forgot password (login only)
            if (isLogin)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading ? null : _forgotPassword,
                  child: const Text(
                    'Forgot password?',
                    style: TextStyle(color: AppTheme.primaryColor, fontSize: 13),
                  ),
                ),
              )
            else
              const SizedBox(height: 16),

            // Error banner
            if (_errorText != null) ...[
              const SizedBox(height: 4),
              _errorBanner(_errorText!),
            ],

            const SizedBox(height: 20),

            // Primary action button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : (isLogin ? _signIn : _register),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(
                        isLogin ? 'Sign in' : 'Create account',
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600),
                      ),
              ),
            ),

            const SizedBox(height: 24),

            Row(
              children: [
                Expanded(child: Divider(color: Colors.grey[300])),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or',
                      style: TextStyle(color: Colors.grey[500], fontSize: 13)),
                ),
                Expanded(child: Divider(color: Colors.grey[300])),
              ],
            ),

            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _googleSignIn,
                icon: _googleLogoWidget(),
                label: Text(
                  isLogin ? 'Continue with Google' : 'Sign up with Google',
                  style: const TextStyle(fontSize: 15),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey[300]!),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  foregroundColor: Colors.black87,
                ),
              ),
            ),

            const SizedBox(height: 32),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  isLogin
                      ? "Don't have an account?  "
                      : 'Already have an account?  ',
                  style: TextStyle(color: Colors.grey[600], fontSize: 15),
                ),
                GestureDetector(
                  onTap: () => _switchMode(
                      isLogin ? _AuthMode.register : _AuthMode.login),
                  child: Text(
                    isLogin ? 'Sign up' : 'Sign in',
                    style: const TextStyle(
                      color: AppTheme.primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildVerifyEmailScreen() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Column(
        children: [
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.mark_email_unread_outlined,
              size: 72,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Verify your email',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppTheme.secondaryColor,
                ),
          ),
          const SizedBox(height: 16),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: TextStyle(
                  color: Colors.grey[600], fontSize: 15, height: 1.6),
              children: [
                const TextSpan(text: 'A verification link was sent to\n'),
                TextSpan(
                  text: _pendingEmail,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Click the link in the email to verify your account.\nCheck your spam folder if you don\'t see it.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 13, height: 1.6),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: 16),
            _errorBanner(_errorText!),
          ],
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () async {
                await _repo.signOut();
                _switchMode(_AuthMode.login);
              },
              child: const Text(
                'Go to Login',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: _isLoading ? null : _resendVerification,
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primaryColor),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text(
                      'Resend verification email',
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _fieldWidget({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _errorBanner(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: Colors.red[700], size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Colors.red[700], fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _googleLogoWidget() {
    return SvgPicture.string(
      '''<svg viewBox="0 0 24 24" width="20" height="20" xmlns="http://www.w3.org/2000/svg"><g transform="matrix(1, 0, 0, 1, 27.009001, -39.238998)"><path fill="#4285F4" d="M -3.264 51.509 C -3.264 50.719 -3.334 49.969 -3.454 49.239 L -14.754 49.239 L -14.754 53.749 L -8.284 53.749 C -8.574 55.229 -9.424 56.479 -10.684 57.329 L -10.684 60.329 L -6.824 60.329 C -4.564 58.239 -3.264 55.159 -3.264 51.509 Z"/><path fill="#34A853" d="M -14.754 63.239 C -11.514 63.239 -8.804 62.159 -6.824 60.329 L -10.684 57.329 C -11.764 58.049 -13.134 58.489 -14.754 58.489 C -17.884 58.489 -20.534 56.379 -21.484 53.529 L -25.464 53.529 L -25.464 56.619 C -23.494 60.539 -19.444 63.239 -14.754 63.239 Z"/><path fill="#FBBC05" d="M -21.484 53.529 C -21.734 52.809 -21.864 52.039 -21.864 51.239 C -21.864 50.439 -21.734 49.669 -21.484 48.949 L -21.484 45.859 L -25.464 45.859 C -26.284 47.479 -26.754 49.299 -26.754 51.239 C -26.754 53.179 -26.284 54.999 -25.464 56.619 L -21.484 53.529 Z"/><path fill="#EA4335" d="M -14.754 43.989 C -12.984 43.989 -11.404 44.599 -10.154 45.799 L -6.734 42.379 C -8.804 40.439 -11.514 39.239 -14.754 39.239 C -19.444 39.239 -23.494 41.939 -25.464 45.859 L -21.484 48.949 C -20.534 46.099 -17.884 43.989 -14.754 43.989 Z"/></g></svg>''',
      width: 20,
      height: 20,
    );
  }
}
