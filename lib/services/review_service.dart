import 'package:in_app_review/in_app_review.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ReviewService {
  static final ReviewService instance = ReviewService._internal();

  ReviewService._internal();

  final InAppReview _inAppReview = InAppReview.instance;

  static const String _keyActionCount = 'review_action_count';
  static const String _keyHasPrompted = 'review_has_prompted';
  static const String _keyLastPromptTime = 'review_last_prompt_time';

  /// Number of significant actions (e.g. transactions added) required before asking for a review
  static const int _actionThreshold = 5;

  /// The minimum time to wait before prompting again if the user didn't review
  static const Duration _cooldownPeriod = Duration(days: 14);

  /// Call this when the user performs a valuable action (like saving a transaction)
  Future<void> registerSignificantEvent() async {
    final prefs = await SharedPreferences.getInstance();

    final hasPrompted = prefs.getBool(_keyHasPrompted) ?? false;
    final lastPromptTimeMs = prefs.getInt(_keyLastPromptTime) ?? 0;

    int currentCount = prefs.getInt(_keyActionCount) ?? 0;
    currentCount++;
    await prefs.setInt(_keyActionCount, currentCount);

    if (currentCount >= _actionThreshold) {
      bool shouldPrompt = false;

      if (!hasPrompted) {
        shouldPrompt = true;
      } else {
        final lastPromptDate =
            DateTime.fromMillisecondsSinceEpoch(lastPromptTimeMs);
        if (DateTime.now().difference(lastPromptDate) > _cooldownPeriod) {
          shouldPrompt = true;
        }
      }

      if (shouldPrompt) {
        await _requestReview();
      }
    }
  }

  Future<void> _requestReview() async {
    if (await _inAppReview.isAvailable()) {
      try {
        await _inAppReview.requestReview();

        // Update tracking data
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_keyHasPrompted, true);
        await prefs.setInt(
            _keyLastPromptTime, DateTime.now().millisecondsSinceEpoch);
        // Reset count so they aren't prompted again immediately after the cooldown
        await prefs.setInt(_keyActionCount, 0);
      } catch (e) {
        // Ignore errors, we shouldn't crash the app for a review prompt
      }
    }
  }

  /// Opens the store listing directly so the user can leave a review
  Future<void> openStoreListing() async {
    try {
      if (await _inAppReview.isAvailable()) {
        await _inAppReview.openStoreListing();
      }
    } catch (e) {
      // Ignore errors
    }
  }
}
