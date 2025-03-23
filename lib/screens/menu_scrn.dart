import 'package:coin_manager/utilities/functions.dart';
import 'package:flutter/material.dart';

import '../utilities/constants.dart';

import 'home_scrn.dart';
import 'setting.dart';
import 'transaction_form.dart';
import 'transaction_list.dart';

class MenuScrn extends StatefulWidget {
  const MenuScrn({super.key});

  @override
  BottomNavBarState createState() => BottomNavBarState();
}

class BottomNavBarState extends State<MenuScrn> {
  int _selectedIndex = 0;

  final List<Widget> _scrns = [
    const HomePage(),
    const TransactionList(),
    const TransactionList(),
    const SettingsScreen()
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(UtilityFunction.getScreenTitle(_selectedIndex)),
      ),
      body: _scrns[_selectedIndex],
      bottomNavigationBar: BottomAppBar(
        shape: const CircularNotchedRectangle(),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: <Widget>[
            IconButton(
              icon: const Icon(Icons.home),
              color: _selectedIndex == 0 ? kPrimaryColor : Colors.grey,
              onPressed: () => _onItemTapped(0),
            ),
            IconButton(
              focusColor: Colors.blue,
              icon: const Icon(Icons.swap_horiz),
              color: _selectedIndex == 1 ? kPrimaryColor : Colors.grey,
              onPressed: () => _onItemTapped(1),
            ),
            const SizedBox(width: 40), // Adjust spacing for circular button
            IconButton(
              icon: const Icon(Icons.monetization_on),
              color: _selectedIndex == 2 ? kPrimaryColor : Colors.grey,
              onPressed: () => _onItemTapped(2),
            ),
            IconButton(
              icon: const Icon(Icons.settings),
              color: _selectedIndex == 3 ? kPrimaryColor : Colors.grey,
              onPressed: () => _onItemTapped(3),
            ),
          ],
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: FloatingActionButton(
        onPressed: () =>
            Navigator.of(context).pushNamed(TransactionForm.routeName),
        tooltip: 'Add',
        child: const Icon(Icons.add),
      ),
    );
  }
}
