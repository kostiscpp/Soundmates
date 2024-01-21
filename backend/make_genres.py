insert_template = "INSERT INTO genre (genre) VALUES ('{genre}');\n"

genres = open('genress.txt').read().split('\n')
seen = set()
with open('output.sql', 'w') as file:
    file.write('SET FOREIGN_KEY_CHECKS = 0;\n')
    file.write('TRUNCATE TABLE genre;\n')
    file.write('SET FOREIGN_KEY_CHECKS = 1;\n')
    for i,genre in enumerate(genres):
        if genre == '':
            continue
        print(genre)
        file.write(insert_template.format(genre=genre))