with open('lib/screens/onboarding_screen.dart', 'r') as f:
    content = f.read()

# Replace Theme.of(context) with Theme.of(ctx) inside _askForNotifications
target_dialog = """              decoration: BoxDecoration(
                color: Theme.of(context)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.notifications_active,
                  color: Theme.of(context).colorScheme.primary),"""

replacement_dialog = """              decoration: BoxDecoration(
                color: Theme.of(ctx)
                    .colorScheme
                    .primary
                    .withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.notifications_active,
                  color: Theme.of(ctx).colorScheme.primary),"""

content = content.replace(target_dialog, replacement_dialog)

# Move _askForNotifications up
block_ask = """    // Ask for notification permissions
    await _askForNotifications();

"""

if block_ask in content:
    content = content.replace(block_ask, "")
    
    # insert it before completeOnboarding
    target_complete = """    // Save to settings
    await settingsProvider.completeOnboarding("""
    
    replacement_complete = block_ask + target_complete
    
    content = content.replace(target_complete, replacement_complete)

with open('lib/screens/onboarding_screen.dart', 'w') as f:
    f.write(content)
print("Fix applied.")
