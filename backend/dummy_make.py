
from faker import Faker
import random

fake = Faker()

# Number of records to generate for each table
NUM_USERS = 10
NUM_BOXES = 20
NUM_MATCHES = 15
NUM_INTERACTIONS = 50
NUM_SOCIALS = 10

# Function to generate dummy data for the 'user' table
def generate_user_data(n):
    users = []
    for _ in range(n):
        username = fake.user_name()
        password = fake.password()
        email = fake.email()
        name = fake.name()
        job = fake.job()
        age = random.randint(18, 99)
        gender = random.choice(['male', 'female', 'non binary'])
        preferred_gender = random.choice(['male', 'female', 'any'])
        location_long = fake.longitude()
        location_lat = fake.latitude()
        users.append((username, password, email, name, job, age, gender, preferred_gender, location_long, location_lat))
    return users

# Generate data
num_users = 10  # Number of dummy users to generate

user_data = generate_user_data(num_users)


# Generate dummy data for the 'box' table
def generate_box_data(num_boxes, num_users):
    boxes = []
    for user_id in range(1, num_users + 1):
        for order in range(1, num_boxes + 1):
            title = fake.sentence(nb_words=6)
            description = fake.text(max_nb_chars=200)
            boxes.append((order, user_id, title, description))
    return boxes

# Generate dummy data for the 'Match' table
def generate_match_data(num_matches, num_users):
    matches = []
    for _ in range(num_matches):
        user1_id = random.randint(1, num_users)
        user2_id = random.randint(1, num_users)
        if user1_id != user2_id:
            matches.append((user1_id, user2_id))
    return matches

# Generate dummy data for the 'interaction' table
def generate_interaction_data(num_interactions, num_users):
    interactions = []
    for _ in range(num_interactions):
        subject_id = random.randint(1, num_users)
        object_id = random.randint(1, num_users)
        date = fake.date_time_this_year()
        interaction_type = random.choice(['like', 'reject', 'superlike', 'reload', 'de-facto-reject'])
        interactions.append((subject_id, object_id, date, interaction_type))
    return interactions

# Generate dummy data for the 'socials' table
def generate_socials_data(num_socials, num_users):
    socials = []
    for user_id in range(1, num_socials + 1):
        social_info = fake.url()
        socials.append((user_id, social_info))
    return socials

# Generating data
users = generate_user_data(NUM_USERS)
boxes = generate_box_data(NUM_BOXES, NUM_USERS)
matches = generate_match_data(NUM_MATCHES, NUM_USERS)
interactions = generate_interaction_data(NUM_INTERACTIONS, NUM_USERS)
socials = generate_socials_data(NUM_SOCIALS, NUM_USERS)

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

# then write SQL insert statements into 'data.sql' file 

with open('data.sql','w') as file: 
    LOAD = "LOAD DATA LOCAL INFILE '"
    INTO = "' INTO TABLE "
    LINES = " LINES TERMINATED BY '\\n';\n"
    file.write(LOAD + 'user.tsv' + INTO + 'user' + LINES)
    file.write(LOAD + 'box.tsv' + INTO + 'box' + LINES)
    file.write(LOAD + 'match.tsv' + INTO + 'match' + LINES)
    file.write(LOAD + 'interaction.tsv' + INTO + 'interaction' + LINES)
    file.write(LOAD + 'socials.tsv' + INTO + 'socials' + LINES)
    

# then run the following command in the terminal to load the data into the database
# mysql -u root -p -h
# source data.sql
    

    