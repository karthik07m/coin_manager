import re

with open('lib/screens/onboarding_screen.dart', 'r') as f:
    content = f.read()

# The block to remove
block_to_move = """    // Save to settings
    await settingsProvider.completeOnboarding(
      income: income,
      budget: budget,
      budgetRule: _selectedBudgetRule.name,
      recurIncome: _recurIncome,
      recurBudget: true, // Always apply budget monthly
      incomeDay: _selectedIncomeDay,
    );

"""

if block_to_move in content:
    content = content.replace(block_to_move, "")
    
    # Where to insert it: right before "if (!mounted) return;" 
    # But wait, there are multiple "if (!mounted) return;" in the file.
    # We want to insert it after the budget allocations loop and before the next "if (!mounted) return;"
    
    target = """    for (var entry in _budgetAllocation.entries) {
      await monthlyBudgetProvider.setBudget(
          entry.key, currentMonth, entry.value);
    }

    if (!mounted) return;"""

    replacement = """    for (var entry in _budgetAllocation.entries) {
      await monthlyBudgetProvider.setBudget(
          entry.key, currentMonth, entry.value);
    }

""" + block_to_move + """    if (!mounted) return;"""
    
    content = content.replace(target, replacement)
    
    with open('lib/screens/onboarding_screen.dart', 'w') as f:
        f.write(content)
    print("Successfully moved completeOnboarding.")
else:
    print("Could not find the block to move.")

