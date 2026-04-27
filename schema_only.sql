-- Project 1 — Schema
DROP SCHEMA IF EXISTS ksu;
create schema ksu;
use ksu;

-- building table (new, wasnt in original schema)
-- needed because building was just floating as a varchar in department/classroom/section
CREATE TABLE `building` (
  `building_id`   varchar(15) PRIMARY KEY,
  `name`          varchar(50) NOT NULL,
  `street_number` varchar(10),
  `street_name`   varchar(50),
  `city`          varchar(30),
  `state`         varchar(2),  -- 2 char state code ex: OH, CA
  `zip`           varchar(10), -- varchar not int because of leading zeros
  CONSTRAINT valid_state CHECK (LENGTH(`state`) = 2),
  CONSTRAINT valid_zip   CHECK (`zip` REGEXP '^[0-9]{5}(-[0-9]{4})?$')
);

-- classroom has composite pk (building + room)
-- room 101 exists in every building so you need both to identify it
CREATE TABLE `classroom` (
  `building_id`  varchar(15),
  `room_number`  varchar(7),
  `capacity`     numeric(4,0),
  PRIMARY KEY (`building_id`, `room_number`),
  CONSTRAINT valid_capacity CHECK (`capacity` > 0)
);

-- department - building_id is now a real fk instead of a loose varchar
CREATE TABLE `department` (
  `dept_name`   varchar(20) PRIMARY KEY,
  `building_id` varchar(15),
  `budget`      numeric(12,2),
  CONSTRAINT valid_budget CHECK (`budget` >= 0)
);

CREATE TABLE `course` (
  `course_id` varchar(8) PRIMARY KEY,
  `title`     varchar(50) NOT NULL,
  `dept_name` varchar(20),
  `credits`   numeric(2,0) NOT NULL,
  CONSTRAINT valid_credits CHECK (`credits` > 0 AND `credits` <= 6)
);

-- prereq is a weak entity, both cols are fks to course
CREATE TABLE `prereq` (
  `course_id`  varchar(8),
  `prereq_id`  varchar(8),
  PRIMARY KEY (`course_id`, `prereq_id`)
);

-- ID format: I00001, I00002 etc.
-- salary check kept from original schema
CREATE TABLE `instructor` (
  `ID`         varchar(6) PRIMARY KEY,
  `first_name` varchar(20) NOT NULL,
  `last_name`  varchar(20) NOT NULL,
  `dept_name`  varchar(20),
  `salary`     numeric(8,2),
  CONSTRAINT valid_instructor_id CHECK (`ID` LIKE 'I%' AND LENGTH(`ID`) = 6),
  CONSTRAINT valid_salary        CHECK (`salary` > 29000)
);

-- ID format: S00001, S00002 etc.
-- advisor_id replaces the old advisor table, just a fk to instructor
CREATE TABLE `student` (
  `ID`         varchar(6) PRIMARY KEY,
  `first_name` varchar(20) NOT NULL,
  `last_name`  varchar(20) NOT NULL,
  `dept_name`  varchar(20),
  `advisor_id` varchar(6),  -- nullable, not every student has advisor yet
  CONSTRAINT valid_student_id CHECK (`ID` LIKE 'S%' AND LENGTH(`ID`) = 6)
);

-- ID format: A00, A01 etc. (max 100 admins, A00-A99)
CREATE TABLE `admin` (
  `ID`         varchar(3) PRIMARY KEY,
  `first_name` varchar(20) NOT NULL,
  `last_name`  varchar(20) NOT NULL,
  CONSTRAINT valid_admin_id CHECK (`ID` LIKE 'A%' AND LENGTH(`ID`) = 3)
);

-- one login row per user regardless of role
-- user_id matches the person ID (S00001, I00001, A00)
-- no fk here because one table cant fk to three different tables easily
-- role + id prefix used to route in application/stored procedures later
CREATE TABLE `login` (
  `user_id`  varchar(6) PRIMARY KEY,
  `username` varchar(50) UNIQUE NOT NULL,
  `password` varchar(255) NOT NULL,  -- store hashed not plaintext handled with stored procedure
  `role`     varchar(15) NOT NULL,
  CONSTRAINT valid_role            CHECK (`role` IN ('student', 'instructor', 'admin')),
  CONSTRAINT valid_password_length CHECK (LENGTH(`password`) >= 8)
);

-- parent table for time slot patterns
-- needed so section can fk to time_slot_id as a standalone pk
-- time_slot_id alone is not unique in time_slot (repeats once per day)
-- so without this table there is no valid fk target for section.time_slot_id
CREATE TABLE `time_slot_pattern` (
  `time_slot_id` varchar(4) PRIMARY KEY
);

-- pk trimmed from original (was time_slot_id, day, start_hr, start_min)
-- that was a 2NF violation, start/end times only depend on (id + day)
-- also replaced start_hr/min end_hr/min with actual time columns
CREATE TABLE `time_slot` (
  `time_slot_id` varchar(4),
  `day`          varchar(1),  -- M T W R F S U
  `start_time`   time NOT NULL,
  `end_time`     time NOT NULL,
  PRIMARY KEY (`time_slot_id`, `day`),
  CONSTRAINT valid_day        CHECK (`day` IN ('M','T','W','R','F','S','U')),
  CONSTRAINT valid_time_range CHECK (`end_time` > `start_time`)
);

-- composite pk on 4 cols
-- time_slot_id fks to time_slot_pattern, not time_slot directly
-- section references the pattern id, join through time_slot to get day/time rows
CREATE TABLE `section` (
  `course_id`    varchar(8),
  `sec_id`       varchar(8),
  `semester`     varchar(6),
  `year`         numeric(4,0),
  `building_id`  varchar(15),
  `room_number`  varchar(7),
  `time_slot_id` varchar(4),
  PRIMARY KEY (`course_id`, `sec_id`, `semester`, `year`),
  CONSTRAINT valid_semester CHECK (`semester` IN ('Fall', 'Winter', 'Spring', 'Summer')),
  CONSTRAINT valid_year     CHECK (`year` > 1701 AND `year` < 2100)
);

-- junction table, all cols are part of pk
-- no non-key attributes so it passes 3NF automatically
CREATE TABLE `teaches` (
  `ID`        varchar(6),
  `course_id` varchar(8),
  `sec_id`    varchar(8),
  `semester`  varchar(6),
  `year`      numeric(4,0),
  PRIMARY KEY (`ID`, `course_id`, `sec_id`, `semester`, `year`)
);

-- lookup table for letter grade to gpa points
-- needed because you cant do AVG() on letter grades
CREATE TABLE `grade_value` (
  `letter_grade` varchar(2) PRIMARY KEY,
  `points`       decimal(3,2) NOT NULL,
  CONSTRAINT valid_letter_grade CHECK (`letter_grade` IN ('A','A-','B+','B','B-','C+','C','C-','D+','D','D-','F','W','I')),
  CONSTRAINT valid_points       CHECK (`points` >= 0.0 AND `points` <= 4.0)
);

-- grade is nullable because student enrolls before grade is posted
-- null = currently enrolled, not null = grade submitted
CREATE TABLE `takes` (
  `ID`        varchar(6),
  `course_id` varchar(8),
  `sec_id`    varchar(8),
  `semester`  varchar(6),
  `year`      numeric(4,0),
  `grade`     varchar(2) DEFAULT NULL,
  PRIMARY KEY (`ID`, `course_id`, `sec_id`, `semester`, `year`)
);

-- permanent academic record, survives course/section deletion
-- stores values directly (title, credits, dept) so it doesnt depend on course existing
-- when calculating GPA exclude W (withdrawal) and I (incomplete) from the average
CREATE TABLE `transcript` (
  `ID`         varchar(6),
  `course_id`  varchar(8),
  `sec_id`     varchar(8),
  `title`      varchar(50) NOT NULL,
  `credits`    numeric(2,0) NOT NULL,
  `dept_name`  varchar(20),
  `semester`   varchar(6) NOT NULL,
  `year`       numeric(4,0) NOT NULL,
  `grade`      varchar(2) NOT NULL,
  PRIMARY KEY (`ID`, `course_id`, `sec_id`, `semester`, `year`),
  CONSTRAINT valid_transcript_semester CHECK (`semester` IN ('Fall', 'Winter', 'Spring', 'Summer')),
  CONSTRAINT valid_transcript_year     CHECK (`year` > 1701 AND `year` < 2100),
  CONSTRAINT valid_transcript_credits  CHECK (`credits` > 0 AND `credits` <= 6)
);

-- fks down here so all tables exist before we reference them

ALTER TABLE `classroom`
  ADD FOREIGN KEY (`building_id`)
  REFERENCES `building` (`building_id`)
  ON UPDATE CASCADE;

ALTER TABLE `department`
  ADD FOREIGN KEY (`building_id`)
  REFERENCES `building` (`building_id`)
  ON UPDATE CASCADE;

-- if dept is deleted, set course dept to null instead of deleting course
ALTER TABLE `course`
  ADD FOREIGN KEY (`dept_name`)
  REFERENCES `department` (`dept_name`)
  ON DELETE SET NULL
  ON UPDATE CASCADE;

ALTER TABLE `prereq`
  ADD FOREIGN KEY (`course_id`)
  REFERENCES `course` (`course_id`)
  ON DELETE CASCADE
  ON UPDATE CASCADE;

-- prereq_id also refs course but no cascade, just restrict
ALTER TABLE `prereq`
  ADD FOREIGN KEY (`prereq_id`)
  REFERENCES `course` (`course_id`)
  ON UPDATE CASCADE;

ALTER TABLE `instructor`
  ADD FOREIGN KEY (`dept_name`)
  REFERENCES `department` (`dept_name`)
  ON DELETE SET NULL
  ON UPDATE CASCADE;

ALTER TABLE `student`
  ADD FOREIGN KEY (`dept_name`)
  REFERENCES `department` (`dept_name`)
  ON DELETE SET NULL
  ON UPDATE CASCADE;

-- if advisor (instructor) is deleted, set student advisor to null
ALTER TABLE `student`
  ADD FOREIGN KEY (`advisor_id`)
  REFERENCES `instructor` (`ID`)
  ON DELETE SET NULL;

ALTER TABLE `section`
  ADD FOREIGN KEY (`course_id`)
  REFERENCES `course` (`course_id`)
  ON DELETE CASCADE
  ON UPDATE CASCADE;

-- time_slot rows must belong to a valid pattern
ALTER TABLE `time_slot`
  ADD FOREIGN KEY (`time_slot_id`)
  REFERENCES `time_slot_pattern` (`time_slot_id`)
  ON DELETE CASCADE;

-- section references the pattern, not individual day rows
ALTER TABLE `section`
  ADD FOREIGN KEY (`time_slot_id`)
  REFERENCES `time_slot_pattern` (`time_slot_id`);

-- composite fk to classroom, set null if room is deleted
ALTER TABLE `section`
  ADD FOREIGN KEY (`building_id`, `room_number`)
  REFERENCES `classroom` (`building_id`, `room_number`)
  ON DELETE SET NULL
  ON UPDATE CASCADE;

-- restrict so instructors with teaching history cant be deleted
ALTER TABLE `teaches`
  ADD FOREIGN KEY (`ID`)
  REFERENCES `instructor` (`ID`);

ALTER TABLE `teaches`
  ADD FOREIGN KEY (`course_id`, `sec_id`, `semester`, `year`)
  REFERENCES `section` (`course_id`, `sec_id`, `semester`, `year`)
  ON DELETE CASCADE
  ON UPDATE CASCADE;

-- restrict so students with transcript history cant be deleted
ALTER TABLE `transcript`
  ADD FOREIGN KEY (`ID`)
  REFERENCES `student` (`ID`);

ALTER TABLE `transcript`
  ADD FOREIGN KEY (`grade`)
  REFERENCES `grade_value` (`letter_grade`);

-- restrict so students with enrollment history cant be deleted
ALTER TABLE `takes`
  ADD FOREIGN KEY (`ID`)
  REFERENCES `student` (`ID`);

-- grade fk allows null so students mid semester dont break anything
ALTER TABLE `takes`
  ADD FOREIGN KEY (`grade`)
  REFERENCES `grade_value` (`letter_grade`);

ALTER TABLE `takes`
  ADD FOREIGN KEY (`course_id`, `sec_id`, `semester`, `year`)
  REFERENCES `section` (`course_id`, `sec_id`, `semester`, `year`)
  ON DELETE CASCADE
  ON UPDATE CASCADE;




-- Project 1 — Stored Procedures

-- read all students in db (test page)
DELIMITER $$
DELIMITER //
CREATE PROCEDURE get_all_students()
BEGIN
    SELECT s.ID, s.first_name, s.last_name, s.dept_name, s.advisor_id,
        CONCAT(i.first_name, ' ', i.last_name) AS advisor_name
    FROM student s
    LEFT JOIN instructor i ON s.advisor_id = i.ID;
END //
DELIMITER ;

-- Create student
-- Creates a new student and their login credentials
-- Password is encrypted using SHA2

DELIMITER //
CREATE PROCEDURE create_student(
    IN p_id VARCHAR(6),
    IN p_first_name VARCHAR(20),
    IN p_last_name VARCHAR(20),
    IN p_dept_name VARCHAR(20),
    IN p_advisor_id VARCHAR(6),
    IN p_username VARCHAR(50),
    IN p_password VARCHAR(255)
)
BEGIN
    -- Check department exists
    IF p_dept_name IS NOT NULL AND p_dept_name NOT IN (SELECT dept_name FROM department) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Department does not exist';
    END IF;

    -- Check advisor exists
    IF p_advisor_id IS NOT NULL AND p_advisor_id NOT IN (SELECT ID FROM instructor) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Advisor (instructor) does not exist';
    END IF;

    -- Insert the student
    INSERT INTO student (ID, first_name, last_name, dept_name, advisor_id)
    VALUES (p_id, p_first_name, p_last_name, p_dept_name, p_advisor_id);

    -- Create login with encrypted password
    INSERT INTO login (user_id, username, password, role)
    VALUES (p_id, p_username, SHA2(p_password, 256), 'student');
END //
DELIMITER ;


-- Read student
-- Looks up a student by ID and returns their info with department and advisor names

DELIMITER //
CREATE PROCEDURE read_student(
    IN p_id VARCHAR(6)
)
BEGIN
    SELECT
        s.ID,
        s.first_name,
        s.last_name,
        s.dept_name,
        s.advisor_id,
        CONCAT(i.first_name, ' ', i.last_name) AS advisor_name,
        l.username
    FROM student s
    LEFT JOIN instructor i ON s.advisor_id = i.ID
    LEFT JOIN login l ON l.user_id = s.ID
    WHERE s.ID = p_id;
END //
DELIMITER ;


-- Update student
-- Updates a student's information (except ID)

DELIMITER //
CREATE PROCEDURE update_student(
    IN p_id VARCHAR(6),
    IN p_first_name VARCHAR(20),
    IN p_last_name VARCHAR(20),
    IN p_dept_name VARCHAR(20),
    IN p_advisor_id VARCHAR(6)
)
BEGIN
    -- Check student exists
    IF p_id NOT IN (SELECT ID FROM student) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student does not exist';
    END IF;

    -- Check department exists
    IF p_dept_name IS NOT NULL AND p_dept_name NOT IN (SELECT dept_name FROM department) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Department does not exist';
    END IF;

    -- Check advisor exists
    IF p_advisor_id IS NOT NULL AND p_advisor_id NOT IN (SELECT ID FROM instructor) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Advisor (instructor) does not exist';
    END IF;

    UPDATE student
    SET first_name = p_first_name,
        last_name = p_last_name,
        dept_name = p_dept_name,
        advisor_id = p_advisor_id
    WHERE ID = p_id;
END //
DELIMITER ;


-- Delete student
-- Deletes a student only if they have no enrollment or transcript records
-- Also cleans up their login row

DELIMITER //
CREATE PROCEDURE delete_student(
    IN p_id VARCHAR(6)
)
BEGIN
    -- Check student exists
    IF p_id NOT IN (SELECT ID FROM student) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student does not exist';
    END IF;

    -- Check for enrollment records
    IF EXISTS (SELECT 1 FROM takes WHERE ID = p_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot delete: student has enrollment records';
    END IF;

    -- Check for transcript records
    IF EXISTS (SELECT 1 FROM transcript WHERE ID = p_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot delete: student has transcript records';
    END IF;

    -- Remove login first
    DELETE FROM login WHERE user_id = p_id;

    -- Then delete the student
    DELETE FROM student WHERE ID = p_id;
END //
DELIMITER ;

-- Create Instructor

DELIMITER //
CREATE PROCEDURE create_instructor(
    IN p_id VARCHAR(6),
    IN p_first_name VARCHAR(20),
    IN p_last_name VARCHAR(20),
    IN p_dept_name VARCHAR(20),
    IN p_salary NUMERIC(8,2),
    IN p_username VARCHAR(50),
    IN p_password VARCHAR(255)
)
BEGIN
    -- Check department exists
    IF p_dept_name IS NOT NULL AND p_dept_name NOT IN (SELECT dept_name FROM department) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Department does not exist';
    END IF;

    -- Insert the instructor
    INSERT INTO instructor (ID, first_name, last_name, dept_name, salary)
    VALUES (p_id, p_first_name, p_last_name, p_dept_name, p_salary);

    -- Create their login with encrypted password
    INSERT INTO login (user_id, username, password, role)
    VALUES (p_id, p_username, SHA2(p_password, 256), 'instructor');
END //
DELIMITER ;


-- Read instructor

DELIMITER //
CREATE PROCEDURE read_instructor(
    IN p_id VARCHAR(6)
)
BEGIN
    SELECT
        i.ID,
        i.first_name,
        i.last_name,
        i.dept_name,
        i.salary,
        login.username
    FROM instructor i
    JOIN login ON login.user_id = i.ID
    WHERE i.ID = p_id;
END //
DELIMITER ;


-- Update instructor

DELIMITER //
CREATE PROCEDURE update_instructor(
    IN p_id VARCHAR(6),
    IN p_first_name VARCHAR(20),
    IN p_last_name VARCHAR(20),
    IN p_dept_name VARCHAR(20),
    IN p_salary NUMERIC(8,2)
)
BEGIN
    -- Check instructor exists
    IF p_id NOT IN (SELECT ID FROM instructor) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Instructor does not exist';
    END IF;

    -- Check department exists
    IF p_dept_name IS NOT NULL AND p_dept_name NOT IN (SELECT dept_name FROM department) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Department does not exist';
    END IF;

    UPDATE instructor
    SET first_name = p_first_name,
        last_name = p_last_name,
        dept_name = p_dept_name,
        salary = p_salary
    WHERE ID = p_id;
END //
DELIMITER ;


-- Delete instructor
-- Block if instructor has teaching history
-- Sets student.advisor_id to NULL for any advisees that are deleted

DELIMITER //
CREATE PROCEDURE delete_instructor(
    IN p_id VARCHAR(6)
)
BEGIN
    -- Check instructor exists
    IF p_id NOT IN (SELECT ID FROM instructor) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Instructor does not exist';
    END IF;

    -- Check for teaching history
    IF EXISTS (SELECT 1 FROM teaches WHERE ID = p_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot delete: instructor has teaching history';
    END IF;

    -- Delete login
    DELETE FROM login WHERE user_id = p_id;

    -- Delete the instructor
    DELETE FROM instructor WHERE ID = p_id;
END //
DELIMITER ;

-- Create section

DELIMITER //
CREATE PROCEDURE create_section(
    IN p_course_id VARCHAR(8),
    IN p_sec_id VARCHAR(8),
    IN p_semester VARCHAR(6),
    IN p_year NUMERIC(4,0),
    IN p_building_id VARCHAR(15),
    IN p_room_number VARCHAR(7),
    IN p_time_slot_id VARCHAR(4)
)
BEGIN
    -- Check course exists
    IF p_course_id NOT IN (SELECT course_id FROM course) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Course does not exist';
    END IF;

    -- Check classroom exists
    IF p_building_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM classroom WHERE building_id = p_building_id AND room_number = p_room_number
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Classroom does not exist';
    END IF;

    -- Check time slot pattern exists
    IF p_time_slot_id IS NOT NULL AND p_time_slot_id NOT IN (SELECT time_slot_id FROM time_slot_pattern) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Time slot pattern does not exist';
    END IF;

    INSERT INTO section (course_id, sec_id, semester, year, building_id, room_number, time_slot_id)
    VALUES (p_course_id, p_sec_id, p_semester, p_year, p_building_id, p_room_number, p_time_slot_id);
END //
DELIMITER ;


-- Read section
-- Returns section info with course title, room details, and time schedule

DELIMITER //
CREATE PROCEDURE read_section(
    IN p_course_id VARCHAR(8),
    IN p_sec_id VARCHAR(8),
    IN p_semester VARCHAR(6),
    IN p_year NUMERIC(4,0)
)
BEGIN
    SELECT
        s.course_id,
        c.title AS course_title,
        s.sec_id,
        s.semester,
        s.year,
        s.building_id,
        s.room_number,
        cl.capacity,
        s.time_slot_id,
        CONCAT(i.first_name, ' ', i.last_name) AS instructor_name
    FROM section s
    JOIN course c ON s.course_id = c.course_id
    LEFT JOIN classroom cl ON s.building_id = cl.building_id AND s.room_number = cl.room_number
    LEFT JOIN teaches t ON s.course_id = t.course_id AND s.sec_id = t.sec_id
        AND s.semester = t.semester AND s.year = t.year
    LEFT JOIN instructor i ON t.ID = i.ID
    WHERE s.course_id = p_course_id
        AND s.sec_id = p_sec_id
        AND s.semester = p_semester
        AND s.year = p_year;
END //
DELIMITER ;


-- Update Section

DELIMITER //
CREATE PROCEDURE update_section(
    IN p_course_id VARCHAR(8),
    IN p_sec_id VARCHAR(8),
    IN p_semester VARCHAR(6),
    IN p_year NUMERIC(4,0),
    IN p_building_id VARCHAR(15),
    IN p_room_number VARCHAR(7),
    IN p_time_slot_id VARCHAR(4)
)
BEGIN
    -- Check section exists
    IF NOT EXISTS (
        SELECT 1 FROM section
        WHERE course_id = p_course_id AND sec_id = p_sec_id
            AND semester = p_semester AND year = p_year
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Section does not exist';
    END IF;

    -- Check classroom exists
    IF p_building_id IS NOT NULL AND NOT EXISTS (
        SELECT 1 FROM classroom WHERE building_id = p_building_id AND room_number = p_room_number
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Classroom does not exist';
    END IF;

    -- Check time slot pattern exists
    IF p_time_slot_id IS NOT NULL AND p_time_slot_id NOT IN (SELECT time_slot_id FROM time_slot_pattern) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Time slot pattern does not exist';
    END IF;

    UPDATE section
    SET building_id = p_building_id,
        room_number = p_room_number,
        time_slot_id = p_time_slot_id
    WHERE course_id = p_course_id
        AND sec_id = p_sec_id
        AND semester = p_semester
        AND year = p_year;
END //
DELIMITER ;


-- Delete/drop section
-- Archives graded enrollments to transcript before deleting

DELIMITER //
CREATE PROCEDURE delete_section(
    IN p_course_id VARCHAR(8),
    IN p_sec_id VARCHAR(8),
    IN p_semester VARCHAR(6),
    IN p_year NUMERIC(4,0)
)
BEGIN
    -- Check section exists
    IF NOT EXISTS (
        SELECT 1 FROM section
        WHERE course_id = p_course_id AND sec_id = p_sec_id
            AND semester = p_semester AND year = p_year
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Section does not exist';
    END IF;

    -- Archive graded enrollments to transcript before deletion
    INSERT IGNORE INTO transcript (ID, course_id, sec_id, title, credits, dept_name, semester, year, grade)
    SELECT
        t.ID,
        t.course_id,
        t.sec_id,
        c.title,
        c.credits,
        c.dept_name,
        t.semester,
        t.year,
        t.grade
    FROM takes t
    JOIN course c ON t.course_id = c.course_id
    WHERE t.course_id = p_course_id
        AND t.sec_id = p_sec_id
        AND t.semester = p_semester
        AND t.year = p_year
        AND t.grade IS NOT NULL;

    -- Delete the section
    DELETE FROM section
    WHERE course_id = p_course_id
        AND sec_id = p_sec_id
        AND semester = p_semester
        AND year = p_year;
END //
DELIMITER ;

-- Enroll in class
-- Checks student exists, section exists, and prerequisites are met

DELIMITER //
CREATE PROCEDURE enroll_student(
    IN p_student_id VARCHAR(6),
    IN p_course_id VARCHAR(8),
    IN p_sec_id VARCHAR(8),
    IN p_semester VARCHAR(6),
    IN p_year NUMERIC(4,0)
)
BEGIN
    -- Check student exists
    IF p_student_id NOT IN (SELECT ID FROM student) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student does not exist';
    END IF;

    -- Check section exists
    IF NOT EXISTS (
        SELECT 1 FROM section
        WHERE course_id = p_course_id AND sec_id = p_sec_id
            AND semester = p_semester AND year = p_year
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Section does not exist';
    END IF;

    -- Check student is not already enrolled in this section
    IF EXISTS (
        SELECT 1 FROM takes
        WHERE ID = p_student_id AND course_id = p_course_id
            AND sec_id = p_sec_id AND semester = p_semester AND year = p_year
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student is already enrolled in this section';
    END IF;

    -- Check prerequisites: student must have completed all prereqs for this course
    IF EXISTS (
        SELECT prereq_id FROM prereq
        WHERE course_id = p_course_id
        AND prereq_id NOT IN (
            SELECT course_id FROM transcript WHERE ID = p_student_id
        )
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Prerequisites not met';
    END IF;

    -- Check capacity: count current enrollments vs classroom capacity
    IF (
        SELECT COUNT(*) FROM takes
        WHERE course_id = p_course_id AND sec_id = p_sec_id
            AND semester = p_semester AND year = p_year
    ) >= (
        SELECT cl.capacity
        FROM section s
        JOIN classroom cl ON s.building_id = cl.building_id AND s.room_number = cl.room_number
        WHERE s.course_id = p_course_id AND s.sec_id = p_sec_id
            AND s.semester = p_semester AND s.year = p_year
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Section is full';
    END IF;

    -- All checks passed = enroll
    INSERT INTO takes (ID, course_id, sec_id, semester, year, grade)
    VALUES (p_student_id, p_course_id, p_sec_id, p_semester, p_year, NULL);
END //
DELIMITER ;


-- Assign instructor to class

DELIMITER //
CREATE PROCEDURE assign_instructor(
    IN p_instructor_id VARCHAR(6),
    IN p_course_id VARCHAR(8),
    IN p_sec_id VARCHAR(8),
    IN p_semester VARCHAR(6),
    IN p_year NUMERIC(4,0)
)
BEGIN
    -- Check instructor exists
    IF p_instructor_id NOT IN (SELECT ID FROM instructor) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Instructor does not exist';
    END IF;

    -- Check section exists
    IF NOT EXISTS (
        SELECT 1 FROM section
        WHERE course_id = p_course_id AND sec_id = p_sec_id
            AND semester = p_semester AND year = p_year
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Section does not exist';
    END IF;

    -- Check instructor is not already assigned to this section
    IF EXISTS (
        SELECT 1 FROM teaches
        WHERE ID = p_instructor_id AND course_id = p_course_id
            AND sec_id = p_sec_id AND semester = p_semester AND year = p_year
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Instructor is already assigned to this section';
    END IF;

    INSERT INTO teaches (ID, course_id, sec_id, semester, year)
    VALUES (p_instructor_id, p_course_id, p_sec_id, p_semester, p_year);
END //
DELIMITER ;


-- Give a grade
-- Uses a transaction so both steps succeed or both fail

DELIMITER //
CREATE PROCEDURE give_grade(
    IN p_student_id VARCHAR(6),
    IN p_course_id VARCHAR(8),
    IN p_sec_id VARCHAR(8),
    IN p_semester VARCHAR(6),
    IN p_year NUMERIC(4,0),
    IN p_grade VARCHAR(2)
)
BEGIN
    -- Check the enrollment exists
    IF NOT EXISTS (
        SELECT 1 FROM takes
        WHERE ID = p_student_id AND course_id = p_course_id
            AND sec_id = p_sec_id AND semester = p_semester AND year = p_year
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Student is not enrolled in this section';
    END IF;

    -- Check grade is valid
    IF p_grade NOT IN (SELECT letter_grade FROM grade_value) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid grade';
    END IF;

    -- Start transaction — both steps must succeed together
    START TRANSACTION;

    -- Step 1: Update the grade in takes
    UPDATE takes
    SET grade = p_grade
    WHERE ID = p_student_id
        AND course_id = p_course_id
        AND sec_id = p_sec_id
        AND semester = p_semester
        AND year = p_year;

    -- Step 2: Archive to transcript (pull course info at this moment)
    INSERT INTO transcript (ID, course_id, sec_id, title, credits, dept_name, semester, year, grade)
    SELECT
        p_student_id,
        p_course_id,
        p_sec_id,
        c.title,
        c.credits,
        c.dept_name,
        p_semester,
        p_year,
        p_grade
    FROM course c
    WHERE c.course_id = p_course_id
    ON DUPLICATE KEY UPDATE grade = p_grade;

    COMMIT;
END //
DELIMITER ;


-- Login procedure
-- Verifies username and password, returns user info if valid

DELIMITER //
CREATE PROCEDURE user_login(
    IN p_username VARCHAR(50),
    IN p_password VARCHAR(255)
)
BEGIN
    DECLARE v_user_id VARCHAR(6);
    DECLARE v_role VARCHAR(15);

    -- Look up the user by username and hashed password
    SELECT user_id, role INTO v_user_id, v_role
    FROM login
    WHERE username = p_username AND password = SHA2(p_password, 256);

    -- If no match found, v_user_id will be NULL
    IF v_user_id IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Invalid username or password';
    END IF;

    -- Return the user info based on their role
    IF v_role = 'student' THEN
        SELECT s.ID, s.first_name, s.last_name, s.dept_name, v_role AS role
        FROM student s WHERE s.ID = v_user_id;
    ELSEIF v_role = 'instructor' THEN
        SELECT i.ID, i.first_name, i.last_name, i.dept_name, v_role AS role
        FROM instructor i WHERE i.ID = v_user_id;
    ELSEIF v_role = 'admin' THEN
        SELECT a.ID, a.first_name, a.last_name, v_role AS role
        FROM admin a WHERE a.ID = v_user_id;
    END IF;
END //
DELIMITER ;

-- Create course

DELIMITER //
CREATE PROCEDURE create_course(
    IN p_course_id VARCHAR(8),
    IN p_title VARCHAR(50),
    IN p_dept_name VARCHAR(20),
    IN p_credits NUMERIC(2,0)
)
BEGIN
    -- Check course doesn't already exist
    IF p_course_id IN (SELECT course_id FROM course) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Course already exists';
    END IF;

    -- Check department exists
    IF p_dept_name IS NOT NULL AND p_dept_name NOT IN (SELECT dept_name FROM department) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Department does not exist';
    END IF;

    INSERT INTO course (course_id, title, dept_name, credits)
    VALUES (p_course_id, p_title, p_dept_name, p_credits);
END //
DELIMITER ;



-- Add prerequisite to a course

DELIMITER //
CREATE PROCEDURE add_prereq(
    IN p_course_id VARCHAR(8),
    IN p_prereq_id VARCHAR(8)
)
BEGIN
    -- Can't be its own prereq
    IF p_course_id = p_prereq_id THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A course cannot be its own prerequisite';
    END IF;

    -- Check course exists
    IF p_course_id NOT IN (SELECT course_id FROM course) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Course does not exist';
    END IF;

    -- Check prereq course exists
    IF p_prereq_id NOT IN (SELECT course_id FROM course) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Prerequisite course does not exist';
    END IF;

    -- Check for duplicate
    IF EXISTS (
        SELECT 1 FROM prereq
        WHERE course_id = p_course_id AND prereq_id = p_prereq_id
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Prerequisite already exists for this course';
    END IF;

    INSERT INTO prereq (course_id, prereq_id)
    VALUES (p_course_id, p_prereq_id);
END //
DELIMITER ;


-- Get all instructors
DELIMITER //
CREATE PROCEDURE get_all_instructors()
BEGIN
    SELECT * FROM instructor;
END //
DELIMITER ;

-- Get all courses
DELIMITER //
CREATE PROCEDURE get_all_courses()
BEGIN
    SELECT * FROM course;
END //
DELIMITER ;

-- Get all sections
DELIMITER //
CREATE PROCEDURE get_all_sections()
BEGIN
    SELECT * FROM section;
END //
DELIMITER ;

-- Get all departments
DELIMITER //
CREATE PROCEDURE get_all_departments()
BEGIN
    SELECT * FROM department;
END //
DELIMITER ;

-- Get all classrooms
DELIMITER //
CREATE PROCEDURE get_all_classrooms()
BEGIN
    SELECT * FROM classroom;
END //
DELIMITER ;

-- Get all timeslots
DELIMITER //
CREATE PROCEDURE get_all_timeslots()
BEGIN
    SELECT * FROM time_slot;
END //
DELIMITER ;

-- Get all buildings
DELIMITER //
CREATE PROCEDURE get_all_buildings()
BEGIN
    SELECT * FROM building;
END //
DELIMITER ;


-- update student with username gholmes and bjackson so i can test schedule page and transcript
UPDATE login SET password = SHA2('test123', 256) WHERE user_id = 'S00004';

UPDATE login SET password = SHA2('test123', 256) WHERE user_id = 'S00054';

-- update instructor mpena and jclarke to use for testing
UPDATE login SET password = SHA2('test123', 256) WHERE user_id = 'I00001';
UPDATE login SET password = SHA2('test123', 256) WHERE user_id = 'I00008';

-- read student transcript return all fields where there is valid grades
DELIMITER //
CREATE PROCEDURE read_student_transcript(IN student_id VARCHAR(6))
BEGIN
    SELECT * FROM transcript
        JOIN grade_value ON transcript.grade = grade_value.letter_grade
    WHERE transcript.ID = student_id
    ORDER BY year DESC, semester;
END //
DELIMITER ;

-- Student schedule: returns current and past schedule for jinja to filter for display
DELIMITER //
CREATE PROCEDURE get_student_schedule(IN student_id VARCHAR(6))
BEGIN
    SELECT
        takes.course_id,
        takes.sec_id,
        takes.semester,
        takes.year,
        takes.grade,
        course.title,
        course.credits,
        classroom.building_id,
        classroom.room_number,
        GROUP_CONCAT(time_slot.day ORDER BY time_slot.day) AS days,
        MIN(time_slot.start_time) AS start_time,
        MIN(time_slot.end_time) AS end_time

    from takes
    JOIN section ON takes.sec_id = section.sec_id
        AND takes.course_id = section.course_id
        AND takes.semester = section.semester
        AND takes.year = section.year

    JOIN course ON section.course_id = course.course_id
    JOIN time_slot ON section.time_slot_id = time_slot.time_slot_id
    JOIN classroom ON section.building_id = classroom.building_id
        AND section.room_number = classroom.room_number

    where takes.ID = student_id

    GROUP BY
        takes.course_id,
        takes.sec_id,
        takes.semester,
        takes.year,
        takes.grade,
        course.title,
        course.credits,
        classroom.building_id,
        classroom.room_number;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE get_sections_by_term(IN semester VARCHAR(6), IN year NUMERIC(4,0))
BEGIN
    SELECT
        section.course_id, course.title,
        course.dept_name, course.credits,
        section.sec_id, section.semester,
        section.year, section.building_id,
        section.room_number,
        COUNT(DISTINCT takes.ID) as enrolled_students,
        classroom.capacity,
        GROUP_CONCAT(time_slot.day ORDER BY time_slot.day) as days,
        MIN(time_slot.start_time) as start_time, MIN(time_slot.end_time) as end_time
        FROM section
        JOIN course ON course.course_id = section.course_id
        JOIN time_slot ON section.time_slot_id = time_slot.time_slot_id
        LEFT JOIN takes ON takes.course_id = section.course_id
            AND takes.sec_id = section.sec_id
            AND takes.semester = section.semester
            AND takes.year = section.year
        LEFT JOIN classroom ON classroom.room_number = section.room_number
            AND classroom.building_id = section.building_id
        WHERE section.year=year AND section.semester = semester
        GROUP BY section.course_id, course.title,
        course.dept_name, course.credits,
        section.sec_id, section.semester,
        section.year, section.building_id,
        section.room_number, classroom.capacity
        ORDER BY section.year DESC;
END //
DELIMITER ;


-- Department CRUD
-- Create department (Admin)
DELIMITER //
CREATE PROCEDURE create_department(
    IN p_dept_name VARCHAR(20),
    IN p_building_id VARCHAR(15),
    IN p_budget NUMERIC(12,2)
)
BEGIN
    IF p_dept_name IN (SELECT dept_name FROM department) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Department already exists';
    END IF;

    IF p_building_id IS NOT NULL AND p_building_id NOT IN (SELECT building_id FROM building) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Building does not exist';
    END IF;

    INSERT INTO department (dept_name, building_id, budget)
    VALUES (p_dept_name, p_building_id, p_budget);
END //
DELIMITER ;

-- Update department (Admin)
DELIMITER //
CREATE PROCEDURE update_department(
    IN p_dept_name VARCHAR(20),
    IN p_building_id VARCHAR(15),
    IN p_budget NUMERIC(12,2)
)
BEGIN
    IF p_dept_name NOT IN (SELECT dept_name FROM department) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Department does not exist';
    END IF;

    UPDATE department
    SET building_id = p_building_id,
        budget = p_budget
    WHERE dept_name = p_dept_name;
END //
DELIMITER ;

-- Delete department (Admin)
DELIMITER //
CREATE PROCEDURE delete_department(
    IN p_dept_name VARCHAR(20)
)
BEGIN
    IF p_dept_name NOT IN (SELECT dept_name FROM department) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Department does not exist';
    END IF;

    IF EXISTS (SELECT 1 FROM instructor WHERE dept_name = p_dept_name) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot delete: instructors exist in this department';
    END IF;

    IF EXISTS (SELECT 1 FROM student WHERE dept_name = p_dept_name) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot delete: students exist in this department';
    END IF;

    DELETE FROM department WHERE dept_name = p_dept_name;
END //
DELIMITER ;

-- Classroom CRUD
-- Create classroom (Admin)
DELIMITER //
CREATE PROCEDURE create_classroom(
    IN p_building_id VARCHAR(15),
    IN p_room_number VARCHAR(7),
    IN p_capacity NUMERIC(4,0)
)
BEGIN
    IF EXISTS (SELECT 1 FROM classroom WHERE building_id = p_building_id AND room_number = p_room_number) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Classroom already exists';
    END IF;

    IF p_building_id NOT IN (SELECT building_id FROM building) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Building does not exist';
    END IF;

    INSERT INTO classroom (building_id, room_number, capacity)
    VALUES (p_building_id, p_room_number, p_capacity);
END //
DELIMITER ;

-- Update classroom (Admin)
DELIMITER //
CREATE PROCEDURE update_classroom(
    IN p_building_id VARCHAR(15),
    IN p_room_number VARCHAR(7),
    IN p_capacity NUMERIC(4,0)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM classroom WHERE building_id = p_building_id AND room_number = p_room_number) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Classroom does not exist';
    END IF;

    UPDATE classroom
    SET capacity = p_capacity
    WHERE building_id = p_building_id AND room_number = p_room_number;
END //
DELIMITER ;

-- Delete classroom (Admin)
DELIMITER //
CREATE PROCEDURE delete_classroom(
    IN p_building_id VARCHAR(15),
    IN p_room_number VARCHAR(7)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM classroom WHERE building_id = p_building_id AND room_number = p_room_number) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Classroom does not exist';
    END IF;

    IF EXISTS (SELECT 1 FROM section WHERE building_id = p_building_id AND room_number = p_room_number) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot delete: classroom is assigned to a section';
    END IF;

    DELETE FROM classroom WHERE building_id = p_building_id AND room_number = p_room_number;
END //
DELIMITER ;

-- Course CRUD
-- Update course (Admin)
DELIMITER //
CREATE PROCEDURE update_course(
    IN p_course_id VARCHAR(8),
    IN p_title VARCHAR(50),
    IN p_dept_name VARCHAR(20),
    IN p_credits NUMERIC(2,0)
)
BEGIN
    IF p_course_id NOT IN (SELECT course_id FROM course) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Course does not exist';
    END IF;

    IF p_dept_name IS NOT NULL AND p_dept_name NOT IN (SELECT dept_name FROM department) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Department does not exist';
    END IF;

    UPDATE course
    SET title = p_title,
        dept_name = p_dept_name,
        credits = p_credits
    WHERE course_id = p_course_id;
END //
DELIMITER ;

-- Delete course (Admin)
DELIMITER //
CREATE PROCEDURE delete_course(
    IN p_course_id VARCHAR(8)
)
BEGIN
    IF p_course_id NOT IN (SELECT course_id FROM course) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Course does not exist';
    END IF;

    IF EXISTS (SELECT 1 FROM section WHERE course_id = p_course_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot delete: course has existing sections';
    END IF;

    DELETE FROM prereq WHERE course_id = p_course_id OR prereq_id = p_course_id;
    DELETE FROM course WHERE course_id = p_course_id;
END //
DELIMITER ;

-- Timeslot CRUD
-- Create Timeslot (Admin)
DELIMITER //
CREATE PROCEDURE create_timeslot(
    IN p_time_slot_id VARCHAR(4),
    IN p_day VARCHAR(1),
    IN p_start_time TIME,
    IN p_end_time TIME
)
BEGIN
    IF p_time_slot_id NOT IN (SELECT time_slot_id FROM time_slot_pattern) THEN
        INSERT INTO time_slot_pattern (time_slot_id) VALUES (p_time_slot_id);
    END IF;

    IF EXISTS (SELECT 1 FROM time_slot WHERE time_slot_id = p_time_slot_id AND day = p_day) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This time slot already has an entry for that day';
    END IF;

    INSERT INTO time_slot (time_slot_id, day, start_time, end_time)
    VALUES (p_time_slot_id, p_day, p_start_time, p_end_time);
END //
DELIMITER ;

-- Delete Timeslot (Admin)
DELIMITER //
CREATE PROCEDURE delete_timeslot(
    IN p_time_slot_id VARCHAR(4),
    IN p_day VARCHAR(1)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM time_slot WHERE time_slot_id = p_time_slot_id AND day = p_day) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Time slot entry does not exist';
    END IF;

    IF (SELECT COUNT(*) FROM time_slot WHERE time_slot_id = p_time_slot_id) = 1
       AND EXISTS (SELECT 1 FROM section WHERE time_slot_id = p_time_slot_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cannot delete: time slot is assigned to a section';
    END IF;

    DELETE FROM time_slot WHERE time_slot_id = p_time_slot_id AND day = p_day;

    IF NOT EXISTS (SELECT 1 FROM time_slot WHERE time_slot_id = p_time_slot_id) THEN
        DELETE FROM time_slot_pattern WHERE time_slot_id = p_time_slot_id;
    END IF;
END //
DELIMITER ;

-- Update Timeslot (Admin)
DELIMITER //
CREATE PROCEDURE update_timeslot(
    IN p_time_slot_id VARCHAR(4),
    IN p_day VARCHAR(1),
    IN p_start_time TIME,
    IN p_end_time TIME
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM time_slot WHERE time_slot_id = p_time_slot_id AND day = p_day) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Time slot entry does not exist';
    END IF;

    UPDATE time_slot
    SET start_time = p_start_time,
        end_time = p_end_time
    WHERE time_slot_id = p_time_slot_id AND day = p_day;
END //
DELIMITER ;

-- Get all time slots with formatted times and ordered by day
DROP PROCEDURE IF EXISTS get_all_timeslots;

DELIMITER //
CREATE PROCEDURE get_all_timeslots()
BEGIN
    SELECT time_slot_id, day,
        TIME_FORMAT(start_time, '%h:%i %p') AS start_time,
        TIME_FORMAT(end_time, '%h:%i %p') AS end_time
    FROM time_slot
    ORDER BY time_slot_id, FIELD(day, 'M', 'T', 'W', 'R', 'F', 'S');
END //
DELIMITER ;

--
DELIMITER //
CREATE PROCEDURE get_droppable_courses(IN student_id VARCHAR(6))
BEGIN
    SELECT takes.course_id, takes.sec_id, takes.semester, takes.year,
           course.title, course.credits,
           classroom.building_id, classroom.room_number,
           GROUP_CONCAT(time_slot.day ORDER BY time_slot.day) AS days,
           MIN(time_slot.start_time) AS start_time,
           MIN(time_slot.end_time) AS end_time
    FROM takes
    JOIN section ON takes.sec_id = section.sec_id
        AND takes.course_id = section.course_id
        AND takes.semester = section.semester
        AND takes.year = section.year
    JOIN course ON section.course_id = course.course_id
    JOIN time_slot ON section.time_slot_id = time_slot.time_slot_id
    JOIN classroom ON section.building_id = classroom.building_id
        AND section.room_number = classroom.room_number
    WHERE takes.ID = student_id
        AND takes.grade IS NULL
    GROUP BY takes.course_id, takes.sec_id, takes.semester, takes.year,
             course.title, course.credits, classroom.building_id, classroom.room_number;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE drop_enrollment(
    IN p_student_id VARCHAR(6),
    IN p_course_id VARCHAR(8),
    IN p_sec_id VARCHAR(8),
    IN p_semester VARCHAR(6),
    IN p_year NUMERIC(4,0)
)
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM takes WHERE ID = p_student_id AND course_id = p_course_id
        AND sec_id = p_sec_id AND semester = p_semester AND year = p_year AND grade IS NULL
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Enrollment not found or already graded';
    END IF;
    DELETE FROM takes WHERE ID = p_student_id AND course_id = p_course_id
        AND sec_id = p_sec_id AND semester = p_semester AND year = p_year;
END //
DELIMITER ;


-- prereq check that pairs with register for classes page
DELIMITER //
CREATE PROCEDURE get_eligible_courses(IN p_student_id VARCHAR(6))
BEGIN
    SELECT DISTINCT course_id FROM course
    WHERE NOT EXISTS (
        SELECT prereq_id FROM prereq
        WHERE prereq.course_id = course.course_id
        AND prereq_id NOT IN (SELECT course_id FROM transcript WHERE ID = p_student_id)
    );
END //
DELIMITER ;

-- admin, instructor and student change password while session is currently logged on
DELIMITER //
CREATE PROCEDURE change_password(IN p_id VARCHAR(6), IN p_new_password VARCHAR(255))
BEGIN
    UPDATE login SET password = SHA2(p_new_password, 256) WHERE user_id = p_id;
END //
DELIMITER ;

-- returns current advisees for instructor
DELIMITER //
CREATE PROCEDURE get_advisees(IN p_instructor_id VARCHAR(6))
BEGIN
    SELECT s.ID, s.first_name, s.last_name, s.dept_name, l.username
    FROM student s
    JOIN login l ON l.user_id = s.ID
    WHERE s.advisor_id = p_instructor_id
    ORDER BY s.last_name;
END //
DELIMITER ;

-- instructor drop down menu for adding an unadvised student
DELIMITER //
CREATE PROCEDURE get_unadvised_students()
BEGIN
    SELECT s.ID, s.first_name, s.last_name
    FROM student s
    WHERE s.advisor_id IS NULL
    ORDER BY s.last_name;
END //
DELIMITER ;

-- update student with new advisor role assigned by instructor

DELIMITER //
CREATE PROCEDURE assign_advisor(IN p_student_id VARCHAR(6), IN p_instructor_id VARCHAR(6))
BEGIN
    UPDATE student SET advisor_id = p_instructor_id WHERE ID = p_student_id;
END //
DELIMITER ;

DELIMITER //
CREATE PROCEDURE drop_advisee(IN p_student_id VARCHAR(6))
BEGIN
    UPDATE student SET advisor_id = NULL WHERE ID = p_student_id;
END //
DELIMITER ;

-- find teaches sections for filtering by most recent finished term
DELIMITER //
CREATE PROCEDURE get_instructor_sections(IN p_instructor_id VARCHAR(6), IN p_semester VARCHAR(6), IN p_year NUMERIC(4,0))
BEGIN
    SELECT t.course_id, t.sec_id, t.semester, t.year, c.title
    FROM teaches t
    JOIN course c ON c.course_id = t.course_id
    WHERE t.ID = p_instructor_id AND t.semester = p_semester AND t.year = p_year;
END //
DELIMITER ;

-- return students class roster for instructor
DELIMITER //
CREATE PROCEDURE get_section_roster(IN p_course_id VARCHAR(8), IN p_sec_id VARCHAR(8), IN p_semester VARCHAR(6), IN p_year NUMERIC(4,0))
BEGIN
    SELECT s.ID, s.first_name, s.last_name, tk.grade
    FROM takes tk
    JOIN student s ON s.ID = tk.ID
    WHERE tk.course_id = p_course_id AND tk.sec_id = p_sec_id
        AND tk.semester = p_semester AND tk.year = p_year
    ORDER BY s.last_name;
END //
DELIMITER ;

-- Admin removing an instructor
DELIMITER //
CREATE PROCEDURE remove_instructor(
    IN p_instructor_id VARCHAR(6),
    IN p_course_id VARCHAR(8),
    IN p_sec_id VARCHAR(8),
    IN p_semester VARCHAR(6),
    IN p_year NUMERIC(4,0)
)
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM teaches
        WHERE ID = p_instructor_id AND course_id = p_course_id
            AND sec_id = p_sec_id AND semester = p_semester AND year = p_year
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'This instructor is not assigned to this section';
    END IF;

    DELETE FROM teaches
    WHERE ID = p_instructor_id
        AND course_id = p_course_id
        AND sec_id = p_sec_id
        AND semester = p_semester
        AND year = p_year;
END //
DELIMITER ;

-- What classes an instructor teaches
DELIMITER //
CREATE PROCEDURE get_all_teaches()
BEGIN
    SELECT
        t.ID AS instructor_id,
        CONCAT(i.first_name, ' ', i.last_name) AS instructor_name,
        t.course_id,
        t.sec_id,
        t.semester,
        t.year
    FROM teaches t
    JOIN instructor i ON t.ID = i.ID
    ORDER BY t.year DESC, t.semester, t.course_id;
END //
DELIMITER ;

-- Update Admin Information
DELIMITER //
CREATE PROCEDURE update_admin_profile(
    IN p_id VARCHAR(3),
    IN p_first_name VARCHAR(20),
    IN p_last_name VARCHAR(20),
    IN p_username VARCHAR(50),
    IN p_password VARCHAR(255)
)
BEGIN
    UPDATE admin
    SET first_name = p_first_name,
        last_name = p_last_name
    WHERE ID = p_id;

    UPDATE login
    SET username = p_username,
        password = SHA2(p_password, 256)
    WHERE user_id = p_id;
END //
DELIMITER ;

-- Additional Queries

-- Average grade by department
DELIMITER //
CREATE PROCEDURE avg_grade_by_department()
BEGIN
    SELECT
        s.dept_name,
        ROUND(AVG(gv.points), 2) AS avg_gpa,
        COUNT(DISTINCT s.ID) AS total_students
    FROM student s
    JOIN takes t ON s.ID = t.ID
    JOIN grade_value gv ON t.grade = gv.letter_grade
    WHERE t.grade IS NOT NULL
    GROUP BY s.dept_name
    ORDER BY avg_gpa DESC;
END //
DELIMITER ;

-- Average grade by class
DELIMITER //
CREATE PROCEDURE avg_grade_by_class_range(
    IN p_course_id VARCHAR(8),
    IN p_start_year NUMERIC(4,0),
    IN p_end_year NUMERIC(4,0)
)
BEGIN
    SELECT
        t.course_id,
        c.title,
        t.semester,
        t.year,
        ROUND(AVG(gv.points), 2) AS avg_gpa,
        COUNT(DISTINCT t.ID) AS total_students
    FROM takes t
    JOIN course c ON t.course_id = c.course_id
    JOIN grade_value gv ON t.grade = gv.letter_grade
    WHERE t.course_id = p_course_id
        AND t.year BETWEEN p_start_year AND p_end_year
        AND t.grade IS NOT NULL
    GROUP BY t.course_id, c.title, t.semester, t.year
    ORDER BY t.year, t.semester;
END //
DELIMITER ;

-- Best and worst classes by semester
DELIMITER //
CREATE PROCEDURE best_worst_classes(
    IN p_semester VARCHAR(6),
    IN p_year NUMERIC(4,0)
)
BEGIN
    SELECT
        t.course_id,
        c.title,
        ROUND(AVG(gv.points), 2) AS avg_gpa,
        COUNT(DISTINCT t.ID) AS total_students
    FROM takes t
    JOIN course c ON t.course_id = c.course_id
    JOIN grade_value gv ON t.grade = gv.letter_grade
    WHERE t.semester = p_semester
        AND t.year = p_year
        AND t.grade IS NOT NULL
    GROUP BY t.course_id, c.title
    ORDER BY avg_gpa DESC;
END //
DELIMITER ;

-- Total students in department
DELIMITER //
CREATE PROCEDURE total_students_by_department()
BEGIN
    SELECT
        d.dept_name,
        COUNT(DISTINCT s.ID) AS total_students
    FROM department d
    LEFT JOIN student s ON d.dept_name = s.dept_name
    GROUP BY d.dept_name
    ORDER BY total_students DESC;
END //
DELIMITER ;

-- Enrolled students in departments
DELIMITER //
CREATE PROCEDURE currently_enrolled_by_department()
BEGIN
    SELECT
        d.dept_name,
        COUNT(DISTINCT t.ID) AS enrolled_students
    FROM department d
    LEFT JOIN student s ON d.dept_name = s.dept_name
    LEFT JOIN takes t ON s.ID = t.ID AND t.grade IS NULL
    GROUP BY d.dept_name
    ORDER BY enrolled_students DESC;
END //
DELIMITER ;

-- remove prereq
DELIMITER //
CREATE PROCEDURE remove_prereq(IN p_course_id VARCHAR(8), IN p_prereq_id VARCHAR(8))
BEGIN
    DELETE FROM prereq WHERE course_id = p_course_id AND prereq_id = p_prereq_id;
END //
DELIMITER ;
