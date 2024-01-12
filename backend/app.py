from flask import Flask,request, jsonify
from flask_mysqldb import MySQL
from werkzeug.security import generate_password_hash, check_password_hash
import yaml
import random
import geopy.distance
from datetime import date
app = Flask(__name__)

# Configure MySQL
db = yaml.safe_load(open('soundmates.yaml'))
app.config['MYSQL_HOST'] = db['mysql_host']
app.config['MYSQL_USER'] = db['mysql_user']
app.config['MYSQL_PASSWORD'] = db['mysql_password']
app.config['MYSQL_DB'] = db['mysql_db']

mysql = MySQL(app)

# Helper function to get age from birthdate
def age(birthdate):
    today = date.today()
    age = today.year - birthdate.year - ((today.month, today.day) < (birthdate.month, birthdate.day))
    return age



# Routes
@app.route('/', methods=['GET'])
def index():
    return jsonify({'message': 'Welcome to Soundmates'})



@app.route('/get_profiles_swipe', methods=['GET'])
def swipe():
    # Get 6 users from database that are in acceptable range of user's location if cached users are not available
    # If cached users are available, return cached users
    lat = request.json['latitude']
    long = request.json['longitude']
    username = request.json['username']
    cur = mysql.connection.cursor()
    query = "SELECT user_id,gender,prefered_gender FROM user WHERE username = %s"
    cur.execute(query, (username,))
    rv = cur.fetchall()
    userID = rv[0][0]
    gender = rv[0][1]
    prefered_gender = rv[0][2]
    query =""" 
    SELECT u.username, u.age, u.name, u.job,
        (6371 * acos(
            cos(radians(%s)) 
            * cos(radians(location_lat)) 
            * cos(radians(location_long) - radians(%s)) 
            + sin(radians(%s)) 
            * sin(radians(location_lat))
        )) AS distance  
    FROM user u 
    WHERE u.username != %s 
    AND u.user_id NOT IN (
        SELECT user2_id 
        FROM soundmates.Match 
        WHERE user1_id = %s AND user2_id = u.user_id
        UNION 
        SELECT user1_id 
        FROM soundmates.Match 
        WHERE user2_id = %s AND user1_id = u.user_id
    )
    AND u.user_id NOT IN (
        SELECT liked_id 
        FROM soundmates.super_likes 
        WHERE liker_id = %s
    ) 
"""
    filter_rejected = """AND u.user_id NOT IN ( 
        SELECT user_id FROM soundmates.interaction 
        WHERE (subject_id = %s OR object_id = %s) AND (type = 'reject' OR type = 'de-facto-reject')
        )"""
    query += filter_rejected
    filter_gender = """AND u.user_id IN (SELECT user_id FROM user 
                        WHERE (prefered_gender = u.gender OR prefered_gender = 'any') 
                        AND (gender = u.prefered_gender OR u.prefered = 'any'))"""
    query += filter_gender
    filter_music = """AND u.user_id IN (SELECT user_id FROM preference
                        WHERE genre_genre_id IN (SELECT genre_genre_id FROM preference WHERE user_id = %s AND percentage >= 50) AND percentage >= 50) """
    query += filter_music
    priority_to_interactions = """ ORDER BY CASE WHEN u.user_id IN (SELECT user_id FROM soundmates.interaction WHERE subject_id = %s AND type = 'like') THEN 1 ELSE 2 END"""
    limit_by = """ LIMIT 20"""
    cur = mysql.connection.cursor()
    cur.execute(query + priority_to_interactions + limit_by, (lat, long, lat, username, userID, userID, userID, userID, userID, userID, userID))
    rv = cur.fetchall()
    if len(rv) == 0:
        cur.execute(query + limit_by, (lat, long, lat, username, userID, userID, userID, userID, userID, userID))
        rv = cur.fetchall()
    rv = [profile_swipe(x) for x in rv] 
    return rv
# Helper function
def profile_swipe(profile):
    # Get user's photos
    query = f"SELECT * FROM photo WHERE user_id = {profile[0]}"
    cur = mysql.connection.cursor()
    cur.execute(query)
    photos = cur.fetchall()
    # Get user's genres
    query = f"SELECT * FROM box WHERE user_id = {profile[0]}"
    cur.execute(query)
    box = cur.fetchall()
    cur.close()
    result = {}
    result["username"] = profile[1]
    result["age"] = age(profile[2])
    result["name"] = profile[3]
    result["distance"] = str(round(profile[-1],1)) + "km"
    result["job"] = profile[4]
    result["photoUrls"] = [x[2] for x in photos]
    result["boxes"] = [x[1] for x in box]
    return result
  
@app.route('/login', methods=['GET'])
def login():
#     # Check if user exists in database
    username = request.json['username']
    password = request.json['password']
    if username == '' or password == '':
        return jsonify({'message': 'Please enter a username and password'}), 400
    cur = mysql.connection.cursor()
    cur.execute("SELECT user_id, password FROM user WHERE username = %s", (username,))
    user = cur.fetchone()
    cur.close()

    if user and check_password_hash(user[1], password):
        return jsonify({'message': 'Login successful'}), 200
    else:
        return jsonify({'message': 'Incorrect username or password'}), 400
   
    

   

@app.route('/signup', methods=['POST'])
def signup():
    cur = mysql.connection.cursor()
    if '' in request.json.values():
        return jsonify({'message': 'Please fill out all fields'}), 400
    username = request.json['username']
    cur.execute("SELECT * FROM user WHERE username = %s", (username,))
    rv = cur.fetchall()
    if len(rv) != 0:
        return jsonify({'message': 'Username already exists'}), 400
    attr = tuple(x for x in request.json.values())
    cur.execute("""INSERT INTO user (username, password, name, email,
  birthdate, gender, preferred_gender, location_long, location_lat) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)""", attr)
    mysql.connection.commit()
    cur.close()
    return jsonify(rv)

@app.route('/profile', methods=['GET'])
def profile():
    username = request.json['username']
    cur = mysql.connection.cursor()
    cur.execute("SELECT * FROM user WHERE username = %s", (username,))
    rv = cur.fetchall()
    if len(rv) == 0:
        return jsonify({'message': 'User does not exist???'}), 400
    cur.close()
    
    return jsonify(rv)

@app.route('/get_profile', methods=['POST']) 
def update_profile():
    cur = mysql.connection.cursor()
    username = request.json['username']
    cur.execute("SELECT * FROM user WHERE username = %s", (username,))
    rv = cur.fetchall()
    if len(rv) == 0:
        return jsonify({'message': 'User does not exist'}), 400
    try:
        if 'name' in request.json:
            cur.execute("UPDATE user SET name = %s WHERE username = %s", (request.json['name'], username))
        if 'email' in request.json:
            cur.execute("UPDATE user SET email = %s WHERE username = %s", (request.json['email'], username))
        if 'birthdate' in request.json:
            cur.execute("UPDATE user SET birthdate = %s WHERE username = %s", (request.json['birthdate'], username))
        if 'prefered_gender' in request.json:
            cur.execute("UPDARE user SET prefered_gender = %s WHERE username = %s", (request.json['prefered_gender'], username))
        if 'job' in request.json:
            cur.execute("UPDATE user SET job = %s WHERE username = %s", (request.json['job'], username))
        if 'email' in request.json:
            cur.execute("UPDATE user SET email = %s WHERE username = %s", (request.json['email'], username))
        mysql.connection.commit()
        cur.close()
        return jsonify({'message': 'Profile updated successfully'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/delete_picture', methods=['POST'])
def delete_picture():
    data = request.json
    username = data.get('username')
    picture_url = data.get('picture_url')

    if not username or not picture_url:
        return jsonify({'message': 'Username and picture URL are required'}), 400

    cur = mysql.connection.cursor()
    try:
        # Delete the specified picture
        cur.execute("DELETE FROM photo WHERE photo_url = %s AND user_id = (SELECT user_id FROM user WHERE username = %s)", (picture_url, username))
        mysql.connection.commit()

        # Check if the file was actually deleted
        if cur.rowcount == 0:
            return jsonify({'message': 'Picture not found'}), 404

        # Retrieve the remaining pictures and adjust their order
        cur.execute("SELECT photo_url, `order` FROM photo WHERE user_id = (SELECT user_id FROM user WHERE username = %s) ORDER BY `order`", (username,))
        remaining_pictures = cur.fetchall()

        for idx, (url, order) in enumerate(remaining_pictures):
            new_order = idx + 1  # New order starts from 1
            if new_order != order:
                # Update the order of the picture
                cur.execute("UPDATE photo SET `order` = %s WHERE photo_url = %s AND user_id = (SELECT user_id FROM user WHERE username = %s)", (new_order, url, username))
                mysql.connection.commit()

        cur.close()
        return jsonify({'message': 'Picture deleted successfully'}), 200

    except Exception as e:
        cur.close()
        return jsonify({'error': str(e)}), 500



@app.route('/matches', methods=['GET'])
def matches():
    if 'username' not in request.json:
        return jsonify({'message': "No username given (this isn't supposed to happen)"}), 400
    username = request.json['username']
    cur = mysql.connection.cursor()
    cur.execute("SELECT user_id FROM user WHERE username = %s", (username,))
    rv = cur.fetchall()
    if len(rv) == 0:
        return jsonify({'message': 'User does not exist'}), 400
    userID = rv[0][0]
    cur.execute("""SELECT * FROM soundmates.Match WHERE user1_id = %s OR user2_id = %s""", (userID, userID))
    rv = cur.fetchall()
    if len(rv) == 0:
        return jsonify({'message': 'No matches found'}), 400
    query = ""
    results = []
    for match in rv:
        print(match)
        print(userID)
        if match[0] == userID:
            query = f"SELECT u.username, p.photo_url FROM user u JOIN photo p ON u.user_id = p.user_id WHERE u.user_id = {match[1]} LIMIT 1"
        else:
            query = f"SELECT u.username, p.photo_url FROM user u JOIN photo p ON u.user_id = p.user_id WHERE u.user_id = {match[0]} LIMIT 1"
        cur.execute(query)
        rv = cur.fetchall()
        results.append(rv)
    cur.close()
    return jsonify(results)

@app.route('/liked_you', methods=['GET'])
def liked_you():
    cur = mysql.connection.cursor()
    cur.execute("SELECT user_id FROM user WHERE username = %s", (request.json['username'],))
    userID = cur.fetchall()[0]
    cur.execute("""SELECT 
                    u.username, 
                    p.photo_url           
                    FROM 
                    soundmates.super_likes s 
                    JOIN user u ON u.user_id = s.liker_id 
                    JOIN 
                        (SELECT * FROM photo WHERE `order` IN (SELECT MIN(`order`) FROM photo GROUP BY user_id)) p 
                    ON 
                    u.user_id = p.user_id 
                    WHERE 
                    s.liked_id = %s
                    """, (userID,))
    rv = cur.fetchall()
    cur.close()
    return jsonify([{"username":x[0],"photo_url":x[1]} for x in rv])
def get_user_id():
    #query the database to get the user_id
    cursor = mysql.connection.cursor()
    cursor.execute("SELECT user_id FROM user WHERE username = %s", (request.json['username'],))
    user_id = cursor.fetchone()[0]
    cursor.close()
    return user_id


#get profile data 
@app.route('/api/profile_data', methods=['GET'])
def get_profile_data():
    # Assuming there's a way to identify the user (e.g., token, session, etc.)
    user_id = get_user_id()  # implemented earlier on 
    cur = mysql.connection.cursor()
    cur.execute("SELECT name, birthdate, job FROM user WHERE user_id = %s", (user_id,))
    profile_data = cur.fetchone()
    cur.close()

    if profile_data:
        name, birthdate, job = profile_data
        age = age(birthdate)  # this implemented earlier on 
        return jsonify({'nameAge': f'{name}, {age}', 'jobTitle': job})
    else:
        return jsonify({'message': 'Profile data not found'}), 404


#endpoint to get the user's photos

@app.route('/api/get_pictures', methods=['GET'])
def get_pictures():
    username = request.args.get('username')
    if not username:
        return jsonify({'message': 'Username is required'}), 400

    cur = mysql.connection.cursor()
    cur.execute("SELECT photo_url FROM photo WHERE user_id = (SELECT user_id FROM user WHERE username = %s)", (username,))
    photos_data = cur.fetchall()
    cur.close()

    if photos_data:
        pictures = [photo[0] for photo in photos_data]
        return jsonify(pictures)
    else:
        return jsonify({'message': 'No pictures found'}), 404

#endpoint to upload the user's photos
from werkzeug.utils import secure_filename
import os

# Configuration for file uploads
UPLOAD_FOLDER = '/path/to/upload/directory'
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}

app.config['UPLOAD_FOLDER'] = UPLOAD_FOLDER

def allowed_file(filename):
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS

@app.route('/api/upload_picture', methods=['POST'])
def upload_picture():
    if 'picture' not in request.files:
        return jsonify({'message': 'No picture part'}), 400
    file = request.files['picture']
    username = request.form.get('username')
    if not username:
        return jsonify({'message': 'Username is required'}), 400
    if file.filename == '':
        return jsonify({'message': 'No selected file'}), 400
    if file and allowed_file(file.filename):
        filename = secure_filename(file.filename)
        file_path = os.path.join(app.config['UPLOAD_FOLDER'], filename)
        file.save(file_path)

        cur = mysql.connection.cursor()

        # Get the current maximum order value
        cur.execute("SELECT MAX(`order`) FROM photo WHERE user_id = (SELECT user_id FROM user WHERE username = %s)", (username,))
        max_order_result = cur.fetchone()
        next_order = max_order_result[0] + 1 if max_order_result and max_order_result[0] is not None else 1

        # Insert the new photo with the next order value
        cur.execute("INSERT INTO photo (user_id, `order`, photo_url) VALUES ((SELECT user_id FROM user WHERE username = %s), %s, %s)", (username, next_order, file_path))
        mysql.connection.commit()
        cur.close()

        return jsonify({'message': 'File uploaded successfully'}), 200
    else:
        return jsonify({'message': 'Invalid file format'}), 400



#endpoint to get all the genres 

@app.route('/genres', methods=['GET'])
def get_genres():
    cur = mysql.connection.cursor()
    try:
        # SQL query to fetch genres
        cur.execute("SELECT genre FROM genre")
        genres_data = cur.fetchall()
        # Extracting genres from the query result
        genres = [genre[0] for genre in genres_data]
        return jsonify({'genres': genres})
    except Exception as e:
        # Handle any exceptions that occur
        return jsonify({'error': str(e)}), 500
    finally:
        cur.close()

#endpoint to update user's genres
@app.route('/api/update_genres', methods=['POST'])
def update_genres():
    data = request.json
    username = data.get('username')
    genres = data.get('genres')

    if not username or not genres:
        return jsonify({'message': 'Username and genres are required'}), 400

    cur = mysql.connection.cursor()
    try:
        # Delete all existing genres for the user
        cur.execute("DELETE FROM preference WHERE user_userid = (SELECT user_id FROM user WHERE username = %s)", (username,))
        mysql.connection.commit()
        # Insert the new genres
        for genre in genres:
            cur.execute("INSERT INTO preference (user_id, genre_genre_id, percentage) VALUES ((SELECT user_id FROM user WHERE username = %s), (SELECT genre_id FROM genre WHERE genre = %s), 69)", (username, genre))
            mysql.connection.commit()

        return jsonify({'message': 'Genres updated successfully'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        cur.close()

#endpoint to get the socials 

@app.route('/api/mysocials', methods=['GET'])
def get_socials():
    username = request.args.get('username')
    if not username:
        return jsonify({'message': 'Username is required'}), 400

    cur = mysql.connection.cursor()
    cur.execute("""
        SELECT s.social_info, p.photo_url 
        FROM socials s
        JOIN user u ON u.user_id = s.user_id
        LEFT JOIN photo p ON u.user_id = p.user_id 
        WHERE u.username = %s
        ORDER BY p.order
        LIMIT 1
    """, (username,))
    user_data = cur.fetchone()
    cur.close()

    if user_data:
        social_data = {
            'socials': user_data[0],
            'photoUrl': user_data[1]
        }
        return jsonify(social_data)
    else:
        return jsonify({'message': 'User not found'}), 404

#endpoint to update the socials 
@app.route('/api/update_mysocials', methods=['POST'])
def update_socials():
    data = request.json
    username = data.get('username')
    socials = data.get('socials')

    if not username or socials is None:
        return jsonify({'message': 'Username and socials are required'}), 400

    cur = mysql.connection.cursor()
    cur.execute("""
        UPDATE socials 
        SET social_info = %s 
        WHERE user_id = (SELECT user_id FROM user WHERE username = %s)
    """, (socials, username))
    mysql.connection.commit()
    updated_rows = cur.rowcount
    cur.close()

    if updated_rows > 0:
        return jsonify({'message': 'Social data updated successfully'}), 200
    else:
        return jsonify({'message': 'User not found'}), 404

#endpoint to add box
@app.route('/api/addbox', methods=['POST'])
def add_box():
    data = request.json
    title = data.get('title')
    content = data.get('content')
    username = data.get('username')

    if not all([title, content, username]):
        return jsonify({'message': 'Title, content, and username are required'}), 400

    cur = mysql.connection.cursor()

    # Fetching the user_id based on the username
    cur.execute("SELECT user_id FROM user WHERE username = %s", (username,))
    user_id_result = cur.fetchone()

    if user_id_result:
        user_id = user_id_result[0]
        # Inserting the new box into the database
        cur.execute("INSERT INTO box (user_id, title, description) VALUES (%s, %s, %s)", (user_id, title, content))
        mysql.connection.commit()
        cur.close()
        return jsonify({'message': 'Box added successfully'}), 201
    else:
        cur.close()
        return jsonify({'message': 'User not found'}), 404

#update location endpoint 
@app.route('/api/update_location', methods=['POST'])
def update_location():
    data = request.json
    username = data.get('username')
    latitude = data.get('latitude')
    longitude = data.get('longitude')

    if not all([username, latitude, longitude]):
        return jsonify({'message': 'Username, latitude, and longitude are required'}), 400

    cur = mysql.connection.cursor()
    try:
        cur.execute("UPDATE user SET location_lat = %s, location_long = %s WHERE username = %s", (latitude, longitude, username))
        mysql.connection.commit()
        return jsonify({'message': 'Location updated successfully'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        cur.close()

#interaction endpoint 
@app.route('/api/interaction', methods=['POST'])
def user_interaction():
    data = request.json
    username = data.get('username')
    target_username = data.get('targetusername')
    interaction_type = data.get('interaction')

    if not all([username, target_username, interaction_type]):
        return jsonify({'message': 'All fields are required'}), 400

    cur = mysql.connection.cursor()
    try:
        # Assuming there's a table to store interactions (like 'interaction')
        # and it has columns for storing the user_id of the acting user,
        # the user_id of the target user, and the type of interaction
        cur.execute("""
            INSERT INTO interaction (subject_id, object_id, type)
            VALUES (
                (SELECT user_id FROM user WHERE username = %s),
                (SELECT user_id FROM user WHERE username = %s),
                %s
            )
        """, (username, target_username, interaction_type))
        mysql.connection.commit()
        return jsonify({'message': 'Interaction recorded successfully'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        cur.close()

#liked endpoint 
@app.route('/api/liked', methods=['GET'])
def get_liked():
    username = request.args.get('username')
    if not username:
        return jsonify({'message': 'Username is required'}), 400

    cur = mysql.connection.cursor()
    try:
        # Assuming 'interaction' table has a type column where 'like' indicates a like interaction
        cur.execute("""
            SELECT i.*, u.username as target_username
            FROM interaction i
            JOIN user u ON i.object_id = u.user_id
            WHERE i.subject_id = (SELECT user_id FROM user WHERE username = %s)
            AND i.type = 'like'
        """, (username,))
        likes = cur.fetchall()
        # Format the data as needed. This is a basic example.
        liked_data = [{'target_username': like['target_username']} for like in likes]
        return jsonify({'answers': liked_data})
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        cur.close()
#endpoint to get the user's boxes
@app.route('/api/infoboxes', methods=['GET'])
def get_infoboxes():
    username = request.args.get('username')
    if not username:
        return jsonify({'message': 'Username is required'}), 400

    cur = mysql.connection.cursor()
    try:
        # Fetching boxes information for the user
        cur.execute("""
            SELECT title, description 
            FROM box 
            WHERE user_id = (SELECT user_id FROM user WHERE username = %s)
        """, (username,))
        boxes = cur.fetchall()
        
        # Formatting the fetched data
        box_data = [{'title': box[0], 'content': box[1]} for box in boxes]
        return jsonify(box_data)
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        cur.close()

#endpoint to delete box
@app.route('/api/delete_box', methods=['POST'])
def delete_box():
    data = request.json
    username = data.get('username')
    title = data.get('title')
    content = data.get('content')

    if not all([username, title, content]):
        return jsonify({'message': 'Username, title, and content are required'}), 400

    cur = mysql.connection.cursor()
    try:
        # Assuming 'box' table has columns 'title', 'description', and is related to 'user'
        cur.execute("""
            DELETE FROM box 
            WHERE user_id = (SELECT user_id FROM user WHERE username = %s)
            AND title = %s
            AND description = %s
        """, (username, title, content))
        mysql.connection.commit()
        return jsonify({'message': 'Box deleted successfully'}), 200
    except Exception as e:
        return jsonify({'error': str(e)}), 500
    finally:
        cur.close()



if __name__ == '__main__':
    app.run(debug=True)
