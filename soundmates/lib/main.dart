import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'colors.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class SecureStorage {
  final _storage = FlutterSecureStorage();

  Future<void> storeCredentials(String username, String password) async {
    await _storage.write(key: 'username', value: username);
    await _storage.write(key: 'password', value: password);
  }

  Future<Map<String, String>> getCredentials() async {
    String? username = await _storage.read(key: 'username');
    String? password = await _storage.read(key: 'password');
    return {'username': username ?? '', 'password': password ?? ''};
  }

  Future<void> clearCredential() async {
    await _storage.deleteAll();
  }
}

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkCredentials();
  }

  Future<void> _checkCredentials() async {
    var credentials = await SecureStorage().getCredentials();
    if (credentials['username'] != '' && credentials['password'] != '') {
      setState(() {
        _isLoggedIn = true;
      });
    }
  }

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
            onPrimary: Colors.white,
            onSecondary: Colors.white,
            onSurface: Colors.white,
            onBackground: Colors.white,
            onError: AppColors.appbackground,
            brightness: Brightness.dark,
          ),
        ),
        home: _isLoggedIn ? MyHomePage() : IndexPage(),
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
        break;
      case 1:
        page = LikedPage();
        break;
      case 2:
        page = MatchesPage();
        break;
      case 3:
        page = ProfilePage();
        break;
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

class SwipePage extends StatefulWidget {
  @override
  State<SwipePage> createState() => _SwipePageState();
}

class _SwipePageState extends State<SwipePage> {
  List<Profile> profiles = [];

  @override
  void initState() {
    super.initState();
    fetchProfiles();
  }

  Future<void> fetchProfiles() async {
    final response =
        await http.get(Uri.parse('https://yourserver.com/get_profiles_swipe'));
    List<dynamic> profileJson = json.decode(response.body)['results'];
    setState(() {
      profiles = profileJson.map((json) => Profile.fromJson(json)).toList();
    });
    if (response.statusCode == 200) {
    } else {
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children:
          profiles.map((profile) => ProfileWidget(profile: profile)).toList(),
    );
  }
}

class LikedPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(children: [
        Padding(
            padding: EdgeInsets.fromLTRB(8, 0, 0, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Liked You:',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  )),
            )),
        MatchBox(),
        MatchBox(),
        MatchBox(),
      ]),
    );
  }
}

class MatchesPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(children: [
        Padding(
            padding: EdgeInsets.fromLTRB(8, 0, 0, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Matches',
                  style: TextStyle(
                    fontFamily: 'Roboto',
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  )),
            )),
        NewMatchBox(),
        MatchBox(),
        MatchBox(),
        MatchBox(),
        MatchBox(),
        MatchBox(),
        MatchBox(),
        MatchBox(),
      ]),
    );
  }
}

class ProfilePage extends StatelessWidget {
  final List<Pair<String, String>> myinfo = [
    Pair('This is a test',
        "This is some longer text to see what happens. The test of course continues"),
    Pair('This is the second box',
        "This is some longer text to see what happens. The test of course continues"),
  ];

  void showBoxPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CustomBoxDialog();
      },
    );
  }

  void showSocialPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CustomSocialDialog();
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          ProfileTopBox(),
          ProfilePicturesBox(),
          Align(
            alignment: Alignment.topRight,
            child: ElevatedButton(
              onPressed: () => showBoxPopup(context),
              style: ElevatedButton.styleFrom(
                shape: CircleBorder(),
                backgroundColor: Theme.of(context).colorScheme.surface,
              ),
              child: Icon(Icons.add),
            ),
          ),
          Column(
            children: myinfo
                .map((pair) => Infobox(title: pair.first, content: pair.second))
                .toList(),
          ),
          ElevatedButton(
            onPressed: () => showSocialPopup(context),
            child: Text('Manage Socials'),
          ),
          // This is a temporary button for testing
          ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => IndexPage()),
              );
            },
            child: Text('Go to index'),
          ),
        ],
      ),
    );
  }
}

class AppBarWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 5),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.background,
        ),
        //backgroundColor: Theme.of(context).colorScheme.background,
        child: Center(
          child: Text('Soundmates',
              style: TextStyle(
                fontFamily: 'Basic',
                fontSize: 30,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              )),
        ),
      ),
    );
  }
}

class Profile {
  final String name;
  final int age;
  final String distance;
  final String job;
  final List<String> photoUrls;
  final Pair<String, String> boxes;

  Profile(
      {required this.name,
      required this.age,
      required this.photoUrls,
      required this.distance,
      required this.job,
      required this.boxes});
}

class PhotoWidget extends StatefulWidget {
  @override
  State<PhotoWidget> createState() => _PhotoWidgetState();
}

class _PhotoWidgetState extends State<PhotoWidget> {
  final int currentPhotoIndex = 1;
  final int totalPhotos = 5;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(10, 8, 10, 20),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20), // Rounded corners
              image: DecorationImage(
                image: AssetImage('assets/images/dalle.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Colors.black.withOpacity(1)],
              ),
            ),
          ),

          Positioned(
            top: 10,
            left: 0,
            right: 0,
            child: PhotoIndicator(
              totalPhotos: totalPhotos,
              currentPhoto: currentPhotoIndex,
            ),
          ),

          // Left part - Previous Photo
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: () {
                  // Logic to go to previous photo
                },
                child: Container(
                  color: Colors.red.withOpacity(0.2), // Semi-transparent
                  width: MediaQuery.of(context).size.width * 0.3, // Half width
                ),
              ),
            ),
          ),
          // Right part - Next Photo
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: GestureDetector(
                onTap: () {
                  // Logic to go to next photo
                },
                child: Container(
                  color: Colors.red.withOpacity(0.2), // Semi-transparent
                  width: MediaQuery.of(context).size.width * 0.3, // Half width
                ),
              ),
            ),
          ),

          Positioned(
            left: 10,
            top: 480, // Change alignment to top center
            child: Text(
              'Laurel 19',
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 40,
                color: Colors.white,
              ),
            ),
          ),
          Positioned(
              left: 10,
              top: 530,
              child: Text(
                '6km',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 16,
                  color: Colors.white,
                ),
              )),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Button 1 action
                      },
                      child: Text('Reload'),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Button 2 action
                      },
                      child: Text('Reject'),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Button 3 action
                      },
                      child: Text('Like'),
                    ),
                  ),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Button 4 action
                      },
                      child: Text('SuperLike'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          Positioned(
            right: 30,
            top: 480,
            child: ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => MoreInfoPage(
                          name: 'Laurel',
                          age: 19,
                          job: 'National Academy of Dance',
                          distance: '6km')),
                );
              },
              child: Text('More Info'),
            ),
          ),
        ],
      ),
    );
  }
}

class PhotoIndicator extends StatelessWidget {
  final int totalPhotos;
  final int currentPhoto;

  PhotoIndicator({required this.totalPhotos, required this.currentPhoto});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalPhotos, (index) {
        return Container(
          width: 300.0 / totalPhotos,
          height: 6.0,
          margin: EdgeInsets.symmetric(horizontal: 2.0),
          decoration: BoxDecoration(
            color: index == currentPhoto
                ? Theme.of(context).colorScheme.primary
                : Colors.grey,
            borderRadius: BorderRadius.circular(2.0),
          ),
        );
      }),
    );
  }
}

class MatchBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
        height: 80,
        child: Row(children: [
          Container(
            height: 80,
            width: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40), // Rounded corners
              image: DecorationImage(
                image: AssetImage('assets/images/dalle.png'),
                fit: BoxFit.cover,
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white,
                    width: 1.0,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8.0, 0, 0, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Laurel 19',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 30,
                        color: Colors.white,
                      )),
                ),
              ),
            ),
          ),
        ]));
  }
}

class NewMatchBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
        height: 80,
        child: Row(children: [
          Container(
            height: 80,
            width: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40), // Rounded corners
              image: DecorationImage(
                image: AssetImage('assets/images/dalle.png'),
                fit: BoxFit.cover,
              ),
            ),
            child: Align(
              alignment: Alignment.topRight,
              child: Container(
                height: 20,
                width: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10), // Rounded corners
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.white,
                    width: 1.0,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8.0, 0, 0, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('Laurel 19',
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 30,
                        color: Colors.white,
                      )),
                ),
              ),
            ),
          ),
        ]));
  }
}

class ProfileTopBox extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 5, 5, 10),
      child: SizedBox(
          height: 80,
          child: Column(children: [
            Text('Name, Age',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 30,
                  color: Colors.white,
                )),
            Text('Job Title/School',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 20,
                  color: Colors.white,
                )),
          ])),
    );
  }
}

class ProfilePicturesBox extends StatelessWidget {
  final List<String> pictures = [
    'assets/images/dalle.png',
    'assets/images/dalle.png'
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
        width: MediaQuery.of(context).size.width,
        height: 372,
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.white,
              width: 1.0,
            ),
            bottom: BorderSide(
              color: Colors.white,
              width: 1.0,
            ),
          ),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 5, 0, 0),
            child: Row(
              children: [
                ProfilePic(pictures: pictures, currentindex: 0),
                ProfilePic(pictures: pictures, currentindex: 1),
                ProfilePic(pictures: pictures, currentindex: 2),
              ],
            ),
          ),
          Row(
            children: [
              ProfilePic(pictures: pictures, currentindex: 3),
              ProfilePic(pictures: pictures, currentindex: 4),
              ProfilePic(pictures: pictures, currentindex: 5),
            ],
          ),
        ]));
  }
}

class ProfilePic extends StatelessWidget {
  final List<String> pictures;
  final int currentindex;

  ProfilePic({required this.pictures, required this.currentindex});

  @override
  Widget build(BuildContext context) {
    if (pictures.length - currentindex - 1 < -1) {
      print('hello $currentindex');
      return Expanded(
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: Container(
            width: 100,
            height: 170,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Colors.grey,
            ),
          ),
        ),
      );
    } else if (pictures.length - currentindex - 1 == -1) {
      print('stop $currentindex');
      return Expanded(
        child: Padding(
            padding: EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Container(
              width: 100,
              height: 170,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                image: DecorationImage(
                  image: AssetImage(
                      'assets/images/addimage.png'), // Local asset image
                  fit: BoxFit.cover,
                ),
              ),
            )),
      );
    } else {
      print('bye $currentindex');
      return Expanded(
        child: Padding(
          padding: EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: Container(
            width: 100,
            height: 170,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10), // Rounded corners
              image: DecorationImage(
                image: AssetImage(
                    pictures[currentindex]), // Replace with your network image
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      );
    }
  }
}

class Infobox extends StatelessWidget {
  final String title;
  final String content;

  Infobox({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
      child: Container(
          decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: Theme.of(context).colorScheme.surface),
          child: Padding(
              padding: EdgeInsets.fromLTRB(10, 5, 10, 10),
              child: Column(
                children: [
                  Container(
                      width: MediaQuery.of(context).size.width,
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.white,
                            width: 1.0,
                          ),
                        ),
                      ),
                      child: Text(title,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 20,
                            color: Colors.white,
                          ))),
                  SizedBox(
                    width: MediaQuery.of(context).size.width,
                    child: Text(content,
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 16,
                          color: Colors.white,
                        )),
                  ),
                ],
              ))),
    );
  }
}

class MoreInfoPage extends StatefulWidget {
  final String name;
  final int age;
  final String job;
  final String distance;

  MoreInfoPage(
      {required this.name,
      required this.age,
      required this.job,
      required this.distance});

  @override
  State<MoreInfoPage> createState() => _MoreInfoPageState();
}

class _MoreInfoPageState extends State<MoreInfoPage> {
  var selectedIndex = 0;

  final List<Pair<String, String>> info = [
    Pair('What I\'m looking for', 'Something serious, but open for casual'),
    Pair('My Favourite Band', 'My Chemical Romance'),
    Pair('My Hobbies', 'Singing\nDancing\nKick Boxing\nCrossfit'),
    Pair('Song stuck in my head', 'Cigarette Daydreams\n-Cage the Elephant'),
    Pair('An interesting fact about me',
        'I discovered I am afraid of heights on my 18th birthday when I went skydiving'),
    Pair('My green flag', 'We can spar together'),
    Pair('My red flag', 'I’ll win'),
    Pair('Swipe left if', 'You don’t like dogs'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SingleChildScrollView(
            child: Column(children: [
      Container(
        height: MediaQuery.of(context).size.height * 0.5,
        decoration: BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/dalle.png'),
            fit: BoxFit.cover,
          ),
        ),
      ),
      Container(
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.white,
              width: 1.0,
            ),
          ),
        ),
        child: Row(children: [
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("${widget.name} ${widget.age}",
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 30,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.left),
                  Text(widget.job,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 20,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.left),
                  Text(widget.distance,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 16,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.left),
                ],
              ),
            ),
          ),
          ElevatedButton(
              onPressed: () {
                Navigator.pop(context,
                    MaterialPageRoute(builder: (context) => MyHomePage()));
              },
              child: Icon(Icons.arrow_downward))
        ]),
      ),
      Column(
        children: info
            .map((pair) => Infobox(title: pair.first, content: pair.second))
            .toList(),
      ),
    ])));
  }
}

class Pair<T, U> {
  final T first;
  final U second;

  Pair(this.first, this.second);
}

class CustomBoxDialog extends StatefulWidget {
  @override
  State<CustomBoxDialog> createState() => _CustomBoxDialogState();
}

class _CustomBoxDialogState extends State<CustomBoxDialog> {
  String userTitle = '';
  String userContent = '';
  TextEditingController textController1 = TextEditingController();
  TextEditingController textController2 = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: 150,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 1.0,
              ),
              color: Theme.of(context).colorScheme.background,
            ),
            child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
                      child: Container(
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              color: Theme.of(context).colorScheme.surface),
                          child: Padding(
                              padding: EdgeInsets.fromLTRB(10, 5, 10, 10),
                              child: Column(
                                children: [
                                  Container(
                                      width: MediaQuery.of(context).size.width,
                                      decoration: BoxDecoration(
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.white,
                                            width: 1.0,
                                          ),
                                        ),
                                      ),
                                      child: TextField(
                                        controller: textController1,
                                        decoration: InputDecoration(
                                          hintText: "Title",
                                          hintStyle: TextStyle(
                                              color: Colors.white,
                                              fontFamily: 'Roboto',
                                              fontSize: 20,
                                              fontWeight: FontWeight.normal),
                                          contentPadding: EdgeInsets.all(0),
                                          isDense: true,
                                        ),
                                        style: TextStyle(
                                          fontFamily: 'Roboto',
                                          fontSize: 20,
                                          color: Colors.white,
                                        ),
                                      )),
                                  SizedBox(
                                    width: MediaQuery.of(context).size.width,
                                    child: TextField(
                                      controller: textController2,
                                      decoration: InputDecoration(
                                          border: InputBorder.none,
                                          hintText:
                                              "Tell us something about you!!!",
                                          hintStyle: TextStyle(
                                            color: Colors.white,
                                            fontFamily: 'Roboto',
                                            fontSize: 16,
                                            fontWeight: FontWeight.normal,
                                          ),
                                          contentPadding: EdgeInsets.all(0),
                                          isDense: true),
                                      style: TextStyle(
                                        fontFamily: 'Roboto',
                                        fontSize: 16,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ],
                              ))),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(0, 0, 5, 0),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => SuggestionPanel()));
                            },
                            child: Text('Suggest'),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(5, 0, 0, 0),
                          child: ElevatedButton(
                            onPressed: () {
                              // Button 2 action
                            },
                            child: Text('Add Box'),
                          ),
                        )
                      ],
                    )
                  ],
                ))));
  }
}

class SuggestionPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Column(children: [
      AppBarWidget(),
      Padding(
          padding: EdgeInsets.fromLTRB(10, 0, 10, 0),
          child: SingleChildScrollView(
            child: Column(
              children: [
                SizedBox(
                  width: MediaQuery.of(context).size.width,
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => MyHomePage()));
                          },
                          child: Text('Back'))),
                ),
                TipBox(
                    tip:
                        'Introducing yourself can be scary! But don’t be discouraged, we’re here to help you! How about we keep it simple? Here are some suggestions!'),
                SuggestionBox(title: 'What I\'m looking for'),
                SuggestionBox(title: 'My Favourite Band'),
                SuggestionBox(title: 'My Hobbies'),
                SuggestionBox(title: 'Song stuck in my head'),
                SuggestionBox(title: 'Interesting fact'),
                SuggestionBox(title: 'Green/Red flag'),
                SuggestionBox(title: 'Swipe right/left if')
              ],
            ),
          ))
    ]));
  }
}

class TipBox extends StatelessWidget {
  final String tip;
  TipBox({required this.tip});

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: Theme.of(context).colorScheme.tertiary),
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Text(
                'Tip',
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 20,
                  fontWeight: FontWeight.normal,
                  color: Colors.black,
                ),
              ),
              Text(
                tip,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 16,
                  fontWeight: FontWeight.normal,
                  color: Colors.black,
                ),
              )
            ],
          ),
        ));
  }
}

class SuggestionBox extends StatelessWidget {
  final String title;
  SuggestionBox({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
        child: Container(
            width: MediaQuery.of(context).size.width,
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context).colorScheme.tertiary,
                  width: 1.0,
                ),
                color: Theme.of(context).colorScheme.surface),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(
                title,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 24,
                  fontWeight: FontWeight.normal,
                  color: Colors.white,
                ),
                textAlign: TextAlign.left,
              ),
            )));
  }
}

class CustomSocialDialog extends StatefulWidget {
  @override
  State<CustomSocialDialog> createState() => _CustomSocialDialogState();
}

class _CustomSocialDialogState extends State<CustomSocialDialog> {
  String socials = '';
  TextEditingController textController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: Colors.transparent,
      child: Container(
        height: 300,
        width: MediaQuery.of(context).size.width * 0.8,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            TipBox(
                tip:
                    'This is where your Matches will reach you. If you change your mind you can always change it later!'),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 10, 0, 0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 1.0,
                  ),
                  color: Theme.of(context).colorScheme.background,
                ),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 4, // 30% of space
                        child: Container(
                          height: 150,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            image: DecorationImage(
                              image: AssetImage('assets/images/dalle.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 6, // 70% of space
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8.0, 0, 0, 0),
                          child: TextField(
                            controller: textController,
                            decoration: InputDecoration(
                              hintText: 'Add your socials here!',
                              hintStyle: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Roboto',
                                fontSize: 16,
                                fontWeight: FontWeight.normal,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.all(0),
                              isDense: true,
                            ),
                            maxLines: 5,
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 16,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class IndexPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Soundmates'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SignUpPage()),
                );
              },
              child: Text('Sign Up'),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              },
              child: Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

class SignUpPage extends StatefulWidget {
  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController ageController = TextEditingController();
  String? selectedGender;
  String? selectedPreferredGender;

  Future<String?> sendDataToServer() async {
    if (1 + 1 == 2) return null;
    try {
      var response = await http.post(
        Uri.parse('https://yourserver.com/signup'),
        body: {
          'username': usernameController.text,
          'password': passwordController.text,
          'email': emailController.text,
          'age': ageController.text,
          'gender': selectedGender,
          'preferredGender': selectedPreferredGender,
        },
      );

      if (response.statusCode == 200) {
        SecureStorage()
            .storeCredentials(usernameController.text, passwordController.text);
        return null;
      } else {
        // Error occurred
        return response.body;
      }
    } catch (e) {
      // Exception handling
      print('Error sending data: $e');
      return 'Error sending data';
    }
  }

  @override
  Widget build(BuildContext context) {
    try {
      return Scaffold(
        appBar: AppBar(
          title: Text('Sign Up'),
          backgroundColor: Theme.of(context).colorScheme.primary,
        ),
        body: Container(
          margin: EdgeInsets.symmetric(
              horizontal: 20), // Add left and right margins
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.start, // Align content to the top
            children: [
              SizedBox(
                  height: 100,
                  width: MediaQuery.of(context).size.width,
                  child: Align(
                    alignment: Alignment.center,
                    child: Text('Soundmates',
                        style: TextStyle(
                          fontFamily: 'Basic',
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        )),
                  )),
              TextField(
                controller: usernameController,
                decoration: InputDecoration(
                  hintText: 'Username',
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: passwordController,
                decoration: InputDecoration(
                  hintText: 'Password',
                ),
                obscureText: true,
              ),
              SizedBox(height: 20),
              TextField(
                controller: emailController,
                decoration: InputDecoration(
                  hintText: 'Email',
                ),
              ),
              SizedBox(height: 20),
              TextField(
                controller: ageController,
                decoration: InputDecoration(
                  hintText: 'Age',
                ),
              ),
              SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedGender,
                decoration: InputDecoration(
                  hintText: 'Select Gender',
                  border: OutlineInputBorder(),
                ),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedGender = newValue;
                  });
                },
                items: <String>['Man', 'Woman', 'Non-Binary']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              SizedBox(height: 20),
              DropdownButtonFormField<String>(
                value: selectedPreferredGender,
                decoration: InputDecoration(
                  hintText: 'Select Preferred Gender',
                  border: OutlineInputBorder(),
                ),
                onChanged: (String? newValue) {
                  setState(() {
                    selectedPreferredGender = newValue;
                  });
                },
                items: <String>['Man', 'Woman', 'Any']
                    .map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () async {
                  final currentContext = context;

                  String? result = await sendDataToServer();

                  if (result == null) {
                    // check out if context is still valid
                    if (!mounted) return;

                    Navigator.pushReplacement(
                      currentContext,
                      MaterialPageRoute(
                        builder: (context) => MyHomePage(),
                      ),
                    );
                  } else {
                    if (!mounted) return;

                    // Show an alert dialog
                    showDialog(
                      context: currentContext,
                      builder: (context) {
                        return AlertDialog(
                          title: Text('Error'),
                          content: Text(result),
                          actions: <Widget>[
                            TextButton(
                              child: Text('OK'),
                              onPressed: () {
                                Navigator.of(context).pop(); // Close the dialog
                              },
                            ),
                          ],
                        );
                      },
                    );
                  }
                },
                child: Text('Sign Up'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      print('Error in GenreSelect build: $e');
      return Scaffold(
        body: Center(child: Text('Error occurred')),
      );
    }
  }
}

class LoginPage extends StatefulWidget {
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController usernameController = TextEditingController();

  final TextEditingController passwordController = TextEditingController();

  Future<String?> sendDataToServer() async {
    if (1 + 1 == 2) return null;
    try {
      var response = await http.post(
        Uri.parse('https://yourserver.com/login'),
        body: {
          'username': usernameController.text,
          'password': passwordController.text,
        },
      );

      if (response.statusCode == 200) {
        SecureStorage()
            .storeCredentials(usernameController.text, passwordController.text);
        return null;
      } else {
        // Error occurred
        return response.body;
      }
    } catch (e) {
      // Exception handling
      print('Error sending data: $e');
      return 'Error sending data';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Login'),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
      body: Container(
        margin:
            EdgeInsets.symmetric(horizontal: 20), // Add left and right margins
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.start, // Align content to the top
          children: [
            SizedBox(
              height: 100,
              width: MediaQuery.of(context).size.width,
            ),
            SizedBox(
                height: 100,
                width: MediaQuery.of(context).size.width,
                child: Align(
                  alignment: Alignment.center,
                  child: Text('Soundmates',
                      style: TextStyle(
                        fontFamily: 'Basic',
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      )),
                )),
            SizedBox(
                height:
                    20), // Increase the space between the title and the text fields
            TextField(
              controller: usernameController,
              decoration: InputDecoration(
                hintText: 'Username',
              ),
            ),
            SizedBox(height: 10),
            TextField(
              controller: passwordController,
              decoration: InputDecoration(
                hintText: 'Password',
              ),
              obscureText: true,
            ),
            SizedBox(height: 50),
            ElevatedButton(
              onPressed: () async {
                final currentContext = context;

                String? result = await sendDataToServer();

                if (result == null) {
                  if (!mounted) return;

                  Navigator.pushReplacement(
                    currentContext,
                    MaterialPageRoute(
                      builder: (context) => MyHomePage(),
                    ),
                  );
                } else {
                  if (!mounted) return;

                  // Show an alert dialog
                  showDialog(
                    context: currentContext,
                    builder: (context) {
                      return AlertDialog(
                        title: Text('Error'),
                        content: Text(result),
                        actions: <Widget>[
                          TextButton(
                            child: Text('OK'),
                            onPressed: () {
                              Navigator.of(context).pop(); // Close the dialog
                            },
                          ),
                        ],
                      );
                    },
                  );
                }
              },
              child: Text('Login'),
            ),
          ],
        ),
      ),
    );
  }
}

class GenreSelect extends StatefulWidget {
  @override
  State<GenreSelect> createState() => _GenreSelectState();
}

class _GenreSelectState extends State<GenreSelect> {
  final List<String> genres = [
    'Rock',
    'Pop',
    'Hip Hop',
    'Rap',
    'Country',
    'Jazz',
    'Classical',
    'Electronic',
    'Metal',
    'R&B',
    'Reggae',
    'Folk',
    'Blues',
    'Punk',
    'Indie',
    'Soul',
    'Funk',
    'Disco',
    'Techno',
    'House',
    'EDM',
    'Dubstep',
    'Trap',
    'Drum & Bass',
    'Ambient',
    'Reggaeton',
    'Ska',
    'Gospel',
    'Latin',
    'K-Pop',
  ];

  List<String> filteredGenres = [];

  @override
  Widget build(BuildContext context) {
    print('inside or sth?');
    return Scaffold(
      appBar: AppBar(
        title: Text("Genre Selector"),
      ),
      body: Padding(
        padding: EdgeInsets.all(8.0),
        child: Column(
          children: [
            Center(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.white,
                ),
                width: MediaQuery.of(context).size.width * 0.9,
                child: SingleChildScrollView(
                  child: TypeAheadField<String>(
                    textFieldConfiguration: TextFieldConfiguration(
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Search Genre',
                        prefixIcon: Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        hintStyle: TextStyle(color: Colors.grey),
                      ),
                    ),
                    suggestionsCallback: (pattern) {
                      return genres.where((genre) {
                        return genre
                            .toLowerCase()
                            .contains(pattern.toLowerCase());
                      }).toList();
                    },
                    itemBuilder: (context, suggestion) {
                      return GestureDetector(
                        onTap: () {
                          // Handle suggestion selection here
                          print(suggestion);
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return CustomGenreAlert(genre: suggestion);
                            },
                          );
                        },
                        child: Container(
                          color: Colors.white, // Set the background color
                          child: ListTile(
                            title: Text(
                              suggestion,
                              style: TextStyle(
                                color: Colors.black, // Set the text color
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                    noItemsFoundBuilder: (context) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0),
                      child:
                          Text('No Genres Found', textAlign: TextAlign.center),
                    ),
                    onSuggestionSelected: (suggestion) {
                      // Handle suggestion selection here
                      print(suggestion);
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return CustomGenreAlert(genre: suggestion);
                        },
                      );
                    },
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            SingleChildScrollView(
                child: Column(
              children: [
                GenreBox(genre: 'Rock', percentage: 69.0),
                GenreBox(genre: 'Pop', percentage: 69.0),
                GenreBox(genre: 'Hip Hop', percentage: 69.0),
              ],
            )),
          ],
        ),
      ),
      bottomSheet: Container(
        color: Colors.transparent,
        child: Container(
          width: MediaQuery.of(context).size.width * 0.7,
          decoration:
              BoxDecoration(color: Theme.of(context).colorScheme.background),
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => MyHomePage()),
              );
            },
            child: Text('Continue'),
          ),
        ),
      ),
    );
  }
}

class CustomGenreAlert extends StatefulWidget {
  final String genre;

  const CustomGenreAlert({required this.genre});

  @override
  State<CustomGenreAlert> createState() => _CustomGenreAlertState();
}

class _CustomGenreAlertState extends State<CustomGenreAlert> {
  double _sliderValue = 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.transparent,
      contentPadding: EdgeInsets.zero,
      content: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 16, 16, 0),
              child: Text(
                widget.genre,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _sliderValue,
                    min: 0,
                    max: 100,
                    onChanged: (newValue) {
                      setState(() {
                        _sliderValue = newValue;
                      });
                    },
                  ),
                ),
                SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${_sliderValue.round()}',
                    style: TextStyle(
                        fontSize: 16,
                        color: Theme.of(context).colorScheme.primary),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            TextButton(
              onPressed: () {
                // Save the slider value here
                print('Slider value: ${_sliderValue.round()}');
                Navigator.of(context).pop();
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Text(
                  'OK',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GenreBox extends StatelessWidget {
  final String genre;
  final double percentage;

  const GenreBox({
    required this.genre,
    required this.percentage,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
      child: GestureDetector(
        onTap: () {
          // Handle suggestion selection here
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return CustomGenreAlert(genre: genre);
            },
          );
        },
        child: Container(
          height: 70,
          width: 300,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: Row(
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "$genre: \t\t ${percentage.toInt()}%",
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 5,
                right: 5,
                child: GestureDetector(
                  onTap: () {
                    // Handle the tap on the close button
                    print('Close button tapped');
                  },
                  child: Icon(Icons.close, size: 20, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
