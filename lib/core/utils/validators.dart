class Validators {
  static String? firstName(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Introduce tu nombre';
    if (value.length < 2) return 'Nombre demasiado corto';
    return null;
  }

  static String? lastName(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Introduce tus apellidos';
    if (value.length < 2) return 'Apellidos demasiado cortos';
    return null;
  }

  static String? email(String? v) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return 'Introduce tu correo';
    final regex = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
    if (!regex.hasMatch(value)) return 'Correo no válido';
    return null;
  }

  static String? password(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Introduce tu contraseña';
    if (value.length < 8) return 'Mínimo 8 caracteres';
    final hasLetter = RegExp(r'[A-Za-z]').hasMatch(value);
    final hasNumber = RegExp(r'\d').hasMatch(value);
    if (!hasLetter || !hasNumber) return 'Usa letras y números';
    return null;
  }

  static String? confirmPassword(String? v, String original) {
    if ((v ?? '').isEmpty) return 'Repite la contraseña';
    if (v != original) return 'Las contraseñas no coinciden';
    return null;
  }
}
