import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/constants/app_sizes.dart';
import '../../../core/extensions/context_ext.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/app_card.dart';
import '../controllers/login_controller.dart';

/// The front door.
///
/// Signing in is **optional**: the shop's records live on this device whether
/// or not there is an account, so the screen always offers a way past itself.
/// An account is what lets those records reach the server and a second phone —
/// nothing more, and the copy says so rather than implying a wall.
class LoginView extends GetView<LoginController> {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      // A soft wash behind the card, brightest behind the mark at the top. It
      // gives the screen a focal point without adding an image to load.
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [palette.brandSoft, palette.bg],
            stops: const [0, 0.55],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSizes.xl),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: controller.formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const _Brand(),
                      AppSizes.gapXl,
                      AppCard(
                        padding: const EdgeInsets.all(AppSizes.xl),
                        child: controller.serverConfigured
                            ? _SignInForm(controller: controller)
                            : const _LocalOnlyNotice(),
                      ),
                      AppSizes.gapLg,
                      // No way past this screen. The app serves several shops
                      // off one backend and every record belongs to one of
                      // them, so there is nothing to show until it knows whose
                      // books it is opening.
                      Text(
                        'Each shop keeps its own books. Sign in with the '
                        'account for your shop.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.caption
                            .copyWith(color: palette.inkSubtle),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      children: [
        Container(
          height: 64,
          width: 64,
          decoration: BoxDecoration(
            color: palette.brand,
            borderRadius: BorderRadius.circular(20),
            boxShadow: AppSizes.lift(palette.brand.withValues(alpha: 0.35)),
          ),
          child: const Icon(Icons.storefront_rounded, size: 32, color: Colors.white),
        ),
        AppSizes.gapLg,
        Text('Shop Records',
            style: AppTextStyles.h1.copyWith(color: palette.ink)),
        AppSizes.gapXs,
        Text(
          'Sign in to open the shop’s books',
          style: AppTextStyles.body.copyWith(color: palette.inkMuted),
        ),
      ],
    );
  }
}

class _SignInForm extends StatelessWidget {
  const _SignInForm({required this.controller});

  final LoginController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Obx(
          () => controller.formError.value == null
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.only(bottom: AppSizes.lg),
                  child: _Banner(
                    icon: Icons.error_outline_rounded,
                    message: controller.formError.value!,
                    tone: context.palette.moneyOut,
                  ),
                ),
        ),
        _Label('Email'),
        AppSizes.gapSm,
        TextFormField(
          controller: controller.emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autocorrect: false,
          autofillHints: const [AutofillHints.username],
          textInputAction: TextInputAction.next,
          validator: controller.validateEmail,
          decoration: const InputDecoration(
            hintText: 'you@shop.com',
            prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
          ),
        ),
        AppSizes.gapLg,
        _Label('Password'),
        AppSizes.gapSm,
        Obx(
          () => TextFormField(
            controller: controller.passwordCtrl,
            obscureText: controller.obscure.value,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            validator: controller.validatePassword,
            onFieldSubmitted: (_) => controller.submit(),
            decoration: InputDecoration(
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
              suffixIcon: IconButton(
                tooltip: controller.obscure.value ? 'Show password' : 'Hide password',
                icon: Icon(
                  controller.obscure.value
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 20,
                ),
                onPressed: controller.toggleObscure,
              ),
            ),
          ),
        ),
        AppSizes.gapXl,
        Obx(
          () => FilledButton(
            onPressed: controller.isSubmitting.value ? null : controller.submit,
            child: controller.isSubmitting.value
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : const Text('Sign in'),
          ),
        ),
        AppSizes.gapLg,
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.key_outlined, size: 15, color: context.palette.inkSubtle),
            AppSizes.gapSm,
            Expanded(
              child: Text(
                'There is no self-service password reset — an administrator '
                'has to set a new one.',
                style: AppTextStyles.caption
                    .copyWith(color: context.palette.inkSubtle),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LocalOnlyNotice extends StatelessWidget {
  const _LocalOnlyNotice();

  @override
  Widget build(BuildContext context) {
    // Not a mode the app can run in — a build that was compiled without a
    // server address. Saying so plainly beats a login form that can only fail.
    return _Banner(
      icon: Icons.cloud_off_rounded,
      tone: context.palette.moneyOut,
      message: 'This build has no server address, so it cannot sign in. '
          'Rebuild with API_BASE_URL pointing at the shop server.',
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AppTextStyles.label.copyWith(color: context.palette.inkMuted),
      );
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.icon,
    required this.message,
    required this.tone,
  });

  final IconData icon;
  final String message;
  final Color tone;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: context.palette.softFor(tone),
        borderRadius: BorderRadius.circular(AppSizes.radius),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tone),
          AppSizes.gapSm,
          Expanded(
            child: Text(
              message,
              style: AppTextStyles.caption.copyWith(color: tone),
            ),
          ),
        ],
      ),
    );
  }
}
