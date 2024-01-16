import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'colors.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:geolocator/geolocator.dart';
import 'package:oauth2_client/spotify_oauth2_client.dart';
import 'config.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http_parser/http_parser.dart';
import 'dart:io';

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

  Future<void> storeLocation(Position position) async {
    String positionString = position.toString(); // Convert position to string
    await _storage.write(key: 'position', value: positionString);
  }

  Future<Position> getLocation() async {
    String? positionString = await _storage.read(key: 'position');

    if (positionString == null) {
      return Future.error('No saved position found');
    }
    Map<String, dynamic> positionMap = jsonDecode(positionString);

    Position position = Position.fromMap(positionMap);

    return position;
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
  bool _isFirstLoad = true;

  @override
  void initState() {
    super.initState();
    _getLocationAndSendToServer();
  }

  void _onItemTapped(int index) {
    setState(() {
      selectedIndex = index;
    });
  }

  Future<void> _getLocationAndSendToServer() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are not enabled, handle accordingly
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          // Permissions are denied, handle accordingly
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        // Permissions are permanently denied, handle accordingly
        return;
      }

      Position position = await Geolocator.getCurrentPosition();
      try {
        Position lastPosition = await SecureStorage().getLocation();
        if (lastPosition.latitude != position.latitude ||
            lastPosition.longitude != position.longitude) {
          await SecureStorage().storeLocation(position);

          await _sendLocationToServer(position);
        }
      } catch (e) {
        await SecureStorage().storeLocation(position);

        await _sendLocationToServer(position);
      }
    } catch (e) {
      // Handle exceptions
    }
  }

  Future<void> _sendLocationToServer(Position position) async {
    var credentials = await SecureStorage().getCredentials();
    var username = credentials['username'];

    await http.post(
      Uri.parse('${AppConfig.serverUrl}/api/update_location'),
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
      },
      body: jsonEncode({
        'username': username,
        'latitude': position.latitude.toString(),
        'longitude': position.longitude.toString(),
      }),
    );

    // Handle the response from the server
  }

  @override
  Widget build(BuildContext context) {
    Widget page;
    if (_isFirstLoad) {
      _getLocationAndSendToServer();
      _isFirstLoad = false;
    }

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
                icon: Icon(Icons.audiotrack_sharp),
                label: 'Swipe',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.thumb_up_rounded),
                label: 'Liked',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.favorite),
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
    var credentials = await SecureStorage().getCredentials();
    String myUsername = credentials['username'] ?? '';
    final response = await http.get(Uri.parse(
        '${AppConfig.serverUrl}/get_profiles_swipe?username=$myUsername'));

    if (response.statusCode == 200) {
      List<dynamic> profileJson = json.decode(response.body)['results'];
      setState(() {
        profiles = profileJson.map((json) => Profile.fromJson(json)).toList();
      });
      return;
    } else {
      return;
    }
  }

  void onButtonPressed(Profile profile, String buttonType) async {
    String answer = await sendDataToServer(profile, buttonType);
    if (!mounted) return;

    if (answer == '') {
      setState(() {
        profiles.remove(profile);
      });
    } else {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text('Error'),
            content: Text(answer),
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
  }

  Future<String> sendDataToServer(Profile profile, String buttonType) async {
    try {
      var credentials = await SecureStorage().getCredentials();
      String myUsername = credentials['username']!;
      String targetusername = profile.username;

      var response = await http.post(
        Uri.parse('${AppConfig.serverUrl}/api/interaction'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'username': myUsername,
          'targetusername': targetusername,
          'interaction': buttonType,
        }),
      );

      if (response.statusCode == 200) {
        return '';
      } else {
        return 'There was a small issue, please try again';
      }
    } catch (e) {
      return 'There was a small issue, please try again';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: profiles.isNotEmpty
          ? PhotoWidget(
              key: ValueKey(profiles.first.username),
              profile: profiles.first,
              onButtonPressed: onButtonPressed,
            )
          : Center(child: Text("No more profiles")),
    );
  }
}

class LikedPage extends StatefulWidget {
  @override
  State<LikedPage> createState() => _LikedPageState();
}

class _LikedPageState extends State<LikedPage> {
  List<dynamic> liked = [];

  @override
  void initState() {
    super.initState();
    fetchLiked();
  }

  Future<void> fetchLiked() async {
    try {
      var credentials = await SecureStorage().getCredentials();
      String myUsername = credentials['username'] ?? '';
      final response = await http.get(
        Uri.parse('${AppConfig.serverUrl}/api/liked').replace(queryParameters: {
          'username': myUsername,
        }),
      );
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        setState(() {
          liked = jsonData['answers'];
        });
      } else {
        if (!mounted) return;
        _showErrorDialog(context, 'Failed to load superlikes.');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(context, 'Error fetching superlikes');
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(message),
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
        for (var like in liked)
          MatchBox(
              name: like['name'],
              age: like['age'],
              photoUrl: like['photoUrl'],
              socials: like['socials']),
      ]),
    );
  }
}

class MatchesPage extends StatefulWidget {
  @override
  State<MatchesPage> createState() => _MatchesPageState();
}

class _MatchesPageState extends State<MatchesPage> {
  List<dynamic> matches = [];

  @override
  void initState() {
    super.initState();
    fetchMatches();
  }

  Future<void> fetchMatches() async {
    try {
      var credentials = await SecureStorage().getCredentials();
      String myUsername = credentials['username'] ?? '';
      final response = await http.get(
        Uri.parse('${AppConfig.serverUrl}/api/matches')
            .replace(queryParameters: {
          'username': myUsername,
        }),
      );
      if (response.statusCode == 200) {
        final jsonData = json.decode(response.body);
        setState(() {
          matches = jsonData['answers'];
        });
      } else {
        if (!mounted) return;
        _showErrorDialog(context, 'Failed to load matches.');
      }
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(context, 'Error fetching matches');
    }
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(message),
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
        for (var match in matches)
          if (match['new'] >= 1)
            NewMatchBox(
              name: match['name'],
              age: match['age'],
              photoUrl: match['photoUrl'],
              socials: match['socials'],
            )
          else
            MatchBox(
              name: match['name'],
              age: match['age'],
              photoUrl: match['photoUrl'],
              socials: match['socials'],
            ),
      ]),
    );
  }
}

class ProfilePage extends StatefulWidget {
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  List<Trio<String, String, int>> myinfo = [];

  @override
  void initState() {
    super.initState();
    fetchBoxesfromServer();
  }

  Future<void> fetchBoxesfromServer() async {
    try {
      var credentials = await SecureStorage().getCredentials();
      String myUsername = credentials['username'] ?? '';
      final response = await http.get(
        Uri.parse('${AppConfig.serverUrl}/api/infoboxes')
            .replace(queryParameters: {
          'username': myUsername,
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        setState(() {
          myinfo = data.map<Trio<String, String, int>>((item) {
            return Trio(item['title'], item['content'], item['isText']);
          }).toList();
        });
      } else {
        showAlert('we could not load your box data, please try again');
      }
    } catch (e) {
      if (!mounted) return;
      showAlert('we could not load your box data, please try again');
    }
  }

  void showAlert(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Boxes Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> refreshBoxes() async {
    await fetchBoxesfromServer();
  }

  void showBoxPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CustomBoxDialog(onBoxAdded: refreshBoxes);
      },
    );
  }

  void showAudioBoxPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CustomAudioBoxDialog(onBoxAdded: refreshBoxes);
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

  Future<void> logout() async {
    await SecureStorage().clearCredential();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => IndexPage()),
      (Route<dynamic> route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          ProfileTopBox(),
          ProfilePicturesBox(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Align(
                alignment: Alignment.topLeft,
                child: ElevatedButton(
                  onPressed: () => showBoxPopup(context),
                  style: ElevatedButton.styleFrom(
                    shape: CircleBorder(),
                    backgroundColor: Theme.of(context).colorScheme.surface,
                  ),
                  child: Icon(Icons.add),
                ),
              ),
              Align(
                alignment: Alignment.topRight,
                child: ElevatedButton(
                  onPressed: () => showAudioBoxPopup(context),
                  style: ElevatedButton.styleFrom(
                    shape: CircleBorder(),
                    backgroundColor: Theme.of(context).colorScheme.surface,
                  ),
                  child: Icon(Icons.music_note_sharp),
                ),
              ),
            ],
          ),
          Column(
            children: myinfo.map((pair) {
              return pair.third == 1
                  ? MyInfobox(
                      title: pair.first,
                      content: pair.second,
                      onDelete: () async {
                        var credentials =
                            await SecureStorage().getCredentials();
                        var username = credentials['username'];
                        try {
                          var response = await http.post(
                            Uri.parse('${AppConfig.serverUrl}/api/delete_box'),
                            headers: {
                              'Content-Type': 'application/json; charset=UTF-8',
                            },
                            body: jsonEncode({
                              'username': username,
                              'title': pair.first,
                              'content': pair.second,
                            }),
                          );
                          if (response.statusCode == 200) {
                            await refreshBoxes();
                          } else {
                            showAlert('Error deleting box');
                          }
                        } catch (e) {
                          showAlert('Error deleting box');
                        }
                      },
                    )
                  : MyAudioInfobox(
                      title: pair.first,
                      content: pair.second,
                      onDelete: () async {
                        var credentials =
                            await SecureStorage().getCredentials();
                        var username = credentials['username'];
                        try {
                          var response = await http.post(
                            Uri.parse('${AppConfig.serverUrl}/api/delete_box'),
                            headers: {
                              'Content-Type': 'application/json; charset=UTF-8',
                            },
                            body: jsonEncode({
                              'username': username,
                              'title': pair.first,
                              'content': pair.second,
                            }),
                          );
                          if (response.statusCode == 200) {
                            await refreshBoxes();
                          } else {
                            showAlert('Error deleting box');
                          }
                        } catch (e) {
                          showAlert('Error deleting box');
                        }
                      },
                    );
            }).toList(),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(6, 0, 6, 0),
                    child: GestureDetector(
                      onTap: () => showSocialPopup(context),
                      child: Container(
                        height: 50, // Set the height of the button
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text('Manage Socials',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 6),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => SpotifyorCustom()),
                        );
                      },
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text('Change Genres',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(6, 0, 6, 0),
                    child: GestureDetector(
                      onTap: logout,
                      child: Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.secondary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Text('Logout',
                              style: TextStyle(color: Colors.white)),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
      padding: const EdgeInsets.fromLTRB(0, 25, 0, 5),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.background,
        ),
        //backgroundColor: Theme.of(context).colorScheme.background,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          SizedBox(
              height: 33,
              width: 33,
              child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    decoration: BoxDecoration(
                      // Rounded corners
                      image: DecorationImage(
                        image: AssetImage('assets/icons/icon.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ))),
          Text('Soundmates',
              style: TextStyle(
                fontFamily: 'Basic',
                fontSize: 33,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              )),
        ]),
      ),
    );
  }
}

class Profile {
  final String username;
  final String name;
  final int age;
  final String distance;
  final String job;
  final List<String> photoUrls;
  final List<Trio<String, String, int>> boxes;

  Profile(
      {required this.username,
      required this.name,
      required this.age,
      required this.photoUrls,
      required this.distance,
      required this.job,
      required this.boxes});

  factory Profile.fromJson(Map<String, dynamic> json) {
    var boxesJson = json['boxes'] as List;
    List<Trio<String, String, int>> boxes = boxesJson.map((box) {
      return Trio<String, String, int>(box[0], box[1], box[2]);
    }).toList();
    var photoUrls1 = json['photoUrls'] as List;
    return Profile(
      username: json['username'],
      name: json['name'],
      age: json['age'],
      photoUrls: photoUrls1.map((url) => url.toString()).toList(),
      distance: json['distance'],
      job: json['job'],
      boxes: boxes,
    );
  }
}

class PhotoWidget extends StatefulWidget {
  final Profile profile;
  final Function(Profile, String) onButtonPressed;

  PhotoWidget({Key? key, required this.profile, required this.onButtonPressed});
  @override
  State<PhotoWidget> createState() => _PhotoWidgetState();
}

class _PhotoWidgetState extends State<PhotoWidget> {
  int currentPhotoIndex = 0;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1); // Middle page
  }

  @override
  void didUpdateWidget(PhotoWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.profile != oldWidget.profile) {
      // Reset the photo index when the profile changes
      setState(() {
        currentPhotoIndex = 0;
      });
    }
  }

  void _onPageChanged(int page) {
    if (page == 0) {
      widget.onButtonPressed(widget.profile, 'like');
      _pageController.jumpToPage(1); // Reset to middle page
    } else if (page == 2) {
      widget.onButtonPressed(widget.profile, 'reject');
      _pageController.jumpToPage(1); // Reset to middle page
    }
  }

  void _goToPreviousPhoto() {
    if (currentPhotoIndex > 0) {
      setState(() {
        currentPhotoIndex--;
      });
    }
  }

  void _goToNextPhoto() {
    if (currentPhotoIndex < widget.profile.photoUrls.length - 1) {
      setState(() {
        currentPhotoIndex++;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final totalPhotos = widget.profile.photoUrls.length;
    final profile = widget.profile;

    return PageView(
      controller: _pageController,
      onPageChanged: _onPageChanged,
      children: [
        Container(color: Colors.transparent), // Left transparent page
        Padding(
          padding: EdgeInsets.fromLTRB(10, 8, 10, 20),
          child: _buildPhotoStack(profile, totalPhotos),
        ),
        Container(color: Colors.transparent), // Right transparent page
      ],
    );
  }

  Widget _buildPhotoStack(Profile profile, int totalPhotos) {
    return Stack(
      children: [
        widget.profile.photoUrls.isNotEmpty
            ? Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20), // Rounded corners
                  image: DecorationImage(
                    image: NetworkImage(
                        widget.profile.photoUrls[currentPhotoIndex]),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            : Container(), // put a placeholder photo here
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
              onTap: _goToPreviousPhoto,
              child: Container(
                color: Colors.red.withOpacity(0), // Semi-transparent
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
              onTap: _goToNextPhoto,
              child: Container(
                color: Colors.red.withOpacity(0), // Semi-transparent
                width: MediaQuery.of(context).size.width * 0.3, // Half width
              ),
            ),
          ),
        ),

        Positioned(
          left: 10,
          top: 480, // Change alignment to top center
          child: Text(
            '${profile.name} ${profile.age}',
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
              profile.distance,
              style: TextStyle(
                fontFamily: 'Roboto',
                fontSize: 16,
                color: Colors.white,
              ),
            )),
        Positioned(
          bottom: 10,
          left: 0,
          right: 0,
          child: Container(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: Center(
                    // Center the IconButton within the Expanded widget
                    child: SizedBox(
                      width: 50, // Width of the icon
                      height: 50, // Height of the icon
                      child: IconButton(
                        icon: Image.asset('assets/icons/Retry.png'),
                        onPressed: () => widget.onButtonPressed(
                            widget.profile, 'reload'), // Button 1 action
                        iconSize: 50,
                        padding: EdgeInsets.zero, // Remove any internal padding
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    // Center the IconButton within the Expanded widget
                    child: SizedBox(
                      width: 50, // Width of the icon
                      height: 50, // Height of the icon
                      child: IconButton(
                        icon: Image.asset('assets/icons/Reject.png'),
                        onPressed: () => widget.onButtonPressed(
                            widget.profile, 'reject'), // Button 1 action
                        iconSize: 50,
                        padding: EdgeInsets.zero, // Remove any internal padding
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    // Center the IconButton within the Expanded widget
                    child: SizedBox(
                      width: 50, // Width of the icon
                      height: 50, // Height of the icon
                      child: IconButton(
                        icon: Image.asset('assets/icons/Like.png'),
                        onPressed: () => widget.onButtonPressed(
                            widget.profile, 'like'), // Button 1 action
                        iconSize: 50,
                        padding: EdgeInsets.zero, // Remove any internal padding
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: Center(
                    // Center the IconButton within the Expanded widget
                    child: SizedBox(
                      width: 50, // Width of the icon
                      height: 50, // Height of the icon
                      child: IconButton(
                        icon: Image.asset('assets/icons/Favourite.png'),
                        onPressed: () => widget.onButtonPressed(
                            widget.profile, 'superlike'), // Button 1 action
                        iconSize: 50,
                        padding: EdgeInsets.zero, // Remove any internal padding
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        Positioned(
          right: 30,
          top: 480,
          child: SizedBox(
            width: 50,
            height: 50,
            child: IconButton(
              icon: Image.asset('assets/icons/More_Info.png'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) =>
                          MoreInfoPage(profile: widget.profile)),
                );
              },
              iconSize: 50,
              padding: EdgeInsets.zero,
            ),
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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
  final String name;
  final int age;
  final String photoUrl;
  final String socials;

  MatchBox(
      {required this.name,
      required this.age,
      required this.photoUrl,
      required this.socials});

  void _showSocials(BuildContext context, String socials, String photoUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CustomMatchSocialDialog(
          socials: socials,
          photoUrl: photoUrl,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSocials(context, socials, photoUrl),
      child: SizedBox(
          height: 80,
          child: Row(children: [
            Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40), // Rounded corners
                image: DecorationImage(
                  image: NetworkImage(photoUrl),
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
                    child: Text('$name $age',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 30,
                          color: Colors.white,
                        )),
                  ),
                ),
              ),
            ),
          ])),
    );
  }
}

class NewMatchBox extends StatelessWidget {
  final String name;
  final int age;
  final String photoUrl;
  final String socials;

  NewMatchBox(
      {required this.name,
      required this.age,
      required this.photoUrl,
      required this.socials});

  void _showSocials(BuildContext context, String socials, String photoUrl) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CustomMatchSocialDialog(
          socials: socials,
          photoUrl: photoUrl,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSocials(context, socials, photoUrl),
      child: SizedBox(
          height: 80,
          child: Row(children: [
            Container(
              height: 80,
              width: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40), // Rounded corners
                image: DecorationImage(
                  image: NetworkImage(photoUrl),
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
                    child: Text('$name $age',
                        style: TextStyle(
                          fontFamily: 'Roboto',
                          fontSize: 30,
                          color: Colors.white,
                        )),
                  ),
                ),
              ),
            ),
          ])),
    );
  }
}

class ProfileTopBox extends StatefulWidget {
  @override
  State<ProfileTopBox> createState() => _ProfileTopBoxState();
}

class _ProfileTopBoxState extends State<ProfileTopBox> {
  String nameAge = '';
  String jobTitle = '';

  @override
  void initState() {
    super.initState();
    fetchDataFromServer();
  }

  void fetchDataFromServer() async {
    try {
      var credentials = await SecureStorage().getCredentials();
      String myUsername = credentials['username'] ?? '';
      var response = await http.get(
          Uri.parse('${AppConfig.serverUrl}/api/profile_data')
              .replace(queryParameters: {
        'username': myUsername,
      }));

      if (response.statusCode == 200) {
        var data = json.decode(response.body);
        setState(() {
          nameAge = data['nameAge'];
          jobTitle = data['jobTitle'];
        });
      } else {
        showAlert('We could not load your profile data, please try again');
      }
    } catch (e) {
      showAlert('We could not load your profile data, please try again');
    }
  }

  void showAlert(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Profile Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void sendDataToServer(String text, String fieldType) async {
    try {
      var credentials = await SecureStorage().getCredentials();
      String myUsername = credentials['username'] ?? '';
      var response = await http.post(
        Uri.parse('${AppConfig.serverUrl}/api/change_profile_data'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode(
            {'username': myUsername, 'fieldType': fieldType, 'text': text}),
      );

      if (response.statusCode == 200) {
        fetchDataFromServer();
      } else {
        showAlert('We could not save your profile data, please try again');
      }
    } catch (e) {
      showAlert('We could not save your profile data, please try again');
    }
  }

  void showBoxPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return CustomTopBoxDialog(onrefresh: fetchDataFromServer);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    String text1 = nameAge == '' ? 'Name, Age' : nameAge;
    String text2 = jobTitle == '' ? 'Job Title/School' : jobTitle;
    return GestureDetector(
      onTap: () {
        showBoxPopup(context);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 5, 5, 10),
        child: SizedBox(
            height: 80,
            child: Column(children: [
              Text(
                text1,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 30,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              Text(
                text2,
                style: TextStyle(
                  fontFamily: 'Roboto',
                  fontSize: 20,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
            ])),
      ),
    );
  }
}

class ProfilePicturesBox extends StatefulWidget {
  @override
  State<ProfilePicturesBox> createState() => _ProfilePicturesBoxState();
}

class _ProfilePicturesBoxState extends State<ProfilePicturesBox> {
  List<String> pictures = [];

  @override
  void initState() {
    super.initState();
    fetchPictures();
  }

  Future<void> fetchPictures() async {
    try {
      var credentials = await SecureStorage().getCredentials();
      var username = credentials['username'];
      var response = await http.get(Uri.parse(
          '${AppConfig.serverUrl}/api/get_pictures?username=$username'));

      if (response.statusCode == 200) {
        setState(() {
          pictures = List<String>.from(json.decode(response.body));
        });
      } else {
        showAlert('we could not load your pictures, please try again');
      }
    } catch (e) {
      showAlert('we could not load your pictures, please try again');
    }
  }

  void showAlert(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Pictures Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

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
              children: [0, 1, 2]
                  .map((i) => ProfilePic(
                        pictures: pictures,
                        currentindex: i,
                        onImageUpload: fetchPictures,
                      ))
                  .toList(),
            ),
          ),
          Row(
            children: [3, 4, 5]
                .map((i) => ProfilePic(
                    pictures: pictures,
                    currentindex: i,
                    onImageUpload: fetchPictures))
                .toList(),
          ),
        ]));
  }
}

class ProfilePic extends StatefulWidget {
  final List<String> pictures;
  final int currentindex;
  final Function onImageUpload;

  ProfilePic(
      {required this.pictures,
      required this.currentindex,
      required this.onImageUpload});

  @override
  State<ProfilePic> createState() => _ProfilePicState();
}

class _ProfilePicState extends State<ProfilePic> {
  final ImagePicker _picker = ImagePicker();
  XFile? _image;

  Future<void> _showImagePickerOptions() async {
    showModalBottomSheet<void>(
        context: context,
        builder: (BuildContext context) {
          return Wrap(children: <Widget>[
            ListTile(
                leading: Icon(Icons.photo_library),
                title: Text('Photo Library'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image =
                      await _picker.pickImage(source: ImageSource.gallery);
                  if (image != null) {
                    setState(() {
                      _image = image;
                    });
                  }
                }),
            ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Camera'),
                onTap: () async {
                  Navigator.pop(context);
                  final XFile? image =
                      await _picker.pickImage(source: ImageSource.camera);
                  if (image != null) {
                    setState(() {
                      _image = image;
                    });
                  }
                })
          ]);
        });
  }

  Future<void> uploadImage(String imagePath, String username) async {
    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('${AppConfig.serverUrl}/api/upload_picture'),
      );
      request.fields['username'] = username;
      request.files.add(
        await http.MultipartFile.fromPath(
          'picture',
          imagePath,
          filename: path.basename(imagePath),
        ),
      );

      var response = await request.send();

      if (response.statusCode == 200) {
        widget.onImageUpload();
      } else {
        showAlert('Failed to upload image');
      }
    } catch (e) {
      showAlert('Failed to upload image');
    }
  }

  Future<void> deleteImage(String username, String pictureUrl) async {
    try {
      var response = await http.post(
        Uri.parse('${AppConfig.serverUrl}/api/delete_picture'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'username': username,
          'picture_url': pictureUrl,
        }),
      );
      if (response.statusCode == 200) {
        widget.onImageUpload();
      } else {
        showAlert('Failed to delete image');
      }
    } catch (e) {
      showAlert('Failed to delete image');
    }
  }

  void showAlert(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Pictures Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.pictures.length - widget.currentindex - 1 < -1) {
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
    } else if (widget.pictures.length - widget.currentindex - 1 == -1) {
      return _buildAddButton(context);
    } else {
      return _buildPicture(context, widget.pictures[widget.currentindex]);
    }
  }

  Widget _buildAddButton(BuildContext context) {
    return Expanded(
      child: Padding(
          padding: EdgeInsets.fromLTRB(8, 4, 8, 4),
          child: GestureDetector(
            onTap: () async {
              _showImagePickerOptions();
              if (_image != null) {
                var credentials = await SecureStorage().getCredentials();
                var username = credentials['username'];
                uploadImage(_image!.path, username!);
              }
            },
            child: Container(
              width: 100,
              height: 170,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.grey,
              ),
              child: Icon(Icons.add),
            ),
          )),
    );
  }

  Widget _buildPicture(BuildContext context, String pictureUrl) {
    return Expanded(
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(8, 4, 8, 4),
            child: Container(
              width: 100,
              height: 170,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10), // Rounded corners
                image: DecorationImage(
                  image: NetworkImage(
                      pictureUrl), // Replace with your network image
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: () async {
                var credentials = await SecureStorage().getCredentials();
                var username = credentials['username'];
                await deleteImage(username!, pictureUrl);
                widget.onImageUpload();
              },
              child: Container(
                color: Colors.black54,
                child: Icon(
                  Icons.close,
                  size: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
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

class MyInfobox extends StatelessWidget {
  final String title;
  final String content;
  final VoidCallback onDelete;

  MyInfobox(
      {required this.title, required this.content, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
      child: Stack(
        children: [
          Container(
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
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.white),
              onPressed: onDelete,
            ),
          )
        ],
      ),
    );
  }
}

class MyAudioInfobox extends StatefulWidget {
  final String title;
  final String content;
  final VoidCallback onDelete;

  MyAudioInfobox(
      {required this.title, required this.content, required this.onDelete});

  @override
  State<MyAudioInfobox> createState() => _MyAudioInfoboxState();
}

class _MyAudioInfoboxState extends State<MyAudioInfobox> {
  final FlutterSoundPlayer _audioPlayer = FlutterSoundPlayer();
  bool _isPlaying = false;
  String? _localFilePath;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _downloadAndStoreFile(widget.content);
  }

  Future<void> _downloadAndStoreFile(String url) async {
    try {
      Uri uri = Uri.parse(url);
      List<String> segments = uri.pathSegments;
      String lastseg = segments.last;
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$lastseg');
      final response = await http.get(
          Uri.parse('${AppConfig.serverUrl}/get_audio')
              .replace(queryParameters: {
        'url': url,
      }));

      if (response.statusCode == 200) {
        await tempFile.writeAsBytes(response.bodyBytes);
        setState(() {
          _localFilePath = tempFile.path;
        });
      } else {
        print('error downloading file');
      }
    } catch (e) {
      print('error downloading file');
    }
  }

  Future<void> _initializePlayer() async {
    try {
      await _audioPlayer.openAudioSession();
      setState(() {
        _isPlaying = false;
      });
      print('player initialized');
    } catch (e) {
      print('error in initializing player');
      print(e);
    }
  }

  void _togglePlay() async {
    if (_localFilePath != null) {
      try {
        if (_isPlaying) {
          await _audioPlayer.stopPlayer();
          setState(() => _isPlaying = false);
        } else {
          await _audioPlayer.startPlayer(
            fromURI: _localFilePath,
            codec: Codec.aacMP4,
            whenFinished: () {
              setState(() => _isPlaying = false);
            },
          );
          setState(() => _isPlaying = true);
        }
      } catch (e) {
        print(e);
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.closeAudioSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 5, 10, 5),
      child: Stack(
        children: [
          Container(
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
                      child: Text(widget.title,
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 20,
                            color: Colors.white,
                          ))),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                          icon: Icon(
                            _isPlaying ? Icons.pause : Icons.play_arrow,
                            color: Colors.white,
                          ),
                          onPressed: () => _togglePlay()),
                      Expanded(
                        child: Text(
                          'Tap to play message',
                          style: TextStyle(
                            fontFamily: 'Roboto',
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: IconButton(
              icon: Icon(Icons.close, color: Colors.white),
              onPressed: widget.onDelete,
            ),
          )
        ],
      ),
    );
  }
}

class AudioInfoBox extends StatefulWidget {
  final String title;
  final String content;

  AudioInfoBox({required this.title, required this.content});

  @override
  State<AudioInfoBox> createState() => _AudioInfoBoxState();
}

class _AudioInfoBoxState extends State<AudioInfoBox> {
  final FlutterSoundPlayer _audioPlayer = FlutterSoundPlayer();

  bool _isPlaying = false;
  String? _localFilePath;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
    _downloadAndStoreFile(widget.content);
  }

  Future<void> _downloadAndStoreFile(String url) async {
    print(url);

    try {
      Uri uri = Uri.parse(url);
      List<String> segments = uri.pathSegments;
      String lastseg = segments.last;
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$lastseg');
      final response = await http.get(
          Uri.parse('${AppConfig.serverUrl}/get_audio')
              .replace(queryParameters: {
        'url': url,
      }));

      if (response.statusCode == 200) {
        await tempFile.writeAsBytes(response.bodyBytes);
        setState(() {
          _localFilePath = tempFile.path;
        });
      } else {
        print('error downloading file');
      }
    } catch (e) {
      print('error downloading file');
    }
  }

  Future<void> _initializePlayer() async {
    try {
      await _audioPlayer.openAudioSession();
      setState(() {
        _isPlaying = false;
      });
      print('player initialized');
    } catch (e) {
      print('error in initializing player');
      print(e);
    }
  }

  void _togglePlay() async {
    if (_localFilePath != null) {
      try {
        if (_isPlaying) {
          await _audioPlayer.stopPlayer();
          setState(() => _isPlaying = false);
        } else {
          await _audioPlayer.startPlayer(
            fromURI: _localFilePath,
            codec: Codec.aacMP4,
            whenFinished: () {
              setState(() => _isPlaying = false);
            },
          );
          setState(() => _isPlaying = true);
        }
      } catch (e) {
        print(e);
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.closeAudioSession();
    super.dispose();
  }

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
                child: Text(widget.title,
                    style: TextStyle(
                      fontFamily: 'Roboto',
                      fontSize: 20,
                      color: Colors.white,
                    )),
              ),
              IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                onPressed: _togglePlay,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MoreInfoPage extends StatefulWidget {
  final Profile profile;

  MoreInfoPage({required this.profile});

  @override
  State<MoreInfoPage> createState() => _MoreInfoPageState();
}

class _MoreInfoPageState extends State<MoreInfoPage> {
  var selectedIndex = 0;
  final PageController _pageController = PageController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SingleChildScrollView(
            child: Column(children: [
      SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: PageView.builder(
            controller: _pageController,
            itemCount: widget.profile.photoUrls.length,
            itemBuilder: (context, index) {
              return Image.network(
                widget.profile.photoUrls[index],
                fit: BoxFit.cover,
              );
            },
          )),
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
                  Text("${widget.profile.name} ${widget.profile.age}",
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 30,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.left),
                  Text(widget.profile.job,
                      style: TextStyle(
                        fontFamily: 'Roboto',
                        fontSize: 20,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.left),
                  Text(widget.profile.distance,
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
          SizedBox(
            width: MediaQuery.of(context).size.width * 0.15,
            child: IconButton(
                icon: Image.asset('assets/icons/Less_Info.png'),
                onPressed: () {
                  Navigator.pop(context,
                      MaterialPageRoute(builder: (context) => MyHomePage()));
                },
                iconSize: 25,
                padding: EdgeInsets.zero),
          ),
        ]),
      ),
      Column(
        children: widget.profile.boxes.map<Widget>((pair) {
          return pair.third == 1
              ? Infobox(title: pair.first, content: pair.second)
              : AudioInfoBox(title: pair.first, content: pair.second);
        }).toList(),
      ),
    ])));
  }
}

class Pair<T, U> {
  final T first;
  final U second;

  Pair(this.first, this.second);
}

class Trio<T, U, V> {
  final T first;
  final U second;
  final V third;

  Trio(this.first, this.second, this.third);
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

// these are the starting pages

class IndexPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Soundmates'),
      ),
      body: Center(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 100, 0, 10),
              child: SizedBox(
                height: 150,
                width: 150,
                child: Align(
                  alignment: Alignment.center,
                  child: Container(
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: AssetImage('assets/icons/icon.png'),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => SignUpPage()),
                );
              },
              child: Container(
                height: 50,
                width: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: Center(
                    child: Text(
                  'Sign Up',
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                )),
              ),
            ),
            SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => LoginPage()),
                );
              },
              child: Container(
                height: 50,
                width: 250,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Theme.of(context).colorScheme.primary,
                ),
                child: Center(
                    child: Text(
                  'Login',
                  style: TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                )),
              ),
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
  final TextEditingController nameController = TextEditingController();
  String? selectedGender;
  String? selectedPreferredGender;

  Future<String?> sendDataToServer() async {
    try {
      var response = await http.post(
        Uri.parse('${AppConfig.serverUrl}/signup'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'username': usernameController.text,
          'password': passwordController.text,
          'name': nameController.text,
          'email': emailController.text,
          'age': ageController.text,
          'gender': selectedGender,
          'preferredGender': selectedPreferredGender,
        }),
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
        body: SingleChildScrollView(
          child: Container(
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
                  controller: nameController,
                  decoration: InputDecoration(
                    hintText: 'Name',
                  ),
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
                  items: <String>['Male', 'Female', 'Non-Binary']
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
                  items: <String>['Male', 'Female', 'Any']
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
                          builder: (context) => SpotifyorCustom(),
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
                                  Navigator.of(context)
                                      .pop(); // Close the dialog
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
        ),
      );
    } catch (e) {
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
    try {
      var response = await http.post(
        Uri.parse('${AppConfig.serverUrl}/login'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'username': usernameController.text,
          'password': passwordController.text,
        }),
      );

      if (response.statusCode == 200) {
        SecureStorage()
            .storeCredentials(usernameController.text, passwordController.text);
        return null;
      } else {
        return "Error sending data";
      }
    } catch (e) {
      // Exception handling
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

class SpotifyorCustom extends StatefulWidget {
  @override
  State<SpotifyorCustom> createState() => _SpotifyorCustomState();
}

class _SpotifyorCustomState extends State<SpotifyorCustom> {
  final client = SpotifyOAuth2Client(
    customUriScheme: 'com.soundmates',
    redirectUri: 'com.soundmates://callback',
  );

  Future<List<String>> authenticate() async {
    try {
      var authResp = await client.requestAuthorization(
          clientId: '79162274865743698734ad317e97304e',
          customParams: {
            'show_dialog': 'true'
          },
          scopes: [
            'user-read-private',
            'user-read-playback-state',
            'user-top-read'
          ]);

      var authCode = authResp.code;
      var accessTokenResponse = await client.requestAccessToken(
        code: authCode.toString(),
        clientId: '79162274865743698734ad317e97304e',
        clientSecret: '04735cc3cfac41d9a4d54b29a0e06a66',
      );
      return [
        accessTokenResponse.accessToken.toString(),
        accessTokenResponse.refreshToken.toString()
      ];
    } catch (e) {
      return [];
    }
  }

  Future<List<String>> topgenres(accessToken) async {
    if (accessToken == []) {
      return [];
    }

    try {
      var response = await http.get(
        Uri.parse('https://api.spotify.com/v1/me/top/artists'),
        headers: {"Authorization": 'Bearer ${accessToken[0]}'},
      );
      if (response.statusCode == 200) {
        var genres = parseGenres(json.decode(response.body));
        return genres;
      } else {
        return [];
      }
      // Parse the response and update the UI
      // Assuming you have a method to parse the JSON response to a list of playlist names
    } catch (e) {
      return [];
    }
  }

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
            GestureDetector(
              onTap: () async {
                showAlert(
                    'Spotify has yet to review our app, please use the custom option for now');
                // var credentials = await authenticate();
                // var genres = await topgenres(credentials);

                // var genreWithValue =
                //     genres.map((genre) => {genre: 69}).toList();

                // var serverres = await sendDataToServer(genreWithValue);

                // if (serverres == 'good') {
                //   if (!mounted) return;
                //   Navigator.push(
                //     context,
                //     MaterialPageRoute(builder: (context) => MyHomePage()),
                //   );
                // } else {
                // }
                // do the http request to put the genres in the database
              },
              child: Container(
                height: 50,
                width: 250,
                decoration: BoxDecoration(
                  color: Color(0xFF1ED760),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Connect with Spotify',
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => GenreSelect()),
                );
              },
              child: Container(
                height: 50,
                width: 250,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Choose my genres',
                    style: TextStyle(
                        color: Colors.black,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<String> parseGenres(Map<String, dynamic> jsonData) {
    final List<dynamic> topArtists = jsonData['items'];

    Set<String> genres = {};
    for (var artist in topArtists) {
      List<dynamic> artistGenres = artist['genres'];
      genres.addAll(artistGenres.cast<String>());
    }

    return genres.toSet().toList();
  }

  Future<String?> sendDataToServer(genreWithValue) async {
    try {
      var credentials = await SecureStorage().getCredentials();
      var username = credentials['username'];

      var response = await http.post(
        Uri.parse('${AppConfig.serverUrl}/api/update_genres'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'username': username, // idk if this is right
          'genres': genreWithValue,
        }),
      );

      if (response.statusCode == 200) {
        //SecureStorage()
        //  .storeCredentials(usernameController.text, passwordController.text);
        return 'good';
      } else {
        // Error occurred
        return 'Error sending data';
      }
    } catch (e) {
      // Exception handling
      return 'Error sending data';
    }
  }

  void showAlert(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(message),
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
}

class GenreSelect extends StatefulWidget {
  @override
  State<GenreSelect> createState() => _GenreSelectState();
}

class _GenreSelectState extends State<GenreSelect> {
  List<String> genres = [];
  Map<String, double> selectedGenres = {};
  List<String> filteredGenres = [];

  void _addGenre(String genre, double percentage) {
    setState(() {
      selectedGenres[genre] = percentage;
    });
  }

  void _removeGenre(String genre) {
    setState(() {
      selectedGenres.remove(genre);
    });
  }

  Future<List<String>> fetchGenres() async {
    try {
      final response =
          await http.get(Uri.parse('${AppConfig.serverUrl}/genres'));
      if (response.statusCode == 200) {
        var body = json.decode(response.body);
        var genresJson = body['genres'] as List;
        var genres = genresJson.map((genre) => genre.toString()).toList();
        return genres;
        //List<dynamic> genresJson = json.decode(response.body);
        //return genres.map((genre) => genre.toString()).toList();
      } else {
        throw Exception('Failed to load genres');
      }
    } catch (e) {
      return [];
    }
  }

  Future<String?> sendDataToServer(genres) async {
    try {
      var credentials = await SecureStorage().getCredentials();
      var username = credentials['username'];
      var response = await http.post(
        Uri.parse('${AppConfig.serverUrl}/api/update_genres'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: jsonEncode({
          'username': username, // idk if this is right
          'genres': selectedGenres,
        }),
      );

      if (response.statusCode == 200) {
        //SecureStorage()
        //  .storeCredentials(usernameController.text, passwordController.text);
        return 'good';
      } else {
        // Error occurred
        return 'Error sending data';
      }
    } catch (e) {
      // Exception handling
      return 'Error sending data';
    }
  }

  @override
  void initState() {
    fetchGenres().then((fetchedGenres) {
      setState(() {
        genres = fetchedGenres;
      });
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text("Genre Selector"),
      ),
      body: Column(
        children: [
          Padding(
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
                          autofocus: false,
                          style: TextStyle(color: Colors.black),
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
                              showDialog(
                                context: context,
                                builder: (BuildContext context) {
                                  return CustomGenreAlert(
                                    genre: suggestion,
                                    onSelection: _addGenre,
                                  );
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
                          child: Text('No Genres Found',
                              textAlign: TextAlign.center),
                        ),
                        onSuggestionSelected: (suggestion) {
                          // Handle suggestion selection here
                          showDialog(
                            context: context,
                            builder: (BuildContext context) {
                              return CustomGenreAlert(
                                genre: suggestion,
                                onSelection: _addGenre,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                SizedBox(
                  height: MediaQuery.of(context).size.height * 0.72,
                  child: SingleChildScrollView(
                      child: Column(
                    children: selectedGenres.entries.map((entry) {
                      return GenreBox(
                        genre: entry.key,
                        percentage: entry.value,
                        onSelection: _addGenre,
                        onDeletion: _removeGenre,
                      );
                    }).toList(),
                  )),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 8.0),
            child: GestureDetector(
              onTap: () async {
                var serverres = await sendDataToServer(selectedGenres);
                if (serverres == 'good') {
                  if (!mounted) return;
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => MyHomePage()),
                  );
                } else {}
              },
              child: Container(
                height: 50,
                width: MediaQuery.of(context).size.width * 0.7,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    'Continue',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GenreBox extends StatelessWidget {
  final String genre;
  final double percentage;
  final Function(String genre, double percentage) onSelection;
  final Function(String genre) onDeletion;

  const GenreBox({
    required this.genre,
    required this.percentage,
    required this.onSelection,
    required this.onDeletion,
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
              return CustomGenreAlert(
                genre: genre,
                onSelection: onSelection,
              );
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
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                  child: FittedBox(
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
                ),
              ),
              Positioned(
                top: 5,
                right: 5,
                child: GestureDetector(
                  onTap: () {
                    onDeletion(genre);
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

//THESE ARE THE DIALOGS

// this one has only text
class CustomMatchSocialDialog extends StatefulWidget {
  final String socials;
  final String photoUrl;

  const CustomMatchSocialDialog(
      {required this.socials, required this.photoUrl});
  @override
  State<CustomMatchSocialDialog> createState() =>
      _CustomMatchSocialDialogState();
}

class _CustomMatchSocialDialogState extends State<CustomMatchSocialDialog> {
  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: Colors.transparent,
      child: Container(
        height: 190,
        width: MediaQuery.of(context).size.width * 0.8,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
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
                              image: NetworkImage(widget.photoUrl),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 6, // 70% of space
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(8.0, 0, 0, 0),
                          child: Text(
                            widget.socials,
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

//this one has a tipbox and a textfield
class CustomSocialDialog extends StatefulWidget {
  @override
  State<CustomSocialDialog> createState() => _CustomSocialDialogState();
}

class _CustomSocialDialogState extends State<CustomSocialDialog> {
  TextEditingController textController = TextEditingController();
  String photoUrl = '';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchSocialData();
  }

  Future<void> fetchSocialData() async {
    try {
      var credentials = await SecureStorage().getCredentials();
      var username = credentials['username'];
      var response = await http.get(
          Uri.parse('${AppConfig.serverUrl}/api/mysocials?username=$username'));

      if (response.statusCode == 200) {
        var data = json.decode(response.body);

        setState(() {
          textController.text = data['socials'];
          photoUrl = data['photoUrl'];
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> sendSocialToServer() async {
    try {
      var credentials = await SecureStorage().getCredentials();
      var username = credentials['username'];

      var response = await http.post(
        Uri.parse('${AppConfig.serverUrl}/api/update_mysocials'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body:
            json.encode({'socials': textController.text, 'username': username}),
      );
      if (response.statusCode == 200) {
        return;
      } else {
        showAlert('There was an error saving your socials. Please try again.');
      }
    } catch (e) {
      showAlert('There was an error saving your socials. Please try again.');
    }
  }

  void showAlert(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(message),
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

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      backgroundColor: Colors.transparent,
      child: Container(
        height: 350,
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
                              image: NetworkImage(photoUrl),
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
            ElevatedButton(
              onPressed: () async {
                await sendSocialToServer();
                if (!mounted) return;
                Navigator.of(context).pop();
              },
              child: Text('Save'),
            )
          ],
        ),
      ),
    );
  }
}

class CustomBoxDialog extends StatefulWidget {
  final Function onBoxAdded;

  CustomBoxDialog({required this.onBoxAdded});

  @override
  State<CustomBoxDialog> createState() => _CustomBoxDialogState();
}

class _CustomBoxDialogState extends State<CustomBoxDialog> {
  TextEditingController textController1 = TextEditingController();
  TextEditingController textController2 = TextEditingController();

  Future<void> sendBoxInfoToServer() async {
    try {
      var credentials = await SecureStorage().getCredentials();
      var username = credentials['username'];
      var response = await http.post(
        Uri.parse('${AppConfig.serverUrl}/api/addbox'),
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
        },
        body: json.encode({
          'title': textController1.text,
          'content': textController2.text,
          'username': username
        }),
      );

      if (response.statusCode == 200) {
        widget.onBoxAdded();
        if (!mounted) return;
        Navigator.of(context).pop();
      } else {
        showAlert('There was an error saving that box. Please try again.');
      }
    } catch (e) {
      showAlert('There was an error saving that box. Please try again.');
    }
  }

  void showAlert(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(message),
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
                              sendBoxInfoToServer();
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

class CustomGenreAlert extends StatefulWidget {
  final String genre;
  final Function(String genre, double percentage) onSelection;

  const CustomGenreAlert({required this.genre, required this.onSelection});

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
                widget.onSelection(widget.genre, _sliderValue);
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

class CustomTopBoxDialog extends StatefulWidget {
  final Function onrefresh;

  CustomTopBoxDialog({required this.onrefresh});

  @override
  State<CustomTopBoxDialog> createState() => _CustomTopBoxDialogState();
}

class _CustomTopBoxDialogState extends State<CustomTopBoxDialog> {
  TextEditingController textController1 = TextEditingController();
  TextEditingController textController2 = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            height: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary,
                width: 1.0,
              ),
              color: Theme.of(context).colorScheme.background,
            ),
            child:
                Column(mainAxisAlignment: MainAxisAlignment.start, children: [
              SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Theme.of(context).colorScheme.surface,
                ),
                width: MediaQuery.of(context).size.width * 0.7,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextField(
                    controller: textController1,
                    decoration: InputDecoration(
                        hintText: 'Name, Age', border: InputBorder.none),
                  ),
                ),
              ),
              SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Theme.of(context).colorScheme.surface,
                ),
                width: MediaQuery.of(context).size.width * 0.7,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: TextField(
                    controller: textController2,
                    decoration: InputDecoration(
                        hintText: 'Job Title/School', border: InputBorder.none),
                  ),
                ),
              ),
              SizedBox(
                height: 10,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: Text('Cancel'),
                  ),
                  SizedBox(
                    width: 10,
                  ),
                  ElevatedButton(
                    onPressed: () async {
                      var credentials = await SecureStorage().getCredentials();
                      var username = credentials['username'];
                      var response = await http.post(
                        Uri.parse(
                            '${AppConfig.serverUrl}/api/change_profile_data'),
                        headers: {
                          'Content-Type': 'application/json; charset=UTF-8',
                        },
                        body: json.encode({
                          'NameAge': textController1.text,
                          'Job': textController2.text,
                          'username': username
                        }),
                      );
                      if (response.statusCode == 200) {
                        widget.onrefresh();
                        if (!mounted) return;
                        Navigator.of(context).pop();
                      } else {
                        showAlert(
                            'There was an error saving that box. Please try again.');
                      }
                    },
                    child: Text('Update'),
                  )
                ],
              )
            ])));
  }

  void showAlert(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Error'),
          content: Text(message),
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
}

class CustomAudioBoxDialog extends StatefulWidget {
  final Function onBoxAdded;

  CustomAudioBoxDialog({required this.onBoxAdded});

  @override
  State<CustomAudioBoxDialog> createState() => _CustomAudioBoxDialogState();
}

class _CustomAudioBoxDialogState extends State<CustomAudioBoxDialog> {
  TextEditingController textController1 = TextEditingController();
  String? _pickedFilePath;
  bool isRecording = false;
  String audioFilePath = '';
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();

  @override
  void initState() {
    super.initState();
    _initRecorder();
    _initPlayer();
  }

  Future<void> _initRecorder() async {
    await _recorder.openAudioSession();
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      return;
    }
    setState(() {});
  }

  Future<void> _initPlayer() async {
    await _player.openAudioSession();
    setState(() {});
  }

  void startRecording() async {
    var status = await Permission.microphone.status;
    if (status != PermissionStatus.granted) {
      return;
    }

    final directory = await getApplicationDocumentsDirectory();
    final String filePath =
        '${directory.path}/recorded_audio_${DateTime.now().millisecondsSinceEpoch}.aac';

    setState(() {
      isRecording = true;
      audioFilePath = filePath;
    });

    await _recorder.startRecorder(toFile: filePath);
  }

  void stopRecording() async {
    await _recorder.stopRecorder();
    setState(() {
      isRecording = false;
    });
  }

  void addBox() async {
    if (audioFilePath.isNotEmpty) {
      try {
        var credentials = await SecureStorage().getCredentials();
        var username = credentials['username'];

        var uri = Uri.parse('${AppConfig.serverUrl}/api/upload_audio');
        var request = http.MultipartRequest('POST', uri);
        request.fields['title'] = textController1.text;
        request.fields['username'] = username!;
        print("yes");
        request.files.add(await http.MultipartFile.fromPath(
          'audio',
          audioFilePath,
          contentType: MediaType('audio', 'aac'),
        ));
        print("no");
        var response = await request.send();
        if (response.statusCode == 200) {
          widget.onBoxAdded();
          if (!mounted) return;
          Navigator.of(context).pop();
        } else {
          showAlert('There was an error saving that box. Please try again.');
          print(response.statusCode);
        }
      } catch (e) {
        print(e);
        showAlert('There was an error saving that box. Please try again.');
      }
    }
  }

  void showAlert(String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Boxes Error'),
          content: Text(message),
          actions: <Widget>[
            TextButton(
              child: Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void playAudio() async {
    if (_pickedFilePath != null || audioFilePath.isNotEmpty) {
      String path = _pickedFilePath ?? audioFilePath;
      await _player.startPlayer(
        fromURI: path,
      );
    }
  }

  @override
  void dispose() {
    _recorder.closeAudioSession();
    _player.closeAudioSession();
    textController1.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        height: 180,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary,
            width: 1.0,
          ),
          color: Theme.of(context).colorScheme.background,
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10.0, 5, 10, 5),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              TextField(
                controller: textController1,
                decoration: InputDecoration(
                  hintText: 'Title',
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
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    GestureDetector(
                      onTapDown: (_) {
                        startRecording();
                      },
                      onTapUp: (_) {
                        stopRecording();
                      },
                      child: Container(
                        width: 120,
                        height: 40,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          color: isRecording
                              ? Theme.of(context).colorScheme.tertiary
                              : Theme.of(context).colorScheme.secondary,
                        ),
                        child: Center(
                          child: Text(
                            isRecording ? 'Recording...' : 'Record Audio',
                            style: TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 10),
                    if (_pickedFilePath != null || audioFilePath.isNotEmpty)
                      GestureDetector(
                        onTap: playAudio,
                        child: Container(
                          width: 120,
                          height: 40,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: Theme.of(context).colorScheme.secondary,
                          ),
                          child: Center(child: Text('Play Audio')),
                        ),
                      )
                  ],
                ),
              ),
              GestureDetector(
                onTap: addBox,
                child: Container(
                  width: 120,
                  height: 40,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  child: Center(child: Text('Add Box')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
