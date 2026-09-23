import 'package:flutter/material.dart';

class SpaceTray extends StatelessWidget {
  final bool expanded;
  final VoidCallback onTap;
  final String detail;
  const SpaceTray({
    super.key,
    required this.expanded,
    required this.onTap,
    required this.detail,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Align(
        alignment: Alignment.center,
        child: FractionallySizedBox(
          widthFactor: .75,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            decoration: const BoxDecoration(
              color: Color(0xff303238),
              borderRadius: BorderRadius.vertical(bottom: Radius.circular(14)),
            ),
            padding: EdgeInsets.fromLTRB(16, 10, 16, expanded ? 14 : 10),
            child: expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: const [
                          Text(
                            '空间',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Spacer(),
                          Icon(
                            Icons.keyboard_arrow_up,
                            color: Colors.white70,
                            size: 20,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        detail,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: const [
                      Text(
                        '空间',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Spacer(),
                      Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white70,
                        size: 20,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}
