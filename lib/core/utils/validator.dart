class AppValidator {
  AppValidator._();

  static String? required(String? value, {String? fieldName}) {
    if (value == null || value.trim().isEmpty) {
      return '${fieldName ?? 'Field'} wajib diisi';
    }
    return null;
  }

  static String? email(String? value) {
    final text = value?.trim() ?? '';

    if (text.isEmpty) {
      return 'Email wajib diisi';
    }

    final emailRegex =
        RegExp(r'^[\w.-]+@([\w-]+\.)+[a-zA-Z]{2,}$');

    if (!emailRegex.hasMatch(text)) {
      return 'Format email tidak valid';
    }

    return null;
  }

  static String? password(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password wajib diisi';
    }
    if (value.length < 8) {
      return 'Password minimal 8 karakter';
    }
    return null;
  }

  static String? confirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Konfirmasi password wajib diisi';
    }
    if (value != password) {
      return 'Password tidak cocok';
    }
    return null;
  }

  static String? jumlah(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Jumlah wajib diisi';
    }
    final parsed = double.tryParse(value.trim().replaceAll(',', '.'));
    if (parsed == null) {
      return 'Jumlah harus berupa angka';
    }
    if (parsed <= 0) {
      return 'Jumlah harus lebih dari 0';
    }
    return null;
  }

  static String? harga(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Harga wajib diisi';
    }
    final parsed = double.tryParse(value.trim().replaceAll('.', '').replaceAll(',', '.'));
    if (parsed == null) {
      return 'Harga harus berupa angka';
    }
    if (parsed < 0) {
      return 'Harga tidak boleh negatif';
    }
    return null;
  }

  static String? tanggal(DateTime? value) {
    if (value == null) {
      return 'Tanggal wajib diisi';
    }
    if (value.isAfter(DateTime.now())) {
      return 'Tanggal tidak boleh melebihi hari ini';
    }
    return null;
  }

  static String? phone(String? value) {
    if (value == null || value.trim().isEmpty) return null; // opsional
    final phoneRegex = RegExp(r'^[0-9]{9,13}$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return 'Format nomor HP tidak valid';
    }
    return null;
  }
}