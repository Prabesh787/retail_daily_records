import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/widgets/app_toast.dart';
import '../../../data/models/app_user.dart';
import '../../../services/auth_service.dart';
import '../../../services/storage_service.dart';

/// The shop's own details — what goes on its paperwork.
///
/// Held in two places on purpose. The server owns them, because they belong to
/// the account and follow it onto a second device; [StorageService] keeps a
/// copy, because the app is offline-first and a statement printed on a train
/// still needs a shop name at the top.
class ShopController extends GetxController {
  final AuthService _auth = Get.find<AuthService>();
  final StorageService _storage = Get.find<StorageService>();

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  final TextEditingController name = TextEditingController();
  final TextEditingController phone = TextEditingController();
  final TextEditingController address = TextEditingController();
  final TextEditingController pan = TextEditingController();
  final TextEditingController currency = TextEditingController();

  final RxBool isSaving = false.obs;

  @override
  void onInit() {
    super.onInit();

    // The server's copy wins where it has one; the local copy fills the gaps,
    // which is what a first run offline leaves behind.
    final shop = _auth.user.value?.shop;
    name.text = shop?.name ?? _storage.shopName;
    phone.text = shop?.phone ?? _storage.shopPhone ?? '';
    address.text = shop?.address ?? _storage.shopAddress ?? '';
    pan.text = shop?.pan ?? '';
    currency.text = _storage.currencySymbol;
  }

  String? _trimmed(TextEditingController field) {
    final value = field.text.trim();
    return value.isEmpty ? null : value;
  }

  Future<void> save() async {
    if (!(formKey.currentState?.validate() ?? false)) return;
    if (isSaving.value) return;

    isSaving.value = true;
    try {
      final shop = Shop(
        name: name.text.trim(),
        phone: _trimmed(phone),
        address: _trimmed(address),
        pan: _trimmed(pan),
      );

      // Local first, and unconditionally. The push can fail — no signal, or
      // sync switched off entirely — and a shop that cannot rename itself
      // while offline would be a strange thing in an offline-first app.
      _storage
        ..shopName = shop.name!
        ..shopPhone = shop.phone
        ..shopAddress = shop.address
        ..currencySymbol = currency.text.trim().isEmpty
            ? 'Rs.'
            : currency.text.trim();

      try {
        await _auth.updateShop(shop);
        AppToast.success('Shop details saved');
      } catch (_) {
        // Deliberately not an error toast: the user's change *was* kept, and
        // the next sync will carry it up.
        AppToast.info('Saved on this device. It will go up when you sync.');
      }

      Get.back<void>();
    } finally {
      isSaving.value = false;
    }
  }

  @override
  void onClose() {
    for (final field in [name, phone, address, pan, currency]) {
      field.dispose();
    }
    super.onClose();
  }
}
