import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// Runs the native Google Sign-In flow and exchanges it for a Firebase ID
/// token, which the backend (`POST /auth/google-signin`) verifies.
///
/// Requires Firebase to be configured (`flutterfire configure`). Until then the
/// UI surfaces a friendly "not configured" message rather than crashing.
class GoogleAuthService {
  final _googleSignIn = GoogleSignIn();

  /// Returns a Firebase ID token, or null if the user cancelled.
  Future<String?> signIn() async {
    final googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null; // cancelled

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      idToken: googleAuth.idToken,
      accessToken: googleAuth.accessToken,
    );
    final userCred =
        await FirebaseAuth.instance.signInWithCredential(credential);
    return userCred.user?.getIdToken();
  }

  Future<void> signOut() async {
    await _googleSignIn.signOut();
    await FirebaseAuth.instance.signOut();
  }
}
