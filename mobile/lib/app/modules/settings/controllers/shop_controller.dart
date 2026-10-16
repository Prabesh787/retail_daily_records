import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/errors/app_exception.dart';
import '../../../core/widgets/app_toast.dart';
import '../../../data/models/app_user.dart';
import '../../../services/auth_service.dart';
import '../../../services/storage_service.dart';

/// The shop's own details — what goes on its paperwork.
///
/// They belong to the account, so the server owns them and they follow the
/// shopkeeper onto a second device. The currency symbol is the exception: it is
/// how this phone draws an amount, not a fact about the business, so it stays
/// here.
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

    final shop = _auth.shop;
    name.text = shop.name ?? '';
    phone.text = shop.phone ?? '';
    address.text = shop.address ?? '';
    pan.text = shop.pan ?? '';
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
      await _auth.updateShop(
        Shop(
          name: name.text.trim(),
          phone: _trimmed(phone),
          address: _trimmed(address),
          pan: _trimmed(pan),
        ),
      );

      // Written only once the server has taken the rest, so the two halves of
      // this form never end up half-saved.
      _storage.currencySymbol =
          currency.text.trim().isEmpty ? 'Rs.' : currency.text.trim();

      AppToast.success('Shop details saved');
      Get.back<void>();
    } on AppException catch (e) {
      AppToast.error(e.message);
    } catch (e) {
      AppToast.error('Could not save the shop details. $e');
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
