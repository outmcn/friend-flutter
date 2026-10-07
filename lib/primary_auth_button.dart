part of 'main.dart';

class _PrimaryAuthButton extends StatelessWidget {
  const _PrimaryAuthButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: 52,
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          child: Text(label),
        ),
      );
}
