INSERT INTO soundmates.user (username, name, birthdate, gender, preferred_gender, location_long, location_lat, password, email, job)
VALUES 
('user1', 'John Doe', '1990-01-01 00:00:00', 'male', 'female', -73.935242, 40.730610, 1, 'pog@gmail.com', 'Software Engineer'),
('user2', 'Jane Smith', '1992-05-15 00:00:00', 'female', 'male', -118.243683, 34.052235, 1,'pog@gmail.com', 'Musician'),
('user3', 'Alex Johnson', '1995-07-20 00:00:00', 'non binary', 'any', -0.127758, 51.507351, 1, 'pog@gmail.com', 'Musician'),
('user4', 'Chris Lee', '1988-11-30 00:00:00', 'male', 'any', 151.209900, -33.865143, 1, 'pog@gmail.com', 'Musician'),
('user5', 'Pat Kim', '1993-03-05 00:00:00', 'female', 'female', 139.691711, 35.689487, 1, 'pog@gmail.com', 'OnlyFans');

INSERT INTO soundmates.Match (user1_id, user2_id)  
VALUES 
(1, 2);

INSERT INTO soundmates.super_likes(liker_id, liked_id)
VALUES
(1, 3),
(1, 4),
(2, 1),
(5, 4);

INSERT INTO soundmates.photo (`user_id`, `order`, `photo_url`) VALUES
(1, 1, 'https://i.imgur.com/1.jpg'),
(1, 2, 'https://i.imgur.com/2.jpg'),
(1, 3, 'https://i.imgur.com/3.jpg'),
(1, 4, 'https://i.imgur.com/4.jpg'),
(1, 5, 'https://i.imgur.com/5.jpg'),
(2, 1, 'https://i.imgur.com/6.jpg'),
(2, 2, 'https://i.imgur.com/7.jpg'),
(2, 3, 'https://i.imgur.com/8.jpg'),
(2, 4, 'https://i.imgur.com/9.jpg'),
(2, 5, 'https://i.imgur.com/10.jpg'),
(3, 1, 'https://i.imgur.com/11.jpg'),
(3, 2, 'https://i.imgur.com/12.jpg'),
(3, 3, 'https://i.imgur.com/13.jpg'),
(3, 4, 'https://i.imgur.com/14.jpg'),
(3, 5, 'https://i.imgur.com/15.jpg'),
(4, 1, 'https://i.imgur.com/16.jpg'),
(4, 2, 'https://i.imgur.com/17.jpg'),
(4, 3, 'https://i.imgur.com/18.jpg'),
(4, 4, 'https://i.imgur.com/19.jpg'),
(4, 5, 'https://i.imgur.com/20.jpg'),
(5, 1, 'https://i.imgur.com/21.jpg'),
(5, 2, 'https://i.imgur.com/22.jpg'),
(5, 3, 'https://i.imgur.com/23.jpg'),
(5, 4, 'https://i.imgur.com/24.jpg'),
(5, 5, 'https://i.imgur.com/25.jpg');