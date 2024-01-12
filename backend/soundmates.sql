-- MySQL Script generated by MySQL Workbench
-- Wed 03 Jan 2024 16:53:22 EET
-- Model: New Model    Version: 1.0
-- MySQL Workbench Forward Engineering

SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0;
SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0;
SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='ONLY_FULL_GROUP_BY,STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION';

-- -----------------------------------------------------
-- Schema soundmates
-- -----------------------------------------------------

-- -----------------------------------------------------
-- Schema soundmates
-- -----------------------------------------------------
CREATE SCHEMA IF NOT EXISTS `soundmates` ;
USE `soundmates` ;

-- -----------------------------------------------------
-- Table `soundmates`.`user`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `soundmates`.`user` ;

CREATE TABLE IF NOT EXISTS `soundmates`.`user` (
  `user_id` INT NOT NULL AUTO_INCREMENT,
  `username` VARCHAR(255) NOT NULL UNIQUE,
  `password` VARCHAR(255) NOT NULL,
  `email` VARCHAR(255) NOT NULL,
  `name` VARCHAR(255) NOT NULL,
  `job` VARCHAR(255) NULL,
  `birthdate` DATETIME NOT NULL,
  `gender` ENUM('male', 'female', 'non binary') NOT NULL,
  `preferred_gender` ENUM('male', 'female', 'any') NOT NULL,
  `location_long` FLOAT NOT NULL,
  `location_lat` FLOAT NOT NULL,
  PRIMARY KEY (`user_id`),
  UNIQUE INDEX `username_UNIQUE` (`username` ASC) VISIBLE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `soundmates`.`photo`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `soundmates`.`photo` ;

CREATE TABLE IF NOT EXISTS `soundmates`.`photo` (
  `user_id` INT NOT NULL,
  `order` INT NOT NULL,
  `photo_url` TEXT NOT NULL,
  PRIMARY KEY (`user_id`, `order`),
  INDEX `fk_photo_user_idx` (`user_id` ASC) VISIBLE,
  CONSTRAINT `fk_photo_user`
    FOREIGN KEY (`user_id`)
    REFERENCES `soundmates`.`user` (`user_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `soundmates`.`genre`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `soundmates`.`genre` ;

CREATE TABLE IF NOT EXISTS `soundmates`.`genre` (
  `genre_id` INT NOT NULL,
  `genre` VARCHAR(255) NOT NULL,
  `genrecol` VARCHAR(45) NULL,
  PRIMARY KEY (`genre_id`),
  UNIQUE INDEX `genre_id_UNIQUE` (`genre_id` ASC) VISIBLE)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `soundmates`.`preference`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `soundmates`.`preference` ;

CREATE TABLE IF NOT EXISTS `soundmates`.`preference` (
  `user_userid` INT NOT NULL,
  `genre_genre_id` INT NOT NULL,
  `percentage` INT NOT NULL,
  PRIMARY KEY (`user_userid`, `genre_genre_id`),
  INDEX `fk_user_has_genre_genre1_idx` (`genre_genre_id` ASC) VISIBLE,
  INDEX `fk_user_has_genre_user1_idx` (`user_userid` ASC) VISIBLE,
  CONSTRAINT `fk_user_has_genre_user1`
    FOREIGN KEY (`user_userid`)
    REFERENCES `soundmates`.`user` (`user_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_user_has_genre_genre1`
    FOREIGN KEY (`genre_genre_id`)
    REFERENCES `soundmates`.`genre` (`genre_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `soundmates`.`box`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `soundmates`.`box` ;

CREATE TABLE IF NOT EXISTS `soundmates`.`box` (
  `order` INT NOT NULL,
  `user_id` INT NOT NULL,
  `title` TEXT NOT NULL,
  `description` TEXT NOT NULL,
  PRIMARY KEY (`user_id`, `order`),
  INDEX `fk_box_user1_idx` (`user_id` ASC) VISIBLE,
  CONSTRAINT `fk_box_user1`
    FOREIGN KEY (`user_id`)
    REFERENCES `soundmates`.`user` (`user_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `soundmates`.`Match`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `soundmates`.`Match` ;

CREATE TABLE IF NOT EXISTS `soundmates`.`Match` (
  `user1_id` INT NOT NULL,
  `user2_id` INT NOT NULL,
  PRIMARY KEY (`user1_id`, `user2_id`),
  INDEX `fk_user_has_user_user2_idx` (`user2_id` ASC) VISIBLE,
  INDEX `fk_user_has_user_user1_idx` (`user1_id` ASC) VISIBLE,
  CONSTRAINT `fk_user_has_user_user1`
    FOREIGN KEY (`user1_id`)
    REFERENCES `soundmates`.`user` (`user_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_user_has_user_user2`
    FOREIGN KEY (`user2_id`)
    REFERENCES `soundmates`.`user` (`user_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `soundmates`.`super_likes`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `soundmates`.`super_likes` ;

CREATE TABLE IF NOT EXISTS `soundmates`.`super_likes` (
  `liker_id` INT NOT NULL,
  `liked_id` INT NOT NULL,
  PRIMARY KEY (`liker_id`, `liked_id`),
  INDEX `fk_user_has_user_user4_idx` (`liked_id` ASC) VISIBLE,
  INDEX `fk_user_has_user_user3_idx` (`liker_id` ASC) VISIBLE,
  CONSTRAINT `fk_user_has_user_user3`
    FOREIGN KEY (`liker_id`)
    REFERENCES `soundmates`.`user` (`user_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_user_has_user_user4`
    FOREIGN KEY (`liked_id`)
    REFERENCES `soundmates`.`user` (`user_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;


-- -----------------------------------------------------
-- Table `soundmates`.`interaction`
-- -----------------------------------------------------
DROP TABLE IF EXISTS `soundmates`.`interaction` ;

CREATE TABLE IF NOT EXISTS `soundmates`.`interaction` (
  `subject_id` INT NOT NULL,
  `object_id` INT NOT NULL,
  `date` TIMESTAMP NOT NULL,
  `type` ENUM('like', 'reject', 'superlike', 'reload', 'de-facto-reject') NOT NULL,
  PRIMARY KEY (`subject_id`, `object_id`),
  INDEX `fk_user_has_user_user6_idx` (`object_id` ASC) VISIBLE,
  INDEX `fk_user_has_user_user5_idx` (`subject_id` ASC) VISIBLE,
  CONSTRAINT `fk_user_has_user_user5`
    FOREIGN KEY (`subject_id`)
    REFERENCES `soundmates`.`user` (`user_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION,
  CONSTRAINT `fk_user_has_user_user6`
    FOREIGN KEY (`object_id`)
    REFERENCES `soundmates`.`user` (`user_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;

-- -----------------------------------------------------
-- Table `soundmates`.`socials'
-- -----------------------------------------------------
CREATE TABLE IF NOT EXISTS `soundmates`.`socials` (
  `user_id` INT NOT NULL,
  `social_info` TEXT NOT NULL,
  PRIMARY KEY (`user_id`),
  INDEX `fk_socials_user_idx` (`user_id` ASC) VISIBLE,
  CONSTRAINT `fk_socials_user`
    FOREIGN KEY (`user_id`)
    REFERENCES `soundmates`.`user` (`user_id`)
    ON DELETE NO ACTION
    ON UPDATE NO ACTION)
ENGINE = InnoDB;



SET SQL_MODE=@OLD_SQL_MODE;
SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS;
SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS;
