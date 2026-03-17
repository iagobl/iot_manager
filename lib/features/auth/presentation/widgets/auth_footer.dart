import 'package:flutter/material.dart';

class AuthFooter extends StatelessWidget {

  const AuthFooter({
    super.key,
    required this.text,
    required this.actionText,
    required this.onTap,
  });
  final String text;
  final String actionText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(text),
        TextButton(
          onPressed: onTap,
          child: Text(actionText),
        ),
      ],
    );
  }
}