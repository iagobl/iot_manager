import 'package:flutter/material.dart';

class PrimaryButton extends StatelessWidget {

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
    this.loading = false,
    this.icon,
  });
  final String text;
  final bool loading;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : Icon(icon ?? Icons.login),
        label: Text(
          loading ? 'Cargando...' : text,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
