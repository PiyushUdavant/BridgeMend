import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthResult {
  final User? user;
  final String? errorMessage;

  AuthResult({this.user, this.errorMessage});
}

class GoogleSignInResult extends AuthResult {
  GoogleSignInResult({super.user, super.errorMessage});
}

class FirebaseAuthService {
  final GoTrueClient _auth = Supabase.instance.client.auth;
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;

  // Get current user
  User? get currentUser => _auth.currentUser;

  // Get auth state changes
  Stream<User?> get authStateChanges =>
      _auth.onAuthStateChange.map((event) => event.session?.user);

  // Sign in with Google
  Future<GoogleSignInResult> signInWithGoogle() async {
    try {
      await _googleSignIn.initialize();

      final GoogleSignInAccount? googleUser = await _googleSignIn
          .authenticate();

      if (googleUser == null) {
        return GoogleSignInResult(errorMessage: 'Sign-in cancelled by user.');
      }

      final GoogleSignInAuthentication googleAuth = await googleUser
          .authentication;
      if (googleAuth.idToken == null) {
        return GoogleSignInResult(
          errorMessage: 'Google sign-in did not return an ID token.',
        );
      }

      final response = await _auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
      );
      return GoogleSignInResult(user: response.user);
    } catch (e) {
      debugPrint('Error signing in with Google: $e');
      return GoogleSignInResult(
        errorMessage: 'Sign-in failed. Please try again.',
      );
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await Future.wait([_auth.signOut(), _googleSignIn.signOut()]);
    } catch (e) {
      debugPrint('Error signing out: $e');
      rethrow;
    }
  }

  // Delete user account
  Future<void> deleteAccount() async {
    try {
      throw UnsupportedError(
        'Direct account deletion is not supported on Supabase client SDK. '
        'Use a secure backend endpoint for this action.',
      );
    } catch (e) {
      debugPrint('Error deleting account: $e');
      rethrow;
    }
  }

  // Get user profile data
  Map<String, dynamic>? get userProfile {
    final user = currentUser;
    if (user == null) return null;

    return {
      'uid': user.id,
      'email': user.email,
      'displayName': user.userMetadata?['full_name'],
      'photoURL': user.userMetadata?['avatar_url'],
      'emailVerified': user.emailConfirmedAt != null,
      'createdAt': user.createdAt,
      'lastSignInTime': null,
    };
  }

  // Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  // Sign in with email and password
  Future<AuthResult> signInWithEmail(String email, String password) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );
      return AuthResult(user: response.user);
    } on AuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'invalid_credentials':
          errorMessage = 'Invalid email or password. Please try again.';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many failed attempts. Please try again later.';
          break;
        case 'email_not_confirmed':
          errorMessage =
              'Please verify your email before signing in. Check your inbox.';
          break;
        default:
          errorMessage = 'Sign in failed: ${e.message}';
      }
      return AuthResult(errorMessage: errorMessage);
    } catch (e) {
      debugPrint('Error signing in with email: $e');
      return AuthResult(
        errorMessage: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  // Sign up with email and password
  Future<AuthResult> signUpWithEmail(String email, String password) async {
    try {
      final response = await _auth.signUp(
        email: email.trim(),
        password: password,
      );
      return AuthResult(user: response.user);
    } on AuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'weak-password':
          errorMessage = 'Password should be at least 6 characters long.';
          break;
        case 'email-already-in-use':
          errorMessage = 'An account already exists with this email address.';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;
        case 'operation-not-allowed':
          errorMessage = 'Email/password accounts are not enabled.';
          break;
        default:
          errorMessage = 'Sign up failed: ${e.message}';
      }
      return AuthResult(errorMessage: errorMessage);
    } catch (e) {
      debugPrint('Error signing up with email: $e');
      return AuthResult(
        errorMessage: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  // Send password reset email
  Future<AuthResult> sendPasswordResetEmail(String email) async {
    try {
      await _auth.resetPasswordForEmail(email.trim());
      return AuthResult(user: null);
    } on AuthException catch (e) {
      String errorMessage;
      switch (e.code) {
        case 'user-not-found':
          errorMessage = 'No account found with this email address.';
          break;
        case 'invalid-email':
          errorMessage = 'Please enter a valid email address.';
          break;
        default:
          errorMessage = 'Failed to send reset email: ${e.message}';
      }
      return AuthResult(errorMessage: errorMessage);
    } catch (e) {
      debugPrint('Error sending password reset email: $e');
      return AuthResult(
        errorMessage: 'An unexpected error occurred. Please try again.',
      );
    }
  }

  // Send email verification
  Future<AuthResult> sendEmailVerification() async {
    try {
      final user = currentUser;
      if (user != null && user.emailConfirmedAt == null && user.email != null) {
        await _auth.resend(type: OtpType.signup, email: user.email);
        return AuthResult(user: null);
      }
      return AuthResult(errorMessage: 'No user to verify or already verified.');
    } catch (e) {
      debugPrint('Error sending verification email: $e');
      return AuthResult(errorMessage: 'Failed to send verification email.');
    }
  }

  // Reload user to check verification status
  Future<void> reloadUser() async {
    try {
      await _auth.refreshSession();
    } catch (e) {
      debugPrint('Error reloading user: $e');
    }
  }

  // Delete current user account (for unverified accounts)
  Future<AuthResult> deleteCurrentUser() async {
    try {
      final user = currentUser;
      if (user != null) {
        return AuthResult(
          errorMessage:
              'Account deletion requires a secure backend endpoint in Supabase.',
        );
      }
      return AuthResult(errorMessage: 'No user to delete');
    } on AuthException catch (e) {
      return AuthResult(errorMessage: 'Failed to delete account: ${e.message}');
    } catch (e) {
      debugPrint('Error deleting user: $e');
      return AuthResult(errorMessage: 'An unexpected error occurred.');
    }
  }

  // Check if user has a linked provider
  bool userHasProvider(String providerId) {
    final user = currentUser;
    if (user == null) return false;
    final providers = (user.appMetadata['providers'] as List?) ?? const [];
    return providers.contains(providerId);
  }

  // Reauthenticate with Google for sensitive operations
  Future<AuthResult> reauthenticateWithGoogle() async {
    try {
      final result = await signInWithGoogle();
      return AuthResult(user: result.user, errorMessage: result.errorMessage);
    } on AuthException catch (e) {
      return AuthResult(errorMessage: e.message);
    } catch (e) {
      debugPrint('Error during Google reauthentication: $e');
      return AuthResult(errorMessage: 'Reauthentication failed.');
    }
  }

  // Check if user needs email verification
  bool get needsEmailVerification {
    final user = currentUser;
    if (user == null) return false;
    return user.emailConfirmedAt == null;
  }

  // Get user creation time
  DateTime? get userCreationTime => DateTime.tryParse(currentUser?.createdAt ?? '');
}
