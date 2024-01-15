LOAD DATA LOCAL INFILE '/u01/ece/se7/hci/Soundmates/backend/user.tsv' INTO TABLE user LINES TERMINATED BY '\n';
LOAD DATA LOCAL INFILE '/u01/ece/se7/hci/Soundmates/backend/box.tsv' INTO TABLE box LINES TERMINATED BY '\n';
LOAD DATA LOCAL INFILE '/u01/ece/se7/hci/Soundmates/backend/match.tsv' INTO TABLE soundmates.Match LINES TERMINATED BY '\n';
LOAD DATA LOCAL INFILE '/u01/ece/se7/hci/Soundmates/backend/interaction.tsv' INTO TABLE interaction LINES TERMINATED BY '\n';
LOAD DATA LOCAL INFILE '/u01/ece/se7/hci/Soundmates/backend/socials.tsv' INTO TABLE socials LINES TERMINATED BY '\n';
