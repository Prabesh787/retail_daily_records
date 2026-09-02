class Validators {
  Validators._();

  static String? required(String? value, [String field = 'This field']) {
    if (value == null || value.trim().isEmpty) return '$field is required';
    return null;
  }

  static String? name(String? value) {
    final req = required(value, 'Name');
    if (req != null) return req;
    if (value!.trim().length < 2) return 'Name is too short';
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null; // optional
    final digits = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 7) return 'Enter a valid phone number';
    return null;
  }

  static String? amount(String? value, {bool allowZero = false}) {
    final req = required(value, 'Amount');
    if (req != null) return req;
    final parsed = double.tryParse(value!.replaceAll(',', '').trim());
    if (parsed == null) return 'Enter a valid amount';
    if (parsed < 0) return 'Amount cannot be negative';
    if (!allowZero && parsed == 0) return 'Amount must be greater than zero';
    return null;
  }

  static String? quantity(String? value) {
    final req = required(value, 'Quantity');
    if (req != null) return req;
    final parsed = double.tryParse(value!.trim());
    if (parsed == null || parsed <= 0) return 'Enter a valid quantity';
    return null;
  }
}
