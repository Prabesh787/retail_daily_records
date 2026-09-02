import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/errors/app_exception.dart';
import '../../../routes/app_pages.dart';
import '../../../services/auth_service.dart';

class LoginController extends GetxController {
  final formKey = GlobalKey<FormState>();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  final RxBool isSubmitting = false.obs;
  final RxBool obscure = true.obs;

  /// A failure that belongs to the whole form rather than to one field - wrong
  /// credentials, server unreachable. Field-level problems are the validators'
  /// job.
  final RxnString formError = RxnString();

  AuthService get _auth => AuthService.to;

  /// False when the build has no `API_BASE_URL`. That is a misconfigured build
  /// rather than a mode the app can run in, and the screen says so instead of
  /// offering a form that cannot work.
  bool get serverConfigured => _auth.canSignIn;

  void toggleObscure() => obscure.toggle();

  String? validateEmail(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Email is required';
    if (!RegExp(r'^\S+@\S+\.\S+$').hasMatch(text)) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? validatePassword(String? value) =>
      (value ?? '').isEmpty ? 'Password is required' : null;

  Future<void> submit() async {
    formError.value = null;
    if (!(formKey.currentState?.validate() ?? false)) return;

    isSubmitting.value = true;
    try {
      final user = await _auth.signIn(
        email: emailCtrl.text,
        password: passwordCtrl.text,
      );
      Get.offAllNamed(Routes.home);
      Get.snackbar(
        'Welcome back',
        'Signed in as ${user.name}',
        snackPosition: SnackPosition.BOTTOM,
      );
    } on AppException catch (e) {
      formError.value = e.message;
    } catch (e) {
      formError.value = 'Could not sign in. $e';
    } finally {
      isSubmitting.value = false;
    }
  }

  @override
  void onClose() {
    emailCtrl.dispose();
    passwordCtrl.dispose();
    super.onClose();
  }
}
