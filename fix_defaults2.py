with open('lib/providers/settings_provider.dart', 'r') as f:
    content = f.read()

content = content.replace("bool _showHomeBudgetChart = true;", "bool _showHomeBudgetChart = false;")
content = content.replace("_showHomeBudgetChart = prefs.getBool('showHomeBudgetChart') ?? true;", "_showHomeBudgetChart = prefs.getBool('showHomeBudgetChart') ?? false;")

content = content.replace("bool _aiAssistantEnabled = false;", "bool _aiAssistantEnabled = true;")
content = content.replace("_aiAssistantEnabled = prefs.getBool('aiAssistantEnabled') ?? false;", "_aiAssistantEnabled = prefs.getBool('aiAssistantEnabled') ?? true;")

with open('lib/providers/settings_provider.dart', 'w') as f:
    f.write(content)

print("Defaults updated 2.")
