import 'package:flutter/material.dart';

String appName = "Coinly";

int defaultExpenseCat = 1;
int defaultIncomeCat = 9;

// Color Constants
class AppColors {
  // Base Colors - Deeper, richer dark theme
  static const Color background =
      Color(0xFF0F1115); // Almost black, slightly cool
  static const Color surface = Color(0xFF181B21); // Dark steel
  static const Color surfaceLight =
      Color(0xFF232830); // Lighter surface for cards

  // Accent Colors - Vibrant and Neon-ish
  static const Color primary = Color(0xFF2ECC71); // Vibrant Emerald
  static const Color secondary = Color(0xFFFFD700); // Electric Gold
  static const Color accentPurple = Color(0xFF9B59B6); // Amethyst
  static const Color accentBlue = Color(0xFF3498DB); // Bright Blue

  // Text Colors
  static const Color textPrimary = Color(0xFFFFFFFF); // Pure White
  static const Color textSecondary = Color(0xFFA1A1AA); // Cool Gray
  static const Color textTertiary = Color(0xFF52525B); // Darker Gray

  // Status Colors
  static const Color positive = Color(0xFF2ECC71); // Green
  static const Color negative = Color(0xFFFF5252); // Bright Red
  static const Color warning = Color(0xFFFFA726); // Orange

  // UI Elements
  static const Color divider = Color(0xFF27272A);
  static const Color border = Color(0xFF27272A);
}

// Dropshadows for depth
class AppShadows {
  static List<BoxShadow> get card => [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.2),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ];

  static List<BoxShadow> get floating => [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: 0.3),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ];
}

// Typography
class AppTextStyles {
  // Headings
  static const TextStyle h1 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.bold,
    letterSpacing: 0,
    height: 1.2,
  );

  static const TextStyle h2 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.3,
  );

  static const TextStyle h3 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.4,
  );

  // Body Text
  static const TextStyle bodyLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
    height: 1.5,
  );

  static const TextStyle bodyMedium = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.normal,
    letterSpacing: 0.2,
    height: 1.5,
  );

  static const TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.5,
    height: 1.4,
  );

  // Special Text
  static const TextStyle amount = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.5,
    fontFamily: 'Monospace', // Or system monospace if font not available
  );

  static const TextStyle caption = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.0,
    height: 1.3,
  );

  static const TextStyle button = TextStyle(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0,
    height: 1.25,
  );

  static const TextStyle input = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    letterSpacing: 0,
    height: 1.25,
  );
}

// Dimensions
class AppDimensions {
  // Spacing
  static const double spacing4 = 4.0;
  static const double spacing8 = 8.0;
  static const double spacing12 = 12.0;
  static const double spacing16 = 16.0;
  static const double spacing20 = 20.0;
  static const double spacing24 = 24.0;
  static const double spacing32 = 32.0;
  static const double spacing48 = 48.0;

  // Border Radius
  static const double radiusSmall = 8.0;
  static const double radiusMedium = 16.0;
  static const double radiusLarge = 24.0;
  static const double radiusExtraLarge = 32.0;

  // Elevation
  static const double elevationSmall = 2.0;
  static const double elevationMedium = 8.0;
  static const double elevationLarge = 16.0;

  // Icon Sizes
  static const double iconSmall = 18.0;
  static const double iconMedium = 24.0;
  static const double iconLarge = 32.0;

  // Component Sizes
  static const double avatarSize = 48.0;
  static const double buttonHeight =
      48.0; // Reduced from 56 for better proportions
  static const double inputHeight = 60.0;
}

// Animation Durations
class AppDurations {
  static const Duration fastest = Duration(milliseconds: 150);
  static const Duration fast = Duration(milliseconds: 250);
  static const Duration medium = Duration(milliseconds: 400);
  static const Duration slow = Duration(milliseconds: 700);
  static const Duration slowest = Duration(milliseconds: 1000);
}

/// Icons offered in the category picker, grouped by theme. Every entry is a
/// real file bundled under assets/categories/ (the whole folder is registered
/// in pubspec, so adding a filename here is all that's needed to offer it).
final List<String> categoryIcons = [
  // Money & income
  'assets/categories/salary.png',
  'assets/categories/salary2.png',
  'assets/categories/bonus.png',
  'assets/categories/money.png',
  'assets/categories/money-bag.png',
  'assets/categories/money-bag2.png',
  'assets/categories/cash-bill-dollar.png',
  'assets/categories/dollar-coin.png',
  'assets/categories/coin.png',
  'assets/categories/paper-bill.png',
  'assets/categories/wallet.png',
  'assets/categories/piggy-bank.png',
  'assets/categories/safe-box.png',
  'assets/categories/budget.png',
  'assets/categories/bank.png',
  'assets/categories/atm-machine(1).png',
  'assets/categories/credit-card.png',
  'assets/categories/stocks.png',
  'assets/categories/investment.png',
  'assets/categories/crypto.png',
  'assets/categories/exchange-arrows.png',
  'assets/categories/loan.png',
  'assets/categories/gift-card.png',
  'assets/categories/price-tag.png',
  // Bills & recurring
  'assets/categories/bill.png',
  'assets/categories/bill2.png',
  'assets/categories/bills.png',
  'assets/categories/duedate.png',
  'assets/categories/recurring.png',
  'assets/categories/subscription.png',
  'assets/categories/subscription2.png',
  'assets/categories/subscription3.png',
  'assets/categories/calendar.png',
  'assets/categories/clock.png',
  // Food & drink
  'assets/categories/food.png',
  'assets/categories/food2.png',
  'assets/categories/food3.png',
  'assets/categories/fast-food.png',
  'assets/categories/groceries.png',
  'assets/categories/fruit.png',
  'assets/categories/bread.png',
  'assets/categories/healthy-food.png',
  'assets/categories/organic-food.png',
  'assets/categories/diet.png',
  'assets/categories/pizza.png',
  'assets/categories/noodles.png',
  'assets/categories/sushi.png',
  'assets/categories/sandwich.png',
  'assets/categories/salad.png',
  'assets/categories/eggs.png',
  'assets/categories/fish.png',
  'assets/categories/cake.png',
  'assets/categories/cupcake.png',
  'assets/categories/donut.png',
  'assets/categories/cookies.png',
  'assets/categories/candy.png',
  'assets/categories/ice-cream-cup.png',
  'assets/categories/coffee.png',
  'assets/categories/coffee-cup.png',
  'assets/categories/tea.png',
  'assets/categories/bubble-tea.png',
  'assets/categories/milk.png',
  'assets/categories/orange-juice.png',
  'assets/categories/fizzy-drink.png',
  'assets/categories/water-bottle.png',
  'assets/categories/cutlery.png',
  // Transport
  'assets/categories/transport.png',
  'assets/categories/car.png',
  'assets/categories/car2.png',
  'assets/categories/car3.png',
  'assets/categories/car-key.png',
  'assets/categories/car-charging-station.png',
  'assets/categories/carwash.png',
  'assets/categories/motor-bike(1).png',
  'assets/categories/bicycle.png',
  'assets/categories/taxi(1).png',
  'assets/categories/school-bus.png',
  'assets/categories/tram.png',
  'assets/categories/locomotive.png',
  'assets/categories/plane.png',
  'assets/categories/helicopter.png',
  'assets/categories/delivery-truck.png',
  'assets/categories/fuel.png',
  'assets/categories/gas-station.png',
  'assets/categories/parking.png',
  // Shopping & personal
  'assets/categories/shopping.png',
  'assets/categories/shopping2.png',
  'assets/categories/shopping3.png',
  'assets/categories/shopping-cart.png',
  'assets/categories/dress.png',
  'assets/categories/tshirt.png',
  'assets/categories/hoodie.png',
  'assets/categories/tie.png',
  'assets/categories/high-heels.png',
  'assets/categories/sneakers.png',
  'assets/categories/watch.png',
  'assets/categories/necklace.png',
  'assets/categories/diamond.png',
  'assets/categories/makeup.png',
  'assets/categories/skincare.png',
  'assets/categories/toiletries.png',
  'assets/categories/haircut.png',
  'assets/categories/barber.png',
  // Home & utilities
  'assets/categories/house.png',
  'assets/categories/home2.png',
  'assets/categories/cottage.png',
  'assets/categories/rent.png',
  'assets/categories/furniture.png',
  'assets/categories/double-bed.png',
  'assets/categories/washing-machine.png',
  'assets/categories/cleaning.png',
  'assets/categories/water-tap.png',
  'assets/categories/socket.png',
  'assets/categories/lightning-bolt.png',
  'assets/categories/gas-valve.png',
  'assets/categories/fireplace.png',
  'assets/categories/wifi.png',
  'assets/categories/internet-globe.png',
  'assets/categories/key.png',
  'assets/categories/padlock.png',
  // Health
  'assets/categories/healthcare-and-medical.png',
  'assets/categories/dental-care.png',
  'assets/categories/multivitamin.png',
  'assets/categories/face-mask.png',
  'assets/categories/hearing-aid.png',
  'assets/categories/vision.png',
  'assets/categories/weight.png',
  // Entertainment & hobbies
  'assets/categories/entertainment.png',
  'assets/categories/gamepad.png',
  'assets/categories/portable-game-console.png',
  'assets/categories/music.png',
  'assets/categories/guitar.png',
  'assets/categories/piano.png',
  'assets/categories/headphones.png',
  'assets/categories/speaker.png',
  'assets/categories/television.png',
  'assets/categories/theatre.png',
  'assets/categories/tickets.png',
  'assets/categories/camera.png',
  'assets/categories/sports.png',
  'assets/categories/trophy.png',
  'assets/categories/chess.png',
  'assets/categories/dice.png',
  'assets/categories/bowling.png',
  'assets/categories/golf.png',
  'assets/categories/fishing-rod.png',
  // Education & work
  'assets/categories/graduation.png',
  'assets/categories/school-backpack.png',
  'assets/categories/open-book.png',
  'assets/categories/pen.png',
  'assets/categories/pencil.png',
  'assets/categories/briefcase.png',
  'assets/categories/laptop.png',
  'assets/categories/desktop-computer.png',
  'assets/categories/keyboard.png',
  'assets/categories/smartphone.png',
  'assets/categories/tablet.png',
  'assets/categories/code.png',
  'assets/categories/science.png',
  'assets/categories/idea.png',
  'assets/categories/calculator.png',
  'assets/categories/clipboard.png',
  'assets/categories/folder.png',
  // Travel & leisure
  'assets/categories/travel.png',
  'assets/categories/travel2.png',
  'assets/categories/travel3.png',
  'assets/categories/travel4.png',
  'assets/categories/beach-umbrella.png',
  'assets/categories/compass.png',
  'assets/categories/map.png',
  'assets/categories/location-pin.png',
  'assets/categories/umbrella.png',
  'assets/categories/campfire.png',
  'assets/categories/picnic.png',
  'assets/categories/telescope.png',
  // Pets
  'assets/categories/cat.png',
  'assets/categories/dog.png',
  'assets/categories/hamster.png',
  'assets/categories/pet-bowl.png',
  'assets/categories/feeding-bottle.png',
  'assets/categories/teddy-bear.png',
  // Gifts & misc
  'assets/categories/gift.png',
  'assets/categories/celebration.png',
  'assets/categories/confetti.png',
  'assets/categories/balloons.png',
  'assets/categories/christmas-tree.png',
  'assets/categories/heart.png',
  'assets/categories/favourite.png',
  'assets/categories/flower.png',
  'assets/categories/bouquet.png',
  'assets/categories/target.png',
  'assets/categories/box.png',
  'assets/categories/package.png',
  'assets/categories/envelope.png',
  'assets/categories/trash.png',
  // More food & drink
  'assets/categories/apple.png',
  'assets/categories/food-tray.png',
  'assets/categories/food4.png',
  'assets/categories/fried-egg.png',
  'assets/categories/fried-potatoes.png',
  'assets/categories/curry.png',
  'assets/categories/raw-meat.png',
  'assets/categories/shrimp.png',
  'assets/categories/spaghetti.png',
  'assets/categories/taco.png',
  'assets/categories/sauces.png',
  'assets/categories/grill.png',
  'assets/categories/chef-hat.png',
  'assets/categories/popcorn.png',
  'assets/categories/popsicle.png',
  'assets/categories/glass.png',
  'assets/categories/glass-of-water.png',
  'assets/categories/bottles.png',
  'assets/categories/pumpkin.png',
  // More transport
  'assets/categories/car(1).png',
  'assets/categories/car(2).png',
  'assets/categories/carwash2.png',
  'assets/categories/motor-bike(2).png',
  'assets/categories/taxi(2).png',
  'assets/categories/limousine.png',
  'assets/categories/gasoline.png',
  'assets/categories/flat-tire.png',
  'assets/categories/anchor.png',
  // More home, tools & utilities
  'assets/categories/cabin.png',
  'assets/categories/church.png',
  'assets/categories/lighthouse.png',
  'assets/categories/birdhouse.png',
  'assets/categories/garden-hose.png',
  'assets/categories/watering-can.png',
  'assets/categories/extinguisher.png',
  'assets/categories/flashlight.png',
  'assets/categories/battery-charge.png',
  'assets/categories/recycling.png',
  'assets/categories/gears.png',
  'assets/categories/settings.png',
  'assets/categories/mixer.png',
  'assets/categories/clothes-hanger.png',
  'assets/categories/3d-printer.png',
  // Safety
  'assets/categories/safety-helmet.png',
  'assets/categories/construction-helmet.png',
  'assets/categories/emergency-exit.png',
  // More clothing & accessories
  'assets/categories/cap.png',
  'assets/categories/cowboy-hat.png',
  'assets/categories/top-hat.png',
  'assets/categories/winter-hat.png',
  'assets/categories/hand-fan.png',
  'assets/categories/sandals.png',
  'assets/categories/feathers.png',
  'assets/categories/make-up.png',
  'assets/categories/makeup(1).png',
  'assets/categories/color-palette.png',
  // More entertainment, sports & hobbies
  'assets/categories/air-hockey.png',
  'assets/categories/ball.png',
  'assets/categories/baseball-player.png',
  'assets/categories/cricket-bat.png',
  'assets/categories/hockey-stick.png',
  'assets/categories/golf-ball.png',
  'assets/categories/snooker.png',
  'assets/categories/checker-chess-board.png',
  'assets/categories/cards.png',
  'assets/categories/kite.png',
  'assets/categories/binoculars.png',
  'assets/categories/microphone.png',
  'assets/categories/radio.png',
  'assets/categories/dvd.png',
  'assets/categories/media-content.png',
  'assets/categories/oldschool-telephone.png',
  'assets/categories/robot.png',
  'assets/categories/magic-box.png',
  'assets/categories/yarn-ball.png',
  'assets/categories/hiking-backpack.png',
  'assets/categories/snorkling.png',
  // More study, work & tech
  'assets/categories/bookshelf.png',
  'assets/categories/essay.png',
  'assets/categories/note.png',
  'assets/categories/sticky-notes.png',
  'assets/categories/magnifying-glass.png',
  'assets/categories/image.png',
  'assets/categories/charts.png',
  'assets/categories/antivirus.png',
  'assets/categories/sim-card.png',
  // Nature & weather
  'assets/categories/earth.png',
  'assets/categories/tree.png',
  'assets/categories/plant.png',
  'assets/categories/cactus.png',
  'assets/categories/coconut-tree.png',
  'assets/categories/butterfly.png',
  'assets/categories/cloudy.png',
  'assets/categories/rain.png',
  'assets/categories/rainbow.png',
  'assets/categories/snowman.png',
  // More money & flows
  'assets/categories/atm-machine(2).png',
  'assets/categories/security-box.png',
  'assets/categories/exchange-arrows-circle.png',
  'assets/categories/increase.png',
  'assets/categories/decrease.png',
  'assets/categories/reload.png',
  'assets/categories/back-undo-arrow.png',
  'assets/categories/open-email.png',
  'assets/categories/paper-ticket.png',
  // People & seasonal
  'assets/categories/user.png',
  'assets/categories/parents.png',
  'assets/categories/confetti(2).png',
  'assets/categories/house(1).png',
  'assets/categories/other.png',
];

extension TextStyleExtensions on TextStyle {
  TextStyle get uppercase => copyWith(
        fontFeatures: [
          const FontFeature.enable('smcp')
        ], // Small caps if supported
      );
}
