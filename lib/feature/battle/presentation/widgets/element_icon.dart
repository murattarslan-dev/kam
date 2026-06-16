import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../domain/entities/hero_entities.dart';

String elementAssetPath(HeroElement element) => switch (element) {
      HeroElement.fire => 'assets/elements/fire.svg',
      HeroElement.water => 'assets/elements/water.svg',
      HeroElement.wind => 'assets/elements/wind.svg',
      HeroElement.steppe => 'assets/elements/steppe.svg',
      HeroElement.forest => 'assets/elements/forest.svg',
      HeroElement.dark => 'assets/elements/dark.svg',
    };

class ElementIcon extends StatelessWidget {
  final HeroElement element;
  final double size;
  const ElementIcon({super.key, required this.element, this.size = 16});

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      elementAssetPath(element),
      width: size,
      height: size,
    );
  }
}
