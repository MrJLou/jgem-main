// Navigation item widget for dashboard sidebar
import 'package:flutter/material.dart';

class DashboardNavigationItem extends StatelessWidget {
  final int index;
  final int selectedIndex;
  final bool isHovered;
  final IconData icon;
  final String title;
  final Map<int, bool> hoveredItems;
  final VoidCallback onTap;
  final Function(int, bool) onHover;

  const DashboardNavigationItem({
    super.key,
    required this.index,
    required this.selectedIndex,
    required this.isHovered,
    required this.icon,
    required this.title,
    required this.hoveredItems,
    required this.onTap,
    required this.onHover,
  });

  @override
  Widget build(BuildContext context) {
    final bool isSelected = selectedIndex == index;
    final bool isItemHovered = hoveredItems[index] ?? false;

    return MouseRegion(
      onEnter: (_) => onHover(index, true),
      onExit: (_) => onHover(index, false),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected
                ? Colors.teal.withAlpha(25)
                : isItemHovered
                    ? Colors.grey.withAlpha(25)
                    : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected
                ? Border.all(color: Colors.teal.withAlpha(75), width: 1)
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.teal[700] : Colors.grey[600],
                size: 24,
              ),
              if (isHovered) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.teal[700] : Colors.grey[800],
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis, // Prevent overflow
                    maxLines: 1, // Limit to single line
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
