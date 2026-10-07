part of 'main.dart';

class _FixedCircleClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final diameter = size.shortestSide;
    final left = (size.width - diameter) / 2;
    final top = (size.height - diameter) / 2;
    return Path()..addOval(Rect.fromLTWH(left, top, diameter, diameter));
  }

  @override
  bool shouldReclip(covariant _FixedCircleClipper oldClipper) => false;
}
