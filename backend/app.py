from flask import Flask,request, jsonify, send_from_directory
from flask_mysqldb import MySQL
from werkzeug.security import generate_password_hash, check_password_hash
import yaml
import random
import geopy.distance
import datetime
from werkzeug.utils import secure_filename
import os
app = Flask(__name__)

# Configure MySQL
db = yaml.safe_load(open('soundmates.yaml'))
app.config['MYSQL_HOST'] = db['mysql_host']
app.config['MYSQL_USER'] = db['mysql_user']
app.config['MYSQL_PASSWORD'] = db['mysql_password']
app.config['MYSQL_DB'] = db['mysql_db']
server = 'http://soundmates.ddns.net:5000'
server_image = server + '/images/'
image_folder = './images/'

mysql = MySQL(app)

# Helper function to get age from birthdate
# def age(birthdate):
#     today = date.today()
#     age = today.year - birthdate.year - ((today.month, today.day) < (birthdate.month, birthdate.day))
#     return age


@app.route('/images/<filename>')
def serve_image(filename):

    return send_from_directory(image_folder, filename)


# Routes
@app.route('/', methods=['GET'])
def index():
    return jsonify({'message': 'Welcome to Soundmates'})



@app.route('/get_profiles_swipe', methods=['GET'])
def swipe():
    # Get 6 users from database that are in acceptable range of user's location if cached users are not available
    # If cached users are available, return cached users
    username = request.args.get('username')
    print(username)
    cur = mysql.connection.cursor()
    query = "SELECT user_id, gender , preferred_gender, location_long, location_lat FROM user WHERE username = %s"

    print("got here")
    cur.execute(query, (username,))
    rv = cur.fetchall()
    if len(rv) == 0:
        cur.close()
        return jsonify({"results" :[]}), 200
    userID = rv[0][0]
    print(userID)
    gender = rv[0][1]
    preferred_gender = rv[0][2]
    long = rv[0][3]
    print(long)
    lat = rv[0][4]
    print(lat)
    query =""" 
    SELECT u.user_id, u.username, u.age, u.name, u.job,
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
        SELECT object_id
        FROM soundmates.interaction 
        WHERE subject_id = %s AND (type = 'superlike' OR type = 'like')
    ) 
"""
    filter_rejected = """AND u.user_id NOT IN ( 
        SELECT user_id FROM soundmates.interaction 
        WHERE (subject_id = %s OR object_id = %s) AND (type = 'reject' OR type = 'de-facto-reject')
        )"""
    query += filter_rejected
    filter_gender = """AND u.user_id IN (SELECT user_id FROM user 
                         WHERE (preferred_gender = %s OR preferred_gender = 'any') 
                         AND (gender = %s OR %s = 'any'))"""
    query += filter_gender
    filter_music = """AND u.user_id IN (SELECT p.user_userid FROM preference p
                        WHERE p.genre_genre_id IN (SELECT pp.genre_genre_id FROM preference pp WHERE pp.user_userid = %s AND pp.percentage >= 50) AND p.percentage >= 50) """
    query += filter_music
    priority_to_interactions = """ ORDER BY CASE WHEN u.user_id IN (SELECT user_id FROM soundmates.interaction WHERE subject_id = %s AND type = 'like') THEN 1 ELSE 2 END"""
    limit_by = """ LIMIT 20"""
    cur = mysql.connection.cursor()
    cur.execute(query + priority_to_interactions + limit_by, (lat, long, lat, username, userID, userID, userID, 
                                                              userID, userID,
                                                              gender, preferred_gender, preferred_gender,
                                                              userID, userID))
    rv = cur.fetchall()
    #print(rv)
    if len(rv) == 0:
        cur.execute(query + limit_by, (lat, long, lat, username, userID, userID, userID, 
                                       userID, userID, 
                                       gender, preferred_gender, preferred_gender,
                                       userID))
        rv = cur.fetchall()
        #print(rv)
    rv = [profile_swipe(x) for x in rv] 
    print({"results" : rv})
    return jsonify({"results" :rv}), 200
# Helper function
def profile_swipe(profile):
    # Get user's photos
    print(profile)
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
    result["age"] = int(profile[2])
    result["name"] = profile[3]
    result["distance"] = str(round(profile[-1],1)) + "km"
    result["job"] = "" if profile[4] is None else profile[4]
    result["photoUrls"] = [server_image + x[2] for x in photos]
    result["boxes"] = [(x[2],x[3]) for x in box]
    return result
  
@app.route('/login', methods=['POST'])
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

    if user and password == user[1]:
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
    attr = list(x for x in request.json.values())
    attr[-1] = attr[-1].lower()
    attr[-2] = attr[-2].lower()
    attr = tuple(attr)
    print(attr)
    cur.execute("""INSERT INTO user (username, password, name, email,
  age, gender, preferred_gender, location_long, location_lat) VALUES (%s, %s, %s, %s, %s, %s, %s, 42, 42)""", attr)
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

@app.route('/api/change_profile_data', methods=['POST']) 
def update_profile():
    cur = mysql.connection.cursor()
    username = request.json['username']
    nameAge = request.json['NameAge']
    job = request.json['Job']
    try:
        
        nameAge = nameAge.split(',')
        if int(nameAge[1]) < 18:
            return jsonify({'message': 'Illegal'}), 400
        cur.execute("UPDATE user SET name = %s WHERE username = %s", (nameAge[0], username))
        cur.execute("UPDATE user SET age = %s WHERE username = %s", (nameAge[1], username))
        cur.execute("UPDATE user SET job = %s WHERE username = %s", (job, username))
        mysql.connection.commit()
        cur.close()
        return jsonify({'message': 'Profile updated successfully'}), 200
    except Exception as e:
        return jsonify({'message': 'Invalid field type'}), 400



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
        picture_url = picture_url.replace(server_image, '')
        cur.execute("DELETE FROM photo WHERE photo_url = %s AND user_id = (SELECT user_id FROM user WHERE username = %s)", (picture_url, username))
        mysql.connection.commit()

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
        delete_path = os.path.join(image_folder, picture_url)
        os.remove(delete_path)
        return jsonify({'message': 'Picture deleted successfully'}), 200

    except Exception as e:
        cur.close()
        return jsonify({'error': str(e)}), 500



@app.route('/api/matches', methods=['GET'])
def matches():
    if 'username' not in request.args:
        return jsonify({'message': "No username given (this isn't supposed to happen)"}), 400
    username = request.args.get('username')
    cur = mysql.connection.cursor()
    cur.execute("SELECT user_id FROM user WHERE username = %s", (username,))
    rv = cur.fetchall()
    if len(rv) == 0:
        return jsonify({'message': 'User does not exist'}), 400
    userID = rv[0][0]
    cur.execute("""SELECT * FROM soundmates.Match WHERE user1_id = %s OR user2_id = %s""", (userID, userID))
    rv = cur.fetchall()
    if len(rv) == 0:
        return jsonify({"answers" : []}), 200
    query = ""
    results = []
    for match in rv:
        print(match)
        print(userID)
        if match[0] == userID:
            query_user = f"""SELECT u.username, u.name, u.age
                        FROM user u  WHERE u.user_id = {match[1]} LIMIT 1"""
            query_photo = f"""SELECT p.photo_url FROM photo p WHERE p.user_id = {match[1]} LIMIT 1"""
            query_socials = f"""SELECT s.social_info FROM socials s WHERE s.user_id = {match[1]} LIMIT 1"""
        else:
            query_user = f"""SELECT u.username, u.name, u.age
                        FROM user u  WHERE u.user_id = {match[0]} LIMIT 1"""
            query_photo = f"""SELECT p.photo_url FROM photo p WHERE p.user_id = {match[0]} LIMIT 1"""
            query_socials = f"""SELECT s.social_info FROM socials s WHERE s.user_id = {match[0]} LIMIT 1"""
        cur.execute(query_user)
        user = cur.fetchall()[0]
        cur.execute(query_photo)
        photo = cur.fetchall()
        if len(photo) == 0:
            photo = 'pog.png'
        else:
            photo = photo[0][0]
        cur.execute(query_socials)
        socials = cur.fetchall()
        if len(socials) == 0:
            socials = ''
        else:
            socials = socials[0][0]
        if match[0] == userID:
            cur.execute("""UPDATE soundmates.Match SET is_new1 = 0 WHERE user1_id = %s AND user2_id = %s""", (match[0], match[1]))
            truthvalue = match[2]
            print(1)
        else:
            cur.execute("""UPDATE soundmates.Match SET is_new2 = 0 WHERE user1_id = %s AND user2_id = %s""", (match[0], match[1]))
            truthvalue = match[3]
            print(2)
        mysql.connection.commit()
        results.append({"username":user[0], "age" : user[2],"photoUrl":server_image + photo , "name":user[1], "socials":socials, "new":truthvalue})
    print(results)
    cur.close()
    return jsonify({"answers": results})

@app.route('/liked_you', methods=['GET'])
def liked_you():
    cur = mysql.connection.cursor()
    cur.execute("SELECT user_id FROM user WHERE username = %s", (request.json['username'],))
    userID = cur.fetchall()[0]
    cur.execute("""SELECT 
                    u.username, 
                    p.photo_url           
                    FROM 
                    soundmates.interaction i 
                    JOIN user u ON u.user_id = i.subject_id 
                    JOIN 
                        (SELECT * FROM photo WHERE `order` IN (SELECT MIN(`order`) FROM photo GROUP BY user_id)) p 
                    ON 
                    u.user_id = p.user_id 
                    WHERE 
                    i.object = %s
                    """, (userID,))
    rv = cur.fetchall()
    cur.close()
    print(rv)
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
    if 'username' not in request.args:
        return jsonify({'message': 'Username is required'}), 400
    username = request.args.get('username') # implemented earlier on 
    cur = mysql.connection.cursor()
    cur.execute("SELECT name, age, job FROM user WHERE username = %s", (username,))
    profile_data = cur.fetchone()
    cur.close()

    if profile_data:
        name, age, job = profile_data
        print(name, age, job)
        if job is None:
            return jsonify({'nameAge': f'{name}, {age}', 'jobTitle': ''})
        else:
            return jsonify({'nameAge': f'{name}, {age}', 'jobTitle': job})
    else:
        return jsonify({'nameAge': '', 'jobTitle': ''}), 200


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
        pictures = [ server_image + photo[0] for photo in photos_data]
        return jsonify(pictures)
    else:
        return jsonify([]), 200



# Configuration for file uploads
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}



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
        extension = file.filename.rsplit('.', 1)[1].lower()
        datee = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
        filename = username + str(datee) + '.' + extension
        file_path = os.path.join(image_folder, filename)

        cur = mysql.connection.cursor()
        # Get the current maximum order value
        cur.execute("SELECT MAX(`order`) FROM photo WHERE user_id = (SELECT user_id FROM user WHERE username = %s)", (username,))
        max_order_result = cur.fetchone()
        print(max_order_result)
        next_order = max_order_result[0] + 1 if max_order_result and max_order_result[0] is not None else 1
        print(next_order)
        # Insert the new photo with the next order value
        cur.execute("INSERT INTO photo (user_id, `order`, photo_url) VALUES ((SELECT user_id FROM user WHERE username = %s), %s, %s)", (username, next_order, filename))
        mysql.connection.commit()
        cur.close()
        file.save(file_path)

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
        print(genres)
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
    print(data)
    username = data.get('username')
    genres = data.get('genres')
    print(genres)
    if not username or not genres:
        return jsonify({'message': 'Username and genres are required'}), 400

    cur = mysql.connection.cursor()
    try:
        # Delete all existing genres for the user
        cur.execute("DELETE FROM preference WHERE user_userid = (SELECT user_id FROM user WHERE username = %s)", (username,))
        mysql.connection.commit()
        
        # Insert the new genres
        cur.execute("SELECT genre FROM genre")
        genres_data = cur.fetchall()
        genres_data = [genre[0] for genre in genres_data]
        for genre in genres:
            percentage = genres[genre]
            print(genre, percentage)
            if genre not in genres_data:
                cur.execute("INSERT INTO genre (genre) VALUES (%s)", (genre,))
                mysql.connection.commit()
            cur.execute("INSERT INTO preference (user_userid, genre_genre_id, percentage) VALUES ((SELECT user_id FROM user WHERE username = %s), (SELECT genre_id FROM genre WHERE genre = %s), %s)", (username, genre, percentage))
            mysql.connection.commit()

        return jsonify({'message': 'Genres updated successfully'}), 200
    except Exception as e:
        print(e)
        return jsonify({'error': str(e)}), 500
    finally:
        cur.close()

#endpoint to get the socials 

@app.route('/api/mysocials', methods=['GET'])
def get_socials():
    username = request.args.get('username')
    print(username)
    if not username:
        return jsonify({'message': 'Username is required'}), 400
    try:    
        cur = mysql.connection.cursor()
        cur.execute("""
            SELECT s.social_info 
            FROM socials s
            JOIN user u ON u.user_id = s.user_id
            WHERE u.username = %s
            LIMIT 1
        """, (username,))
        user_data = cur.fetchone()
        cur.execute(""" 
            SELECT photo_url from photo 
                    JOIN user ON photo.user_id = user.user_id 
                    WHERE user.username = %s AND photo.order = 1
        """, (username,))
        photo_url = cur.fetchone()
        cur.close()
        if not photo_url:
            photo_url = 'pog.png'
        else:
            photo_url = photo_url[0]
        photo_url = server_image + photo_url
        print(user_data, photo_url)
        if not user_data:
            user_data = ''
        else:
            user_data = user_data[0]
        social_data = {
            'socials': user_data,
            'photoUrl': photo_url
        }
        return jsonify(social_data)
    except Exception as e:
        print(e)
        return jsonify({'error': str(e)}), 500



#endpoint to update the socials 
@app.route('/api/update_mysocials', methods=['POST'])
def update_socials():
    data = request.json
    username = data.get('username')
    socials = data.get('socials')
    print(username, socials)
    if (not username) or (not socials):
        return jsonify({'message': 'Username and socials are required'}), 400

    cur = mysql.connection.cursor()
    cur.execute("SELECT * FROM socials WHERE user_id = (SELECT user_id FROM user WHERE username = %s)", (username,))
    if cur.rowcount == 0:
        # Insert socials
        cur.execute("INSERT INTO socials (user_id, social_info) VALUES ((SELECT user_id FROM user WHERE username = %s), %s)", (username, socials))
        mysql.connection.commit()
        cur.close()
        return jsonify({'message': 'Social data updated successfully'}), 200
    cur.execute("""
        UPDATE socials 
        SET social_info = %s 
        WHERE user_id = (SELECT user_id FROM user WHERE username = %s)
    """, (socials, username))
    mysql.connection.commit()
    cur.close()
    return jsonify({'message': 'Social data updated successfully'}), 200

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
        cur.execute("SELECT * FROM box WHERE user_id = %s", (user_id,))
        next_order = 1
        if cur.rowcount != 0:
            cur.execute("SELECT MAX(`order`) FROM box WHERE user_id = %s", (user_id,))
            max_order_result = cur.fetchone()[0]
            next_order = max_order_result + 1 
        cur.execute("INSERT INTO box (user_id, title, description,`order`) VALUES (%s, %s, %s, %s)", (user_id, title, content, next_order))
        mysql.connection.commit()
        cur.close()
        return jsonify({'message': 'Box added successfully'}), 200
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
            INSERT INTO interaction (subject_id, object_id, type, `date`)
            VALUES (
                (SELECT user_id FROM user WHERE username = %s),
                (SELECT user_id FROM user WHERE username = %s),
                %s,
                %s
            )
        """, (username, target_username, interaction_type, datetime.datetime.now()))
        mysql.connection.commit()
        if interaction_type == 'like' or interaction_type == 'superlike':
            # Check if the target user has liked the acting user
            cur.execute("""
                SELECT * 
                FROM interaction 
                WHERE subject_id = (SELECT user_id FROM user WHERE username = %s)
                AND object_id = (SELECT user_id FROM user WHERE username = %s)
                AND (type = 'like' or type = 'superlike')
            """, (target_username, username))
            if cur.rowcount != 0:
                # If the target user has liked the acting user, insert a match
                cur.execute("""
                    INSERT INTO soundmates.`Match` (user1_id, user2_id)
                    VALUES (
                        (SELECT user_id FROM user WHERE username = %s),
                        (SELECT user_id FROM user WHERE username = %s)
                    )
                """, (username, target_username))
                mysql.connection.commit()
        return jsonify({'message': 'Interaction recorded successfully'}), 200
    except Exception as e:
        print(e)
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
            SELECT i.subject_id
            FROM interaction i WHERE i.object_id = (SELECT user_id FROM user WHERE username = %s) AND i.type = 'superlike'""", (username,))
        likes = cur.fetchall()
        liked_data = []
        for user in likes:
            query_user = f"""SELECT u.username, u.name, u.age
                        FROM user u  WHERE u.user_id = {user[0]} LIMIT 1"""
            query_photo = f"""SELECT p.photo_url FROM photo p WHERE p.user_id = {user[0]} LIMIT 1"""
            query_socials = f"""SELECT s.social_info FROM socials s WHERE s.user_id = {user[0]} LIMIT 1"""
            cur.execute(query_user)
            user = cur.fetchall()[0]
            cur.execute(query_photo)
            photo = cur.fetchall()
            if len(photo) == 0:
                photo = 'pog.png'
            else:
                photo = photo[0][0]
            cur.execute(query_socials)
            socials = cur.fetchall()
            if len(socials) == 0:
                socials = ''
            else:
                socials = socials[0][0]
            liked_data.append({"username":user[0], "age" : user[2],"photoUrl":server_image + photo , "name":user[1], "socials":socials})
        # Format the data as needed. This is a basic example.
        print(liked_data)
        return jsonify({'answers': liked_data})
    except Exception as e:
        print(e)
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
        if not boxes:
            return jsonify([]), 200
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
    app.run(debug=True, host='0.0.0.0')
