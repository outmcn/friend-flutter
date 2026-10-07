part of 'main.dart';

class _FigmaIcon extends StatelessWidget {
  const _FigmaIcon(this.name);
  final String name;
  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/icons/$name.svg',
        width: 22,
        height: 22,
        color: Theme.of(context).colorScheme.onSurface,
      );
}
