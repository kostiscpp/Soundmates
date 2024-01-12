insert_template = "INSERT INTO genre (genre) VALUES ('{genre}');"

genres = open('genres.txt').read().split('\n')

with open('output.sql', 'w') as file:
    for genre in genres:
        file.write(insert_template.format(genre=genre))