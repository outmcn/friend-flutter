part of 'main.dart';

class _AuthField extends StatelessWidget {
  const _AuthField({
    required this.label,
    required this.icon,
    this.obscureText = false,
    this.initialText,
  });
  final String label;
  final IconData icon;
  final bool obscureText;
  final String? initialText;
  @override
  Widget build(BuildContext context) => TextField(
        obscureText: obscureText,
        controller: initialText == null
            ? null
            : TextEditingController(text: initialText),
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
      );
}
