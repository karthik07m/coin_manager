with open('lib/providers/settings_provider.dart', 'r') as f:
    content = f.read()

content = content.replace("bool _enableNotifications = false;", "bool _enableNotifications = true;")
content = content.replace("bool _billRemindersEnabled = false;", "bool _billRemindersEnabled = true;")

content = content.replace("_enableNotifications = prefs.getBool('enableNotifications') ?? false;", "_enableNotifications = prefs.getBool('enableNotifications') ?? true;")
content = content.replace("_billRemindersEnabled = prefs.getBool('billRemindersEnabled') ?? false;", "_billRemindersEnabled = prefs.getBool('billRemindersEnabled') ?? true;")

with open('lib/providers/settings_provider.dart', 'w') as f:
    f.write(content)

print("Defaults updated.")
