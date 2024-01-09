from flask import Flask, request, jsonify
from flask_mysqldb import MySQL
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
    query =""" 
    SELECT username, age, name, job,
        (6371 * acos(
            cos(radians(%s)) 
            * cos(radians(location_lat)) 
            * cos(radians(location_long) - radians(%s)) 
            + sin(radians(%s)) 
            * sin(radians(location_lat))
        )) AS distance  
    FROM user 
    WHERE username != %s 
    AND user_id NOT IN (
        SELECT user2_id 
        FROM soundmates.Match 
        WHERE user1_id = user_id
        UNION 
        SELECT user1_id 
        FROM soundmates.Match 
        WHERE user2_id = user_id
    )
    ORDER BY distance 
    LIMIT 6
"""
    cur = mysql.connection.cursor()
    cur.execute(query, (request.json['latitude'], request.json['longitude'], request.json['latitude'], request.json['username']))
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
  
@app.route('/login', methods=['POST'])
def login():
#     # Check if user exists in database
    username = request.json['username']
    password = request.json['password']
    if username == '' or password == '':
        return jsonify({'message': 'Please enter a username and password'}), 400
    cur = mysql.connection.cursor()
    cur.execute("SELECT * FROM user WHERE username = %s", (username,))
    rv = cur.fetchall()
    if len(rv) == 0:
        return jsonify({'message': 'User does not exist'}), 400
    cur.execute("SELECT * FROM user WHERE username = %s AND password = %s", (username, password))
    rv = cur.fetchall()
    if len(rv) == 0:
        return jsonify({'message': 'Wrong Password'}), 400
    cur.close()
    return jsonify(rv)

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

@app.route('/update_profile', methods=['PUT']) 
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

@app.route('/delete_user/<string:username>', methods=['DELETE'])
def delete_profile(username):
    cur = mysql.connection.cursor()
    try:
       # SQL query to delete a user
       cur.execute("DELETE FROM user WHERE username = %s", (username,))
       mysql.connection.commit()
       if cur.rowcount > 0:
           return jsonify({'message': 'User deleted successfully'}), 200
       else:
           return jsonify({'message': 'User not found'}), 404
    except Exception as e:
        # Handle any exception that occurs during the operation
        return jsonify({'error': str(e)}), 500
    finally:
        cur.close()


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



if __name__ == '__main__':
    app.run(debug=True)
