import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

class SwipePage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return PhotoWidget();
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
        ],
      ),
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
        backgroundColor:
            Colors.transparent, // Set the background color to transparent

        child: Container(
            height: 300,
            width: MediaQuery.of(context).size.width * 0.8,
            decoration: BoxDecoration(color: Colors.transparent),
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
                          color: Theme.of(context).colorScheme.background),
                      child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Row(
                            children: [
                              Container(
                                width: 100,
                                height: 130,
                                decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    image: DecorationImage(
                                        image: AssetImage(
                                            'assets/images/dalle.png'),
                                        fit: BoxFit.cover)),
                              ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(10, 0, 0, 0),
                                child: SizedBox(
                                  width: 150,
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
                                      contentPadding: EdgeInsets.all(
                                          0), // Adjust the vertical padding as needed
                                      isDense: true,
                                    ),
                                    maxLines:
                                        null, // Use as many lines as needed
                                  ),
                                ),
                              )
                            ],
                          )),
                    ))
              ],
            )));
  }
}
