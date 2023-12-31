import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'colors.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) => MyAppState(),
      child: MaterialApp(
        title: 'Soundmates',
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme(
            primary: AppColors.primaryColor,
            secondary: AppColors.secondaryColor,
            tertiary: AppColors.teal,
            surface: AppColors.boxbackground,
            background: AppColors.appbackground,
            error: AppColors.reject,
            onPrimary: AppColors.appbackground,
            onSecondary: AppColors.appbackground,
            onSurface: AppColors.appbackground,
            onBackground: AppColors.appbackground,
            onError: AppColors.appbackground,
            brightness: Brightness.dark,
          ),
        ),
        home: MyHomePage(),
      ),
    );
  }
}

class MyAppState extends ChangeNotifier {}

class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;

  void _onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    Widget page;
    switch (selectedIndex) {
      case 0:
        page = SwipePage();
      case 1:
        page = LikedPage();
      case 2:
        page = MatchesPage();
      case 3:
        page = ProfilePage();
      default:
        throw UnimplementedError('no widget for $selectedIndex');
    }

    return LayoutBuilder(builder: (context, constraints) {
      return Scaffold(
          body: Column(
        children: [
          AppBarWidget(),
          Expanded(
            child: Container(
              color: Theme.of(context).colorScheme.background,
              child: page,
            ),
          ),
          BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(
                icon: Icon(Icons.notes),
                label: 'Swipe',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.favorite),
                label: 'Liked',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.chat),
                label: 'Matches',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
            currentIndex: selectedIndex,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            onTap: _onItemTapped,
          ),
        ],
      ));
    });
  }
}

class SwipePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Swipeeee'),
    );
  }
}

class LikedPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Liked'),
    );
  }
}

class MatchesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Matches'),
    );
  }
}

class ProfilePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('Profile'),
    );
  }
}

class AppBarWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Theme.of(context).colorScheme.background,
      title: Center(
        child: Text('Soundmates',
            style: TextStyle(
              fontFamily: 'Basic',
              fontSize: 30,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary,
            )),
      ),
    );
  }
}
