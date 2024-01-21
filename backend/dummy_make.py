
from faker import Faker
from numpy import random as rnd
import random
import os

fake = Faker()

# Number of records to generate for each table
NUM_USERS = 200
NUM_BOXES = 5
NUM_INTERACTIONS = 800
NUM_SOCIALS = 100
NUM_GENRES = 101
def form(tmp):
    if tmp == 'M':
        return 'male'
    else:
        return 'female'
# Function to generate dummy data for the 'user' table
def generate_user_data(n):
    users = []
    for i in range(n):
        user_id = i+1
        temp = fake.profile()
        #print(temp)
        username = temp['username']
        password = fake.password()
        email = temp['mail']
        name = temp['name']
        job = temp['job']
        age = random.randint(18, 40)
        gender = rnd.choice([form(temp['sex']), 'non binary'], 1, p=[0.7, 0.3])[0]
        preferred_gender = random.choice(['male', 'female', 'any'])
        location_long = fake.longitude()
        location_lat = fake.latitude()
        users.append((user_id,username, password, email, name, job, age, gender, preferred_gender, location_long, location_lat))
    return users




# Generate dummy data for the 'box' table
def generate_box_data(num_boxes, num_users):
    boxes = []
    for user_id in range(1, num_users + 1):
        for order in range(1, num_boxes + 1):
            title = fake.sentence(nb_words=6)
            description = fake.text(max_nb_chars=50)
            boxes.append((order, user_id, title, description, 1))
    return boxes

# Generate dummy data for the 'Match' table
def generate_match_data(interactions):
    matches = []
    likes = []
    for user1_id, user2_id, _, interaction_type in interactions:
        if interaction_type == 'like' or interaction_type == 'superlike':
            likes.append((user1_id, user2_id))
            if (user2_id, user1_id) in likes:
                matches.append((user1_id, user2_id, 0, 0))
    return matches

# Generate dummy data for the 'interaction' table
def generate_interaction_data(num_interactions, num_users):
    interactions = []
    for _ in range(num_interactions):
        subject_id = random.randint(1, num_users)
        object_id = random.randint(1, num_users)
        while subject_id == object_id or (subject_id, object_id,) in interactions[:][:2]:
            subject_id = random.randint(1, num_users)
            object_id = random.randint(1, num_users)
        date = fake.date_time_this_year()
        interaction_type = random.choice(['like', 'reject', 'superlike', 'reload', 'de-facto-reject'])
        interactions.append((subject_id, object_id, date, interaction_type))
    return interactions

# Generate dummy data for the 'socials' table
def generate_socials_data(num_socials):
    socials = []
    for user_id in range(1, num_socials + 1):
        social_info = fake.url()
        socials.append((user_id, social_info))
    return socials

# Generate dummy data for the 'preferences' table
def generate_preferences_data(num_genres, num_users):
    preferences = []
    for user_id in range(1, num_users + 1):
        for _ in range(1):
            preference = random.randint(1, num_genres)
            percentage = random.randint(50, 100)
            while (user_id, preference) in ((x[0],x[1]) for x in preferences):
                preference = random.randint(1, num_genres)
                percentage = random.randint(50, 100)
            preferences.append((user_id, preference, percentage))
    return preferences

# Generating data
users = generate_user_data(NUM_USERS)
boxes = generate_box_data(NUM_BOXES, NUM_USERS)
interactions = generate_interaction_data(NUM_INTERACTIONS, NUM_USERS)
matches = generate_match_data(interactions)
socials = generate_socials_data(NUM_SOCIALS)
preferences = generate_preferences_data(NUM_GENRES, NUM_USERS)

# Generate TSVs for each table


def write_tsv(filename, data):
    with open(filename, 'w') as f:
        for row in data:
            f.write('\t'.join([str(x) for x in row]) + '\n')

# Write TSVs
write_tsv('user.tsv', users)
write_tsv('box.tsv', boxes)
write_tsv('match.tsv', matches)
write_tsv('interaction.tsv', interactions)
write_tsv('socials.tsv', socials)
write_tsv('preferences.tsv', preferences)

# then write SQL insert statements into 'data.sql' file 


with open('data.sql','w') as file:
    TRUNCATE = "TRUNCATE TABLE " 
    LOAD = "LOAD DATA LOCAL INFILE '"
    INTO = "' INTO TABLE "
    LINES = " LINES TERMINATED BY '\\n';\n"
    file.write('SET FOREIGN_KEY_CHECKS = 0;\n')
    file.write(TRUNCATE + 'user' + ';\n')
    file.write(TRUNCATE + 'box' + ';\n')
    file.write(TRUNCATE + 'interaction' + ';\n')
    file.write(TRUNCATE + 'soundmates.Match' + ';\n')
    file.write(TRUNCATE + 'socials' + ';\n')
    file.write(TRUNCATE + 'preference' + ';\n')
    file.write('SET FOREIGN_KEY_CHECKS = 1;\n')
    file.write(LOAD + os.getcwd() + '/user.tsv' + INTO + 'user' + LINES)
    file.write(LOAD + os.getcwd() + '/box.tsv' + INTO + 'box' + LINES)
    file.write(LOAD + os.getcwd() + '/interaction.tsv' + INTO + 'interaction' + LINES)
    file.write(LOAD + os.getcwd() + '/match.tsv' + INTO + 'soundmates.Match' + LINES)
    file.write(LOAD + os.getcwd() + '/socials.tsv' + INTO + 'socials' + LINES)
    file.write(LOAD + os.getcwd() + '/preferences.tsv' + INTO + 'preference' + LINES)

# then run the following command in the terminal to load the data into the database
# mysql -u root -p -h
# source data.sql
    

    