
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import 'gig_card.dart';
import 'swipe_view_model.dart';

class SwipeScreen extends StatelessWidget {
  const SwipeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<SwipeViewModel>();
    final gig = vm.currentGig;
    final colors = context.appColors;
    final screenWidth = MediaQuery.sizeOf(context).width;

    final horizontalPadding = screenWidth > 700 ? 32.0 : 20.0;

    return SafeArea(
      child: Column(
        children: [
          // HEADER
          Padding(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              12,
              horizontalPadding,
              14,
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.bolt_rounded,
                  size: 22,
                  color: Colors.black,
                ),
                const SizedBox(width: 6),
                Text(
                  'HUSTLELINK',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                      ),
                ),
                const SizedBox(width: 7),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.peach,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.black, width: 1.5),
                  ),
                  child: const Text(
                    'BETA',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.menu_rounded),
                  tooltip: 'Menu',
                ),
              ],
            ),
          ),

          // CATEGORY FILTERS
          SizedBox(
            height: 42,
            child: ListView.separated(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              scrollDirection: Axis.horizontal,
              itemCount: vm.categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 9),
              itemBuilder: (context, index) {
                final category = vm.categories[index];
                final selected = category == vm.selectedCategory;

                return GestureDetector(
                  onTap: () => vm.selectCategory(category),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 17,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? Colors.black : Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Colors.black,
                        width: 1.5,
                      ),
                    ),
                    child: Text(
                      category,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.black,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 12),

          // MAIN GIG AREA
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
              ),
              child: _buildGigArea(context, vm, gig),
            ),
          ),

          // ACTION BUTTONS
          if (gig != null && !vm.isLoading)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _ActionButton(
                    icon: Icons.close_rounded,
                    label: 'Pass',
                    size: 58,
                    onPressed: vm.pass,
                  ),
                  const SizedBox(width: 22),
                  _ActionButton(
                    icon: Icons.bookmark_border_rounded,
                    label: 'Save',
                    size: 58,
                    onPressed: vm.save,
                  ),
                  const SizedBox(width: 22),
                  _ActionButton(
                    icon: Icons.check_rounded,
                    label: 'Apply',
                    size: 68,
                    background: Colors.black,
                    foreground: Colors.white,
                    onPressed: vm.apply,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGigArea(
    BuildContext context,
    SwipeViewModel vm,
    dynamic gig,
  ) {
    if (vm.isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (vm.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded, size: 42),
            const SizedBox(height: 12),
            Text(
              vm.error!,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: vm.load,
              child: const Text('Try again'),
            ),
          ],
        ),
      );
    }

    if (gig == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.explore_outlined,
              size: 58,
            ),
            const SizedBox(height: 16),
            const Text(
              'No more gigs around you.',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Check back later for new opportunities.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: vm.load,
              child: const Text('Refresh gigs'),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Dismissible(
              key: ValueKey(gig.id),
              direction: DismissDirection.horizontal,
              onDismissed: (direction) {
                if (direction == DismissDirection.startToEnd) {
                  vm.apply();
                } else {
                  vm.pass();
                }
              },
              child: SizedBox(
                height: constraints.maxHeight,
                width: double.infinity,
                child: GigCard(gig: gig),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.size,
    required this.onPressed,
    this.background = Colors.white,
    this.foreground = Colors.black,
  });

  final IconData icon;
  final String label;
  final double size;
  final VoidCallback onPressed;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: background,
            shape: const CircleBorder(
              side: BorderSide(
                color: Colors.black,
                width: AppTokens.borderWidth,
              ),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(
                height: size,
                width: size,
                child: Icon(
                  icon,
                  size: size * 0.43,
                  color: foreground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
