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
CREATE PROCEDURE get_all_students()
BEGIN
    SELECT * FROM student;
END $$
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
        CONCAT(i.first_name, ' ', i.last_name) AS advisor_name
    FROM student s
    LEFT JOIN instructor i ON s.advisor_id = i.ID
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
    INSERT INTO transcript (ID, course_id, sec_id, title, credits, dept_name, semester, year, grade)
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
    WHERE c.course_id = p_course_id;

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


-- Project 1 — Data Population Script
-- Generated by generate_data.py

-- BUILDING
INSERT INTO building VALUES ('Cunningham', 'Cunningham Hall', '1275', 'University Esplanade', 'Kent', 'OH', '44242');
INSERT INTO building VALUES ('ISB', 'Integrated Sciences Building', '1165', 'University Esplanade', 'Kent', 'OH', '44242');
INSERT INTO building VALUES ('Smith', 'Smith Hall', '1250', 'University Esplanade', 'Kent', 'OH', '44242');
INSERT INTO building VALUES ('Bowman', 'Bowman Hall', '850', 'University Esplanade', 'Kent', 'OH', '44242');
INSERT INTO building VALUES ('Lowry', 'Lowry Hall', '750', 'Hilltop Drive', 'Kent', 'OH', '44242');
INSERT INTO building VALUES ('McGilvrey', 'McGilvrey Hall', '325', 'South Lincoln Street', 'Kent', 'OH', '44242');
INSERT INTO building VALUES ('Merrill', 'Merrill Hall', '700', 'Hilltop Drive', 'Kent', 'OH', '44242');
INSERT INTO building VALUES ('Ritchie', 'Oscar Ritchie Hall', '225', 'Terrace Drive', 'Kent', 'OH', '44242');
INSERT INTO building VALUES ('Satterfield', 'Satterfield Hall', '475', 'Janik Drive', 'Kent', 'OH', '44242');
INSERT INTO building VALUES ('Williams', 'Williams Hall', '1175', 'Risman Drive', 'Kent', 'OH', '44243');
INSERT INTO building VALUES ('MSB', 'Mathematical Sciences Building', '', 'Lester A Lefton Esplanade', 'Kent', 'OH', '44243');

-- CLASSROOM
INSERT INTO classroom VALUES ('Cunningham', '101', 75);
INSERT INTO classroom VALUES ('Cunningham', '201', 50);
INSERT INTO classroom VALUES ('Cunningham', '301', 35);
INSERT INTO classroom VALUES ('Cunningham', '401', 30);
INSERT INTO classroom VALUES ('ISB', '101', 75);
INSERT INTO classroom VALUES ('ISB', '201', 50);
INSERT INTO classroom VALUES ('ISB', '301', 35);
INSERT INTO classroom VALUES ('ISB', '401', 30);
INSERT INTO classroom VALUES ('Smith', '101', 75);
INSERT INTO classroom VALUES ('Smith', '201', 50);
INSERT INTO classroom VALUES ('Smith', '301', 35);
INSERT INTO classroom VALUES ('Smith', '401', 30);
INSERT INTO classroom VALUES ('Bowman', '101', 75);
INSERT INTO classroom VALUES ('Bowman', '201', 50);
INSERT INTO classroom VALUES ('Bowman', '301', 35);
INSERT INTO classroom VALUES ('Bowman', '401', 30);
INSERT INTO classroom VALUES ('Lowry', '101', 75);
INSERT INTO classroom VALUES ('Lowry', '201', 50);
INSERT INTO classroom VALUES ('Lowry', '301', 35);
INSERT INTO classroom VALUES ('Lowry', '401', 30);
INSERT INTO classroom VALUES ('McGilvrey', '101', 75);
INSERT INTO classroom VALUES ('McGilvrey', '201', 50);
INSERT INTO classroom VALUES ('McGilvrey', '301', 35);
INSERT INTO classroom VALUES ('McGilvrey', '401', 30);
INSERT INTO classroom VALUES ('Merrill', '101', 75);
INSERT INTO classroom VALUES ('Merrill', '201', 50);
INSERT INTO classroom VALUES ('Merrill', '301', 35);
INSERT INTO classroom VALUES ('Merrill', '401', 30);
INSERT INTO classroom VALUES ('Ritchie', '101', 75);
INSERT INTO classroom VALUES ('Ritchie', '201', 50);
INSERT INTO classroom VALUES ('Ritchie', '301', 35);
INSERT INTO classroom VALUES ('Ritchie', '401', 30);
INSERT INTO classroom VALUES ('Satterfield', '101', 75);
INSERT INTO classroom VALUES ('Satterfield', '201', 50);
INSERT INTO classroom VALUES ('Satterfield', '301', 35);
INSERT INTO classroom VALUES ('Satterfield', '401', 30);
INSERT INTO classroom VALUES ('Williams', '101', 75);
INSERT INTO classroom VALUES ('Williams', '201', 50);
INSERT INTO classroom VALUES ('Williams', '301', 35);
INSERT INTO classroom VALUES ('Williams', '401', 30);
INSERT INTO classroom VALUES ('MSB', '101', 75);
INSERT INTO classroom VALUES ('MSB', '201', 50);
INSERT INTO classroom VALUES ('MSB', '301', 35);
INSERT INTO classroom VALUES ('MSB', '401', 30);

-- DEPARTMENT
INSERT INTO department VALUES ('Biology', 'Cunningham', 90000);
INSERT INTO department VALUES ('Comp. Sci.', 'MSB', 100000);
INSERT INTO department VALUES ('Elec. Eng.', 'Ritchie', 85000);
INSERT INTO department VALUES ('Finance', 'Satterfield', 120000);
INSERT INTO department VALUES ('History', 'Bowman', 50000);
INSERT INTO department VALUES ('Music', 'Williams', 80000);
INSERT INTO department VALUES ('Physics', 'Smith', 70000);

-- COURSE
INSERT INTO course VALUES ('BIO-101', 'Intro. to Biology', 'Biology', 4);
INSERT INTO course VALUES ('BIO-201', 'Biology II', 'Biology', 4);
INSERT INTO course VALUES ('BIO-301', 'Genetics', 'Biology', 4);
INSERT INTO course VALUES ('BIO-399', 'Computational Biology', 'Biology', 3);
INSERT INTO course VALUES ('BIO-401', 'Advanced Biology', 'Biology', 3);
INSERT INTO course VALUES ('CS-101', 'Intro. to Computer Science', 'Comp. Sci.', 4);
INSERT INTO course VALUES ('CS-190', 'Game Design', 'Comp. Sci.', 4);
INSERT INTO course VALUES ('CS-315', 'Robotics', 'Comp. Sci.', 3);
INSERT INTO course VALUES ('CS-319', 'Image Processing', 'Comp. Sci.', 3);
INSERT INTO course VALUES ('CS-347', 'Database System Concepts', 'Comp. Sci.', 3);
INSERT INTO course VALUES ('EE-181', 'Intro. to Digital Systems', 'Elec. Eng.', 3);
INSERT INTO course VALUES ('EE-201', 'Circuits I', 'Elec. Eng.', 3);
INSERT INTO course VALUES ('EE-301', 'Circuits II', 'Elec. Eng.', 3);
INSERT INTO course VALUES ('EE-315', 'Signal Processing', 'Elec. Eng.', 3);
INSERT INTO course VALUES ('EE-401', 'Advanced Electronics', 'Elec. Eng.', 3);
INSERT INTO course VALUES ('FIN-101', 'Intro. to Finance', 'Finance', 3);
INSERT INTO course VALUES ('FIN-201', 'Investment Banking', 'Finance', 3);
INSERT INTO course VALUES ('FIN-301', 'Corporate Finance', 'Finance', 3);
INSERT INTO course VALUES ('FIN-315', 'Financial Analysis', 'Finance', 3);
INSERT INTO course VALUES ('FIN-401', 'Advanced Finance', 'Finance', 3);
INSERT INTO course VALUES ('HIS-101', 'Intro. to History', 'History', 3);
INSERT INTO course VALUES ('HIS-201', 'American History', 'History', 3);
INSERT INTO course VALUES ('HIS-301', 'European History', 'History', 3);
INSERT INTO course VALUES ('HIS-351', 'World History', 'History', 3);
INSERT INTO course VALUES ('HIS-401', 'Advanced History', 'History', 3);
INSERT INTO course VALUES ('MU-101', 'Intro. to Music', 'Music', 3);
INSERT INTO course VALUES ('MU-199', 'Music Video Production', 'Music', 3);
INSERT INTO course VALUES ('MU-201', 'Music Theory', 'Music', 3);
INSERT INTO course VALUES ('MU-301', 'Music Composition', 'Music', 3);
INSERT INTO course VALUES ('MU-401', 'Advanced Music', 'Music', 3);
INSERT INTO course VALUES ('PHY-101', 'Physical Principles', 'Physics', 4);
INSERT INTO course VALUES ('PHY-201', 'Physics II', 'Physics', 4);
INSERT INTO course VALUES ('PHY-301', 'Physics III', 'Physics', 3);
INSERT INTO course VALUES ('PHY-315', 'Advanced Physics', 'Physics', 3);
INSERT INTO course VALUES ('PHY-401', 'Physics Seminar', 'Physics', 3);

-- PREREQ
INSERT INTO prereq VALUES ('BIO-201', 'BIO-101');
INSERT INTO prereq VALUES ('BIO-301', 'BIO-101');
INSERT INTO prereq VALUES ('BIO-399', 'BIO-101');
INSERT INTO prereq VALUES ('BIO-401', 'BIO-101');
INSERT INTO prereq VALUES ('MU-199', 'MU-101');
INSERT INTO prereq VALUES ('MU-201', 'MU-101');
INSERT INTO prereq VALUES ('MU-301', 'MU-101');
INSERT INTO prereq VALUES ('MU-401', 'MU-101');
INSERT INTO prereq VALUES ('CS-190', 'CS-101');
INSERT INTO prereq VALUES ('CS-315', 'CS-101');
INSERT INTO prereq VALUES ('CS-319', 'CS-101');
INSERT INTO prereq VALUES ('CS-347', 'CS-101');
INSERT INTO prereq VALUES ('FIN-201', 'FIN-101');
INSERT INTO prereq VALUES ('FIN-301', 'FIN-101');
INSERT INTO prereq VALUES ('FIN-315', 'FIN-101');
INSERT INTO prereq VALUES ('FIN-401', 'FIN-101');
INSERT INTO prereq VALUES ('PHY-201', 'PHY-101');
INSERT INTO prereq VALUES ('PHY-301', 'PHY-101');
INSERT INTO prereq VALUES ('PHY-315', 'PHY-101');
INSERT INTO prereq VALUES ('PHY-401', 'PHY-101');
INSERT INTO prereq VALUES ('HIS-201', 'HIS-101');
INSERT INTO prereq VALUES ('HIS-301', 'HIS-101');
INSERT INTO prereq VALUES ('HIS-351', 'HIS-101');
INSERT INTO prereq VALUES ('HIS-401', 'HIS-101');
INSERT INTO prereq VALUES ('EE-201', 'EE-181');
INSERT INTO prereq VALUES ('EE-301', 'EE-181');
INSERT INTO prereq VALUES ('EE-315', 'EE-181');
INSERT INTO prereq VALUES ('EE-401', 'EE-181');

-- INSTRUCTOR
INSERT INTO instructor VALUES ('I00001', 'Milan', 'Pena', 'Biology', 119203);
INSERT INTO instructor VALUES ('I00002', 'Marcus', 'Glass', 'Biology', 111456);
INSERT INTO instructor VALUES ('I00003', 'Clare', 'Schroeder', 'Biology', 79130);
INSERT INTO instructor VALUES ('I00004', 'Izaiah', 'Walker', 'Biology', 74086);
INSERT INTO instructor VALUES ('I00005', 'Hazel', 'Solis', 'Comp. Sci.', 109702);
INSERT INTO instructor VALUES ('I00006', 'Ronin', 'Fields', 'Comp. Sci.', 102148);
INSERT INTO instructor VALUES ('I00007', 'Annie', 'Buck', 'Comp. Sci.', 108188);
INSERT INTO instructor VALUES ('I00008', 'Jon', 'Clarke', 'Comp. Sci.', 91700);
INSERT INTO instructor VALUES ('I00009', 'Kaitlyn', 'Dorsey', 'Elec. Eng.', 51708);
INSERT INTO instructor VALUES ('I00010', 'Enoch', 'Browning', 'Elec. Eng.', 108748);
INSERT INTO instructor VALUES ('I00011', 'Princess', 'Hendricks', 'Elec. Eng.', 103320);
INSERT INTO instructor VALUES ('I00012', 'Dash', 'Magana', 'Elec. Eng.', 75615);
INSERT INTO instructor VALUES ('I00013', 'Amaris', 'Hoffman', 'Finance', 113712);
INSERT INTO instructor VALUES ('I00014', 'Steven', 'Case', 'Finance', 58055);
INSERT INTO instructor VALUES ('I00015', 'Cleo', 'Castro', 'Finance', 79480);
INSERT INTO instructor VALUES ('I00016', 'Jasper', 'Macdonald', 'Finance', 112333);
INSERT INTO instructor VALUES ('I00017', 'Rosalia', 'Xiong', 'History', 95778);
INSERT INTO instructor VALUES ('I00018', 'Azrael', 'Hayden', 'History', 115611);
INSERT INTO instructor VALUES ('I00019', 'Avayah', 'Short', 'History', 77778);
INSERT INTO instructor VALUES ('I00020', 'Hezekiah', 'Shepard', 'History', 108507);
INSERT INTO instructor VALUES ('I00021', 'Noor', 'Strickland', 'Music', 54737);
INSERT INTO instructor VALUES ('I00022', 'Keegan', 'Burns', 'Music', 73297);
INSERT INTO instructor VALUES ('I00023', 'Emerson', 'Small', 'Music', 94455);
INSERT INTO instructor VALUES ('I00024', 'Rudy', 'McGee', 'Music', 52991);
INSERT INTO instructor VALUES ('I00025', 'Kayleigh', 'Kent', 'Physics', 75375);
INSERT INTO instructor VALUES ('I00026', 'Mekhi', 'Rivas', 'Physics', 51608);
INSERT INTO instructor VALUES ('I00027', 'Averie', 'Weiss', 'Physics', 65336);
INSERT INTO instructor VALUES ('I00028', 'Koa', 'Patrick', 'Physics', 65808);

-- STUDENT
INSERT INTO student VALUES ('S00001', 'Joseph', 'Peterson', 'Finance', 'I00014');
INSERT INTO student VALUES ('S00002', 'Christopher', 'Thompson', 'Finance', 'I00014');
INSERT INTO student VALUES ('S00003', 'Leah', 'Contreras', 'Biology', 'I00003');
INSERT INTO student VALUES ('S00004', 'Gary', 'Holmes', 'Comp. Sci.', 'I00005');
INSERT INTO student VALUES ('S00005', 'John', 'Potter', 'Physics', 'I00026');
INSERT INTO student VALUES ('S00006', 'Audrey', 'Barrett', 'Biology', NULL);
INSERT INTO student VALUES ('S00007', 'Nicole', 'Mclaughlin', 'History', 'I00018');
INSERT INTO student VALUES ('S00008', 'Brian', 'Strickland', 'History', NULL);
INSERT INTO student VALUES ('S00009', 'Amy', 'Grant', 'Physics', 'I00026');
INSERT INTO student VALUES ('S00010', 'Jeremy', 'Rogers', 'Finance', 'I00015');
INSERT INTO student VALUES ('S00011', 'Paula', 'Long', 'Biology', 'I00001');
INSERT INTO student VALUES ('S00012', 'Angela', 'Johnson', 'Biology', 'I00004');
INSERT INTO student VALUES ('S00013', 'Jonathan', 'Jackson', 'History', 'I00019');
INSERT INTO student VALUES ('S00014', 'Brian', 'Taylor', 'Music', 'I00022');
INSERT INTO student VALUES ('S00015', 'Ashley', 'Sutton', 'Biology', 'I00004');
INSERT INTO student VALUES ('S00016', 'Gloria', 'Vazquez', 'Finance', 'I00013');
INSERT INTO student VALUES ('S00017', 'Peggy', 'Faulkner', 'Music', 'I00022');
INSERT INTO student VALUES ('S00018', 'Dennis', 'Graham', 'Music', 'I00023');
INSERT INTO student VALUES ('S00019', 'Hannah', 'Cooper', 'Music', 'I00023');
INSERT INTO student VALUES ('S00020', 'William', 'Hughes', 'Elec. Eng.', 'I00009');
INSERT INTO student VALUES ('S00021', 'Javier', 'Holmes', 'Comp. Sci.', 'I00006');
INSERT INTO student VALUES ('S00022', 'Diane', 'Jones', 'Biology', 'I00004');
INSERT INTO student VALUES ('S00023', 'Victor', 'Flores', 'Biology', 'I00002');
INSERT INTO student VALUES ('S00024', 'Joanna', 'Houston', 'Elec. Eng.', 'I00012');
INSERT INTO student VALUES ('S00025', 'Louis', 'Obrien', 'Biology', 'I00003');
INSERT INTO student VALUES ('S00026', 'Micheal', 'Miller', 'Music', 'I00021');
INSERT INTO student VALUES ('S00027', 'Jacob', 'Wolfe', 'Comp. Sci.', 'I00006');
INSERT INTO student VALUES ('S00028', 'Jose', 'Garcia', 'Comp. Sci.', NULL);
INSERT INTO student VALUES ('S00029', 'Rachel', 'Shepard', 'History', 'I00020');
INSERT INTO student VALUES ('S00030', 'Emily', 'Freeman', 'Comp. Sci.', 'I00008');
INSERT INTO student VALUES ('S00031', 'Beth', 'Delacruz', 'Finance', 'I00015');
INSERT INTO student VALUES ('S00032', 'Ashley', 'Brooks', 'Biology', 'I00002');
INSERT INTO student VALUES ('S00033', 'Jeremy', 'Cruz', 'Elec. Eng.', 'I00010');
INSERT INTO student VALUES ('S00034', 'James', 'Lyons', 'Biology', 'I00003');
INSERT INTO student VALUES ('S00035', 'Patrick', 'Welch', 'Music', 'I00024');
INSERT INTO student VALUES ('S00036', 'Amanda', 'Schultz', 'History', 'I00020');
INSERT INTO student VALUES ('S00037', 'Shawn', 'Anderson', 'History', 'I00017');
INSERT INTO student VALUES ('S00038', 'Leslie', 'Bender', 'Finance', NULL);
INSERT INTO student VALUES ('S00039', 'James', 'Gross', 'Biology', 'I00002');
INSERT INTO student VALUES ('S00040', 'Eric', 'Whitehead', 'Biology', 'I00001');
INSERT INTO student VALUES ('S00041', 'William', 'Williams', 'Biology', 'I00001');
INSERT INTO student VALUES ('S00042', 'Heather', 'Ashley', 'Finance', 'I00014');
INSERT INTO student VALUES ('S00043', 'Paige', 'Ruiz', 'Comp. Sci.', 'I00006');
INSERT INTO student VALUES ('S00044', 'Amber', 'Dixon', 'History', 'I00018');
INSERT INTO student VALUES ('S00045', 'Jenna', 'Torres', 'Comp. Sci.', 'I00007');
INSERT INTO student VALUES ('S00046', 'Michael', 'Carrillo', 'Music', 'I00024');
INSERT INTO student VALUES ('S00047', 'Ashley', 'Diaz', 'Physics', 'I00028');
INSERT INTO student VALUES ('S00048', 'Nicholas', 'Stewart', 'Physics', 'I00028');
INSERT INTO student VALUES ('S00049', 'Cynthia', 'Cohen', 'Finance', NULL);
INSERT INTO student VALUES ('S00050', 'Brenda', 'White', 'Comp. Sci.', 'I00008');
INSERT INTO student VALUES ('S00051', 'Susan', 'Ramirez', 'Music', 'I00024');
INSERT INTO student VALUES ('S00052', 'Brandon', 'Garner', 'Comp. Sci.', 'I00007');
INSERT INTO student VALUES ('S00053', 'Nicole', 'Shannon', 'Physics', 'I00026');
INSERT INTO student VALUES ('S00054', 'Blake', 'Jackson', 'Comp. Sci.', 'I00007');
INSERT INTO student VALUES ('S00055', 'Brandon', 'Rogers', 'Music', 'I00022');
INSERT INTO student VALUES ('S00056', 'Jose', 'Brown', 'Comp. Sci.', 'I00006');
INSERT INTO student VALUES ('S00057', 'Michelle', 'Meyers', 'Biology', 'I00001');
INSERT INTO student VALUES ('S00058', 'Heather', 'Colon', 'Music', 'I00024');
INSERT INTO student VALUES ('S00059', 'Joshua', 'Arias', 'Music', 'I00022');
INSERT INTO student VALUES ('S00060', 'Penny', 'Kim', 'Elec. Eng.', 'I00011');
INSERT INTO student VALUES ('S00061', 'Jean', 'Woods', 'Music', 'I00024');
INSERT INTO student VALUES ('S00062', 'Deborah', 'Harrison', 'Elec. Eng.', 'I00011');
INSERT INTO student VALUES ('S00063', 'Brian', 'Montgomery', 'Finance', 'I00013');
INSERT INTO student VALUES ('S00064', 'Gregory', 'Davis', 'Elec. Eng.', 'I00012');
INSERT INTO student VALUES ('S00065', 'Zachary', 'Marquez', 'Elec. Eng.', 'I00011');
INSERT INTO student VALUES ('S00066', 'Carla', 'Jackson', 'Elec. Eng.', 'I00012');
INSERT INTO student VALUES ('S00067', 'Richard', 'Dominguez', 'Music', NULL);
INSERT INTO student VALUES ('S00068', 'Brittany', 'Nunez', 'Comp. Sci.', 'I00005');
INSERT INTO student VALUES ('S00069', 'Joan', 'Schneider', 'Biology', 'I00002');
INSERT INTO student VALUES ('S00070', 'Antonio', 'Clark', 'Biology', 'I00001');
INSERT INTO student VALUES ('S00071', 'Katherine', 'Dean', 'Comp. Sci.', 'I00005');
INSERT INTO student VALUES ('S00072', 'Stephanie', 'Powell', 'Comp. Sci.', 'I00006');
INSERT INTO student VALUES ('S00073', 'Lauren', 'Mercer', 'Music', 'I00022');
INSERT INTO student VALUES ('S00074', 'Robert', 'Harris', 'Finance', 'I00013');
INSERT INTO student VALUES ('S00075', 'Joanna', 'Cohen', 'Comp. Sci.', 'I00006');
INSERT INTO student VALUES ('S00076', 'Patricia', 'Carpenter', 'History', 'I00017');
INSERT INTO student VALUES ('S00077', 'Sara', 'Huynh', 'Elec. Eng.', 'I00011');
INSERT INTO student VALUES ('S00078', 'Jermaine', 'Rowland', 'History', 'I00017');
INSERT INTO student VALUES ('S00079', 'Jessica', 'Higgins', 'Biology', 'I00003');
INSERT INTO student VALUES ('S00080', 'Brian', 'Peters', 'Physics', 'I00026');
INSERT INTO student VALUES ('S00081', 'James', 'Martinez', 'Finance', 'I00014');
INSERT INTO student VALUES ('S00082', 'Frank', 'Walls', 'Elec. Eng.', 'I00009');
INSERT INTO student VALUES ('S00083', 'Emma', 'Bennett', 'Elec. Eng.', 'I00011');
INSERT INTO student VALUES ('S00084', 'Erika', 'Harris', 'Physics', 'I00026');
INSERT INTO student VALUES ('S00085', 'Amy', 'Richardson', 'Finance', NULL);
INSERT INTO student VALUES ('S00086', 'Caitlyn', 'Santos', 'Comp. Sci.', 'I00008');
INSERT INTO student VALUES ('S00087', 'Elizabeth', 'Jarvis', 'Finance', 'I00013');
INSERT INTO student VALUES ('S00088', 'Jennifer', 'Rich', 'Biology', 'I00002');
INSERT INTO student VALUES ('S00089', 'Brendan', 'King', 'Music', 'I00022');
INSERT INTO student VALUES ('S00090', 'Linda', 'Roach', 'History', 'I00019');
INSERT INTO student VALUES ('S00091', 'Brent', 'Thompson', 'Comp. Sci.', NULL);
INSERT INTO student VALUES ('S00092', 'John', 'Vincent', 'History', 'I00019');
INSERT INTO student VALUES ('S00093', 'Melissa', 'Macdonald', 'Finance', 'I00016');
INSERT INTO student VALUES ('S00094', 'Victoria', 'Ruiz', 'Elec. Eng.', NULL);
INSERT INTO student VALUES ('S00095', 'Alexandria', 'Petersen', 'Elec. Eng.', 'I00010');
INSERT INTO student VALUES ('S00096', 'Melinda', 'Price', 'History', 'I00018');
INSERT INTO student VALUES ('S00097', 'Christine', 'Roberts', 'Physics', 'I00025');
INSERT INTO student VALUES ('S00098', 'Jill', 'James', 'Physics', 'I00025');
INSERT INTO student VALUES ('S00099', 'John', 'Warren', 'Music', 'I00022');
INSERT INTO student VALUES ('S00100', 'Phillip', 'Taylor', 'Biology', 'I00003');
INSERT INTO student VALUES ('S00101', 'Christopher', 'Schwartz', 'Elec. Eng.', 'I00010');
INSERT INTO student VALUES ('S00102', 'Brandy', 'Walsh', 'Biology', 'I00003');
INSERT INTO student VALUES ('S00103', 'Matthew', 'Gordon', 'Biology', 'I00003');
INSERT INTO student VALUES ('S00104', 'Randy', 'Becker', 'Biology', 'I00002');
INSERT INTO student VALUES ('S00105', 'Sarah', 'Gutierrez', 'Comp. Sci.', 'I00006');
INSERT INTO student VALUES ('S00106', 'Stephanie', 'Caldwell', 'History', 'I00018');
INSERT INTO student VALUES ('S00107', 'Anthony', 'Valencia', 'Comp. Sci.', 'I00006');
INSERT INTO student VALUES ('S00108', 'Alexandra', 'Mora', 'Physics', 'I00027');
INSERT INTO student VALUES ('S00109', 'Donald', 'Curtis', 'Music', 'I00023');
INSERT INTO student VALUES ('S00110', 'Rachel', 'Jones', 'Biology', 'I00002');
INSERT INTO student VALUES ('S00111', 'John', 'Bryant', 'Finance', 'I00014');
INSERT INTO student VALUES ('S00112', 'Todd', 'Vasquez', 'Comp. Sci.', NULL);
INSERT INTO student VALUES ('S00113', 'Jeremiah', 'Johnson', 'Physics', 'I00028');
INSERT INTO student VALUES ('S00114', 'Rachel', 'Byrd', 'Music', 'I00021');
INSERT INTO student VALUES ('S00115', 'Marilyn', 'Coleman', 'Music', 'I00023');
INSERT INTO student VALUES ('S00116', 'Valerie', 'Dunn', 'Comp. Sci.', 'I00006');
INSERT INTO student VALUES ('S00117', 'Mario', 'King', 'Finance', 'I00015');
INSERT INTO student VALUES ('S00118', 'Trevor', 'Watson', 'Comp. Sci.', 'I00005');
INSERT INTO student VALUES ('S00119', 'Walter', 'Anderson', 'Physics', 'I00027');
INSERT INTO student VALUES ('S00120', 'Donna', 'Simmons', 'Biology', 'I00004');
INSERT INTO student VALUES ('S00121', 'Jennifer', 'Smith', 'Biology', 'I00004');
INSERT INTO student VALUES ('S00122', 'Roger', 'Alvarado', 'Elec. Eng.', 'I00012');
INSERT INTO student VALUES ('S00123', 'Danielle', 'Allen', 'Physics', 'I00025');
INSERT INTO student VALUES ('S00124', 'Natalie', 'Miles', 'Finance', 'I00014');
INSERT INTO student VALUES ('S00125', 'Christine', 'Orr', 'Finance', 'I00016');
INSERT INTO student VALUES ('S00126', 'Walter', 'Bowers', 'History', 'I00019');
INSERT INTO student VALUES ('S00127', 'Julia', 'Jones', 'Finance', 'I00016');
INSERT INTO student VALUES ('S00128', 'Sandra', 'Hill', 'Finance', 'I00013');
INSERT INTO student VALUES ('S00129', 'Stephanie', 'Burton', 'Finance', 'I00014');
INSERT INTO student VALUES ('S00130', 'James', 'Roberts', 'Biology', 'I00002');
INSERT INTO student VALUES ('S00131', 'Michelle', 'Huffman', 'Biology', 'I00001');
INSERT INTO student VALUES ('S00132', 'Brian', 'English', 'Physics', 'I00025');
INSERT INTO student VALUES ('S00133', 'James', 'Hernandez', 'History', 'I00018');
INSERT INTO student VALUES ('S00134', 'Shannon', 'Lyons', 'Finance', 'I00015');
INSERT INTO student VALUES ('S00135', 'Erik', 'Franco', 'Elec. Eng.', 'I00011');
INSERT INTO student VALUES ('S00136', 'Michael', 'Lee', 'History', NULL);
INSERT INTO student VALUES ('S00137', 'Jonathan', 'Love', 'History', NULL);
INSERT INTO student VALUES ('S00138', 'David', 'Thomas', 'Biology', 'I00004');
INSERT INTO student VALUES ('S00139', 'Jennifer', 'Curtis', 'History', 'I00018');
INSERT INTO student VALUES ('S00140', 'Sonia', 'Harper', 'History', 'I00020');
INSERT INTO student VALUES ('S00141', 'Michael', 'Williams', 'Music', 'I00024');
INSERT INTO student VALUES ('S00142', 'Maria', 'Ryan', 'Comp. Sci.', 'I00005');
INSERT INTO student VALUES ('S00143', 'Brandi', 'Horton', 'Finance', 'I00016');
INSERT INTO student VALUES ('S00144', 'Carrie', 'Phillips', 'Music', 'I00022');
INSERT INTO student VALUES ('S00145', 'Johnny', 'Grimes', 'Biology', 'I00001');
INSERT INTO student VALUES ('S00146', 'Adam', 'Smith', 'Music', 'I00024');
INSERT INTO student VALUES ('S00147', 'Rebecca', 'Jenkins', 'Finance', 'I00015');
INSERT INTO student VALUES ('S00148', 'Douglas', 'White', 'Elec. Eng.', 'I00010');
INSERT INTO student VALUES ('S00149', 'Antonio', 'Sanchez', 'Music', 'I00021');
INSERT INTO student VALUES ('S00150', 'Ronald', 'Roman', 'Music', 'I00023');
INSERT INTO student VALUES ('S00151', 'Grant', 'Bailey', 'History', 'I00018');
INSERT INTO student VALUES ('S00152', 'Luis', 'Luna', 'Biology', 'I00004');
INSERT INTO student VALUES ('S00153', 'Jill', 'Moore', 'Elec. Eng.', NULL);
INSERT INTO student VALUES ('S00154', 'John', 'Smith', 'Comp. Sci.', 'I00006');
INSERT INTO student VALUES ('S00155', 'Eric', 'Mason', 'Finance', 'I00014');
INSERT INTO student VALUES ('S00156', 'Chad', 'Johnson', 'Comp. Sci.', 'I00008');
INSERT INTO student VALUES ('S00157', 'Timothy', 'Farrell', 'Music', NULL);
INSERT INTO student VALUES ('S00158', 'Christopher', 'Hall', 'History', 'I00019');
INSERT INTO student VALUES ('S00159', 'Jacqueline', 'Rodriguez', 'Elec. Eng.', 'I00009');
INSERT INTO student VALUES ('S00160', 'Bianca', 'Weber', 'Physics', 'I00028');
INSERT INTO student VALUES ('S00161', 'Melanie', 'Hayes', 'Music', 'I00024');
INSERT INTO student VALUES ('S00162', 'Carla', 'Jones', 'Music', 'I00024');
INSERT INTO student VALUES ('S00163', 'Henry', 'Cole', 'Elec. Eng.', 'I00012');
INSERT INTO student VALUES ('S00164', 'Matthew', 'Turner', 'Biology', 'I00004');
INSERT INTO student VALUES ('S00165', 'Jessica', 'Douglas', 'History', 'I00019');
INSERT INTO student VALUES ('S00166', 'Mary', 'Oconnell', 'Comp. Sci.', 'I00007');
INSERT INTO student VALUES ('S00167', 'Ryan', 'Hodges', 'Elec. Eng.', 'I00010');
INSERT INTO student VALUES ('S00168', 'Tracy', 'Mathews', 'Biology', 'I00002');
INSERT INTO student VALUES ('S00169', 'Denise', 'Sanchez', 'Music', 'I00022');
INSERT INTO student VALUES ('S00170', 'Mark', 'Hawkins', 'History', NULL);
INSERT INTO student VALUES ('S00171', 'Jennifer', 'Moran', 'Music', 'I00022');
INSERT INTO student VALUES ('S00172', 'Troy', 'Little', 'Biology', 'I00004');
INSERT INTO student VALUES ('S00173', 'Tina', 'Patel', 'Music', 'I00024');
INSERT INTO student VALUES ('S00174', 'Jonathan', 'Torres', 'Biology', 'I00003');
INSERT INTO student VALUES ('S00175', 'Heather', 'Reilly', 'Elec. Eng.', 'I00009');
INSERT INTO student VALUES ('S00176', 'Wendy', 'Huff', 'Physics', 'I00028');
INSERT INTO student VALUES ('S00177', 'Craig', 'Smith', 'Finance', 'I00014');
INSERT INTO student VALUES ('S00178', 'Melinda', 'Kaiser', 'Physics', 'I00027');
INSERT INTO student VALUES ('S00179', 'Paul', 'Mccormick', 'History', 'I00018');
INSERT INTO student VALUES ('S00180', 'Nathaniel', 'Taylor', 'Physics', 'I00028');
INSERT INTO student VALUES ('S00181', 'Susan', 'Banks', 'Finance', 'I00014');
INSERT INTO student VALUES ('S00182', 'Sarah', 'Greene', 'History', 'I00020');
INSERT INTO student VALUES ('S00183', 'Mary', 'Rodriguez', 'Comp. Sci.', 'I00007');
INSERT INTO student VALUES ('S00184', 'Jeanette', 'Austin', 'Music', 'I00022');
INSERT INTO student VALUES ('S00185', 'Gary', 'West', 'History', NULL);
INSERT INTO student VALUES ('S00186', 'Gary', 'Miller', 'Music', 'I00024');
INSERT INTO student VALUES ('S00187', 'Daniel', 'Briggs', 'History', 'I00018');
INSERT INTO student VALUES ('S00188', 'Janet', 'Perez', 'Physics', NULL);
INSERT INTO student VALUES ('S00189', 'William', 'Watson', 'Finance', 'I00014');
INSERT INTO student VALUES ('S00190', 'Thomas', 'Lowe', 'Biology', 'I00002');
INSERT INTO student VALUES ('S00191', 'Daniel', 'Morales', 'Elec. Eng.', 'I00011');
INSERT INTO student VALUES ('S00192', 'John', 'Johnson', 'Music', 'I00023');
INSERT INTO student VALUES ('S00193', 'Morgan', 'Moss', 'Music', 'I00021');
INSERT INTO student VALUES ('S00194', 'Daniel', 'Little', 'History', 'I00017');
INSERT INTO student VALUES ('S00195', 'Jeffrey', 'Stevens', 'Finance', 'I00013');
INSERT INTO student VALUES ('S00196', 'Yvonne', 'Parker', 'Finance', 'I00014');
INSERT INTO student VALUES ('S00197', 'James', 'Warren', 'Comp. Sci.', 'I00007');
INSERT INTO student VALUES ('S00198', 'Samuel', 'Cook', 'Music', 'I00022');
INSERT INTO student VALUES ('S00199', 'Eileen', 'Spencer', 'Music', 'I00024');
INSERT INTO student VALUES ('S00200', 'Maria', 'Thomas', 'Finance', NULL);
INSERT INTO student VALUES ('S00201', 'Shelly', 'Green', 'Elec. Eng.', 'I00011');
INSERT INTO student VALUES ('S00202', 'Shawn', 'Grant', 'History', 'I00019');
INSERT INTO student VALUES ('S00203', 'Justin', 'Brewer', 'Elec. Eng.', 'I00011');
INSERT INTO student VALUES ('S00204', 'Steven', 'Joyce', 'Comp. Sci.', 'I00006');
INSERT INTO student VALUES ('S00205', 'William', 'Watts', 'Physics', 'I00026');
INSERT INTO student VALUES ('S00206', 'Lisa', 'Jennings', 'History', 'I00019');
INSERT INTO student VALUES ('S00207', 'Bradley', 'Stewart', 'Finance', 'I00015');
INSERT INTO student VALUES ('S00208', 'Vincent', 'Sanford', 'Elec. Eng.', NULL);
INSERT INTO student VALUES ('S00209', 'Luis', 'Stewart', 'Comp. Sci.', 'I00006');
INSERT INTO student VALUES ('S00210', 'David', 'Bell', 'Comp. Sci.', 'I00005');
INSERT INTO student VALUES ('S00211', 'April', 'Kaiser', 'Biology', 'I00004');
INSERT INTO student VALUES ('S00212', 'Melody', 'Alvarez', 'Physics', NULL);
INSERT INTO student VALUES ('S00213', 'Vanessa', 'Arroyo', 'History', 'I00017');
INSERT INTO student VALUES ('S00214', 'Tammy', 'Mcgrath', 'Music', 'I00023');
INSERT INTO student VALUES ('S00215', 'Roberta', 'Ward', 'History', 'I00020');
INSERT INTO student VALUES ('S00216', 'Joshua', 'Hood', 'Biology', 'I00002');
INSERT INTO student VALUES ('S00217', 'Destiny', 'Rivers', 'Biology', 'I00001');
INSERT INTO student VALUES ('S00218', 'Christine', 'Williams', 'Music', 'I00023');
INSERT INTO student VALUES ('S00219', 'Julie', 'Johnson', 'Physics', 'I00026');
INSERT INTO student VALUES ('S00220', 'Stephanie', 'Turner', 'Physics', 'I00028');
INSERT INTO student VALUES ('S00221', 'Lawrence', 'Travis', 'Finance', 'I00013');
INSERT INTO student VALUES ('S00222', 'Richard', 'Clark', 'Music', 'I00022');
INSERT INTO student VALUES ('S00223', 'Aaron', 'Moreno', 'Physics', 'I00027');
INSERT INTO student VALUES ('S00224', 'Kristine', 'Reese', 'Physics', 'I00028');
INSERT INTO student VALUES ('S00225', 'Mason', 'Cummings', 'Music', 'I00023');
INSERT INTO student VALUES ('S00226', 'Lori', 'Bailey', 'Biology', NULL);
INSERT INTO student VALUES ('S00227', 'Amanda', 'Clark', 'Finance', 'I00014');
INSERT INTO student VALUES ('S00228', 'Matthew', 'Carter', 'Physics', 'I00026');
INSERT INTO student VALUES ('S00229', 'Kathy', 'Kelly', 'Finance', NULL);
INSERT INTO student VALUES ('S00230', 'Jesse', 'Jones', 'Finance', 'I00015');
INSERT INTO student VALUES ('S00231', 'Gregory', 'Charles', 'Elec. Eng.', 'I00012');
INSERT INTO student VALUES ('S00232', 'Ariel', 'Mccoy', 'Music', 'I00024');
INSERT INTO student VALUES ('S00233', 'Kaylee', 'Morrow', 'Physics', 'I00026');
INSERT INTO student VALUES ('S00234', 'Katie', 'Castro', 'Finance', NULL);
INSERT INTO student VALUES ('S00235', 'Jamie', 'Moore', 'Finance', 'I00013');
INSERT INTO student VALUES ('S00236', 'Brian', 'Roberts', 'Finance', 'I00015');
INSERT INTO student VALUES ('S00237', 'Katie', 'Roberts', 'Physics', 'I00025');
INSERT INTO student VALUES ('S00238', 'Lori', 'Guzman', 'Finance', 'I00014');
INSERT INTO student VALUES ('S00239', 'Mark', 'Palmer', 'Finance', 'I00014');
INSERT INTO student VALUES ('S00240', 'Sarah', 'Powell', 'History', 'I00017');
INSERT INTO student VALUES ('S00241', 'Brandon', 'Moran', 'Physics', 'I00027');
INSERT INTO student VALUES ('S00242', 'Michelle', 'Daniels', 'History', 'I00018');
INSERT INTO student VALUES ('S00243', 'Lisa', 'Garcia', 'Music', 'I00021');
INSERT INTO student VALUES ('S00244', 'Megan', 'Marquez', 'Elec. Eng.', NULL);
INSERT INTO student VALUES ('S00245', 'William', 'Walker', 'Biology', 'I00002');
INSERT INTO student VALUES ('S00246', 'Jeffery', 'Salazar', 'Biology', 'I00002');
INSERT INTO student VALUES ('S00247', 'Melissa', 'Morales', 'Comp. Sci.', 'I00006');
INSERT INTO student VALUES ('S00248', 'Richard', 'Long', 'Finance', 'I00013');
INSERT INTO student VALUES ('S00249', 'Allen', 'Decker', 'Comp. Sci.', 'I00006');
INSERT INTO student VALUES ('S00250', 'Clinton', 'Jackson', 'Biology', 'I00004');
INSERT INTO student VALUES ('S00251', 'Patricia', 'Thompson', 'Music', 'I00023');
INSERT INTO student VALUES ('S00252', 'Kenneth', 'Williams', 'Finance', 'I00015');
INSERT INTO student VALUES ('S00253', 'Cody', 'Nolan', 'Comp. Sci.', NULL);
INSERT INTO student VALUES ('S00254', 'Christopher', 'Garza', 'Physics', 'I00025');
INSERT INTO student VALUES ('S00255', 'John', 'Tran', 'Physics', 'I00026');
INSERT INTO student VALUES ('S00256', 'Matthew', 'Thomas', 'History', 'I00019');
INSERT INTO student VALUES ('S00257', 'Kathleen', 'Brown', 'Music', 'I00023');
INSERT INTO student VALUES ('S00258', 'Eric', 'Anderson', 'Comp. Sci.', 'I00005');
INSERT INTO student VALUES ('S00259', 'Michael', 'Burgess', 'Elec. Eng.', 'I00010');
INSERT INTO student VALUES ('S00260', 'Margaret', 'Norman', 'History', 'I00018');
INSERT INTO student VALUES ('S00261', 'Shawn', 'Austin', 'Comp. Sci.', 'I00005');
INSERT INTO student VALUES ('S00262', 'Karen', 'Ford', 'Music', 'I00023');
INSERT INTO student VALUES ('S00263', 'Cynthia', 'Riley', 'Finance', NULL);
INSERT INTO student VALUES ('S00264', 'Sherry', 'Townsend', 'History', 'I00020');
INSERT INTO student VALUES ('S00265', 'Shane', 'Moore', 'Biology', 'I00001');
INSERT INTO student VALUES ('S00266', 'Andrew', 'Mclaughlin', 'Biology', 'I00002');
INSERT INTO student VALUES ('S00267', 'Tracy', 'Schaefer', 'Music', 'I00023');
INSERT INTO student VALUES ('S00268', 'Bryan', 'Adams', 'History', 'I00018');
INSERT INTO student VALUES ('S00269', 'Amanda', 'Henry', 'Comp. Sci.', 'I00005');
INSERT INTO student VALUES ('S00270', 'Kelly', 'Perez', 'Finance', 'I00016');
INSERT INTO student VALUES ('S00271', 'Grace', 'Johnson', 'Comp. Sci.', 'I00005');
INSERT INTO student VALUES ('S00272', 'Terri', 'Smith', 'Finance', NULL);
INSERT INTO student VALUES ('S00273', 'Cassie', 'Goodman', 'Comp. Sci.', 'I00006');
INSERT INTO student VALUES ('S00274', 'Jamie', 'Pearson', 'Elec. Eng.', 'I00011');
INSERT INTO student VALUES ('S00275', 'Amy', 'Hill', 'Biology', NULL);
INSERT INTO student VALUES ('S00276', 'Kevin', 'Baker', 'Comp. Sci.', 'I00007');
INSERT INTO student VALUES ('S00277', 'Christopher', 'Berry', 'Music', 'I00024');
INSERT INTO student VALUES ('S00278', 'Angela', 'Jones', 'Biology', 'I00003');
INSERT INTO student VALUES ('S00279', 'Amanda', 'Hernandez', 'Finance', 'I00016');
INSERT INTO student VALUES ('S00280', 'Melissa', 'Roberts', 'Finance', 'I00015');
INSERT INTO student VALUES ('S00281', 'Carol', 'Roach', 'History', NULL);
INSERT INTO student VALUES ('S00282', 'Shane', 'Fuentes', 'Elec. Eng.', 'I00011');
INSERT INTO student VALUES ('S00283', 'Derrick', 'Flores', 'Biology', NULL);
INSERT INTO student VALUES ('S00284', 'Christopher', 'Hanson', 'History', 'I00017');
INSERT INTO student VALUES ('S00285', 'Charles', 'Johnson', 'Music', 'I00022');
INSERT INTO student VALUES ('S00286', 'Christine', 'Miller', 'Comp. Sci.', 'I00005');
INSERT INTO student VALUES ('S00287', 'Amber', 'Weaver', 'Physics', 'I00028');
INSERT INTO student VALUES ('S00288', 'Gwendolyn', 'Davenport', 'Music', 'I00022');
INSERT INTO student VALUES ('S00289', 'Natalie', 'Anderson', 'Physics', 'I00025');
INSERT INTO student VALUES ('S00290', 'Scott', 'Matthews', 'History', 'I00018');
INSERT INTO student VALUES ('S00291', 'Joanne', 'Case', 'History', 'I00019');
INSERT INTO student VALUES ('S00292', 'Zachary', 'Stewart', 'Biology', 'I00003');
INSERT INTO student VALUES ('S00293', 'Amy', 'Alexander', 'Elec. Eng.', 'I00011');
INSERT INTO student VALUES ('S00294', 'Pam', 'Martinez', 'Music', 'I00022');
INSERT INTO student VALUES ('S00295', 'Robert', 'Bates', 'Comp. Sci.', 'I00008');
INSERT INTO student VALUES ('S00296', 'Kimberly', 'Chung', 'Finance', 'I00013');
INSERT INTO student VALUES ('S00297', 'Tyrone', 'Lopez', 'Comp. Sci.', NULL);
INSERT INTO student VALUES ('S00298', 'Dana', 'Mcdonald', 'Comp. Sci.', 'I00006');
INSERT INTO student VALUES ('S00299', 'James', 'Hunt', 'Biology', NULL);
INSERT INTO student VALUES ('S00300', 'Ian', 'Torres', 'Physics', 'I00025');
INSERT INTO student VALUES ('S00301', 'Kevin', 'Parker', 'Finance', NULL);
INSERT INTO student VALUES ('S00302', 'Christina', 'Ward', 'Music', 'I00021');
INSERT INTO student VALUES ('S00303', 'Dustin', 'Jenkins', 'History', 'I00019');
INSERT INTO student VALUES ('S00304', 'Erica', 'Smith', 'Finance', 'I00014');
INSERT INTO student VALUES ('S00305', 'Tyler', 'Medina', 'History', 'I00018');
INSERT INTO student VALUES ('S00306', 'Linda', 'Hawkins', 'Biology', 'I00004');
INSERT INTO student VALUES ('S00307', 'Meghan', 'Flores', 'Physics', 'I00027');
INSERT INTO student VALUES ('S00308', 'Thomas', 'Miranda', 'Physics', 'I00026');
INSERT INTO student VALUES ('S00309', 'Andrew', 'Henderson', 'Biology', 'I00004');
INSERT INTO student VALUES ('S00310', 'Sarah', 'Miller', 'Comp. Sci.', NULL);
INSERT INTO student VALUES ('S00311', 'Ashlee', 'Adams', 'Comp. Sci.', 'I00005');
INSERT INTO student VALUES ('S00312', 'Matthew', 'Gibson', 'Finance', 'I00014');
INSERT INTO student VALUES ('S00313', 'Jared', 'Hernandez', 'Comp. Sci.', 'I00005');
INSERT INTO student VALUES ('S00314', 'John', 'Keller', 'Finance', 'I00013');
INSERT INTO student VALUES ('S00315', 'Charles', 'Campos', 'Biology', 'I00004');
INSERT INTO student VALUES ('S00316', 'Jill', 'Gray', 'History', 'I00020');
INSERT INTO student VALUES ('S00317', 'Carrie', 'Woodard', 'Physics', 'I00028');
INSERT INTO student VALUES ('S00318', 'Andrew', 'Oneal', 'Music', 'I00023');
INSERT INTO student VALUES ('S00319', 'Barbara', 'Crawford', 'Comp. Sci.', 'I00008');
INSERT INTO student VALUES ('S00320', 'Matthew', 'Morrison', 'Comp. Sci.', 'I00006');
INSERT INTO student VALUES ('S00321', 'Daniel', 'Reid', 'Comp. Sci.', 'I00005');
INSERT INTO student VALUES ('S00322', 'David', 'Smith', 'Finance', 'I00016');
INSERT INTO student VALUES ('S00323', 'Michael', 'Turner', 'Comp. Sci.', 'I00007');
INSERT INTO student VALUES ('S00324', 'Michael', 'Gates', 'Comp. Sci.', 'I00007');
INSERT INTO student VALUES ('S00325', 'Jessica', 'Brown', 'History', 'I00019');
INSERT INTO student VALUES ('S00326', 'Stephen', 'Johns', 'Elec. Eng.', NULL);
INSERT INTO student VALUES ('S00327', 'John', 'Wilson', 'Physics', 'I00028');
INSERT INTO student VALUES ('S00328', 'April', 'Norris', 'Comp. Sci.', NULL);
INSERT INTO student VALUES ('S00329', 'Jenna', 'Dougherty', 'Comp. Sci.', NULL);
INSERT INTO student VALUES ('S00330', 'Anthony', 'Clark', 'Comp. Sci.', 'I00007');
INSERT INTO student VALUES ('S00331', 'Taylor', 'Curry', 'Comp. Sci.', 'I00005');
INSERT INTO student VALUES ('S00332', 'Sandra', 'Shaw', 'Biology', 'I00003');
INSERT INTO student VALUES ('S00333', 'Holly', 'Meyer', 'Biology', NULL);
INSERT INTO student VALUES ('S00334', 'Carmen', 'Carney', 'Finance', 'I00014');
INSERT INTO student VALUES ('S00335', 'David', 'Russell', 'Comp. Sci.', 'I00008');
INSERT INTO student VALUES ('S00336', 'James', 'Russell', 'Biology', 'I00001');
INSERT INTO student VALUES ('S00337', 'Stephen', 'Powell', 'History', 'I00019');
INSERT INTO student VALUES ('S00338', 'Abigail', 'Townsend', 'History', 'I00020');
INSERT INTO student VALUES ('S00339', 'Vincent', 'Ramsey', 'Biology', 'I00003');
INSERT INTO student VALUES ('S00340', 'Terri', 'Freeman', 'Elec. Eng.', 'I00012');
INSERT INTO student VALUES ('S00341', 'Maria', 'Ashley', 'Elec. Eng.', 'I00010');
INSERT INTO student VALUES ('S00342', 'Kimberly', 'Taylor', 'Elec. Eng.', 'I00010');
INSERT INTO student VALUES ('S00343', 'Brandon', 'Maxwell', 'Finance', NULL);
INSERT INTO student VALUES ('S00344', 'Ana', 'Malone', 'Physics', 'I00026');
INSERT INTO student VALUES ('S00345', 'Eric', 'Rivera', 'Elec. Eng.', 'I00011');
INSERT INTO student VALUES ('S00346', 'Holly', 'Salazar', 'Comp. Sci.', NULL);
INSERT INTO student VALUES ('S00347', 'Gina', 'Vaughan', 'Biology', 'I00003');
INSERT INTO student VALUES ('S00348', 'Rodney', 'Vasquez', 'Biology', 'I00004');
INSERT INTO student VALUES ('S00349', 'Anna', 'Bailey', 'Elec. Eng.', 'I00012');
INSERT INTO student VALUES ('S00350', 'Shane', 'Taylor', 'Biology', NULL);
INSERT INTO student VALUES ('S00351', 'Allison', 'Wu', 'History', 'I00020');
INSERT INTO student VALUES ('S00352', 'Shelia', 'Evans', 'Comp. Sci.', 'I00007');
INSERT INTO student VALUES ('S00353', 'Adam', 'Walker', 'Finance', 'I00015');
INSERT INTO student VALUES ('S00354', 'James', 'Edwards', 'Physics', 'I00027');
INSERT INTO student VALUES ('S00355', 'Taylor', 'Sanders', 'Music', 'I00024');
INSERT INTO student VALUES ('S00356', 'Joshua', 'Nguyen', 'Finance', 'I00015');
INSERT INTO student VALUES ('S00357', 'Rebecca', 'Miller', 'History', 'I00017');
INSERT INTO student VALUES ('S00358', 'Elizabeth', 'Bailey', 'Comp. Sci.', 'I00006');
INSERT INTO student VALUES ('S00359', 'Lisa', 'Wheeler', 'Music', 'I00024');
INSERT INTO student VALUES ('S00360', 'Garrett', 'Hill', 'Biology', 'I00003');
INSERT INTO student VALUES ('S00361', 'Kathleen', 'Kaufman', 'Elec. Eng.', 'I00010');
INSERT INTO student VALUES ('S00362', 'Melvin', 'Riley', 'History', 'I00020');
INSERT INTO student VALUES ('S00363', 'William', 'Williams', 'Music', 'I00024');
INSERT INTO student VALUES ('S00364', 'Terri', 'Hill', 'Music', 'I00022');
INSERT INTO student VALUES ('S00365', 'Wanda', 'Jones', 'Biology', 'I00003');
INSERT INTO student VALUES ('S00366', 'Russell', 'Duarte', 'History', 'I00019');
INSERT INTO student VALUES ('S00367', 'John', 'Johnson', 'Elec. Eng.', 'I00009');
INSERT INTO student VALUES ('S00368', 'Matthew', 'Bauer', 'Biology', 'I00003');
INSERT INTO student VALUES ('S00369', 'Elizabeth', 'Green', 'History', 'I00018');
INSERT INTO student VALUES ('S00370', 'Melissa', 'Gonzalez', 'Physics', 'I00026');
INSERT INTO student VALUES ('S00371', 'Jeffery', 'Smith', 'Elec. Eng.', 'I00011');
INSERT INTO student VALUES ('S00372', 'Robert', 'Lloyd', 'Comp. Sci.', 'I00005');
INSERT INTO student VALUES ('S00373', 'Jerry', 'Sanders', 'Comp. Sci.', 'I00006');
INSERT INTO student VALUES ('S00374', 'James', 'Rodriguez', 'Music', 'I00021');
INSERT INTO student VALUES ('S00375', 'Paul', 'Flores', 'Biology', 'I00004');
INSERT INTO student VALUES ('S00376', 'Adam', 'Ray', 'History', 'I00017');
INSERT INTO student VALUES ('S00377', 'Matthew', 'White', 'Biology', 'I00002');
INSERT INTO student VALUES ('S00378', 'Amanda', 'Cruz', 'History', NULL);
INSERT INTO student VALUES ('S00379', 'Maria', 'Joseph', 'Elec. Eng.', 'I00011');
INSERT INTO student VALUES ('S00380', 'Michelle', 'Cooper', 'History', 'I00017');
INSERT INTO student VALUES ('S00381', 'James', 'Morris', 'History', 'I00017');
INSERT INTO student VALUES ('S00382', 'Juan', 'Lynn', 'History', 'I00018');
INSERT INTO student VALUES ('S00383', 'Todd', 'Hamilton', 'History', 'I00019');
INSERT INTO student VALUES ('S00384', 'Vincent', 'Walker', 'History', 'I00017');
INSERT INTO student VALUES ('S00385', 'Teresa', 'Simmons', 'Comp. Sci.', 'I00008');
INSERT INTO student VALUES ('S00386', 'Heather', 'Davis', 'Elec. Eng.', 'I00010');
INSERT INTO student VALUES ('S00387', 'Christopher', 'Wilson', 'Comp. Sci.', 'I00006');
INSERT INTO student VALUES ('S00388', 'Jacob', 'Martin', 'Biology', 'I00004');
INSERT INTO student VALUES ('S00389', 'Seth', 'Howard', 'History', 'I00018');
INSERT INTO student VALUES ('S00390', 'Alice', 'Crawford', 'Elec. Eng.', 'I00011');
INSERT INTO student VALUES ('S00391', 'William', 'Gilbert', 'Finance', 'I00015');
INSERT INTO student VALUES ('S00392', 'Jeremy', 'Harris', 'History', 'I00018');
INSERT INTO student VALUES ('S00393', 'Colton', 'Floyd', 'Biology', 'I00004');
INSERT INTO student VALUES ('S00394', 'Latoya', 'Hopkins', 'History', 'I00017');
INSERT INTO student VALUES ('S00395', 'Wendy', 'Vang', 'Elec. Eng.', 'I00012');
INSERT INTO student VALUES ('S00396', 'Jeffrey', 'Henderson', 'Music', 'I00022');
INSERT INTO student VALUES ('S00397', 'Shirley', 'Patrick', 'Music', 'I00021');
INSERT INTO student VALUES ('S00398', 'Michael', 'Davis', 'Finance', 'I00013');
INSERT INTO student VALUES ('S00399', 'Brittany', 'Peck', 'Physics', 'I00028');
INSERT INTO student VALUES ('S00400', 'Linda', 'Jackson', 'Music', NULL);
INSERT INTO student VALUES ('S00401', 'Joshua', 'Brown', 'Finance', 'I00015');
INSERT INTO student VALUES ('S00402', 'Herbert', 'Cline', 'Finance', 'I00016');
INSERT INTO student VALUES ('S00403', 'Timothy', 'Gutierrez', 'Physics', 'I00026');
INSERT INTO student VALUES ('S00404', 'Norman', 'Spears', 'Elec. Eng.', 'I00009');
INSERT INTO student VALUES ('S00405', 'Mary', 'Stewart', 'Physics', NULL);
INSERT INTO student VALUES ('S00406', 'Richard', 'Hernandez', 'Comp. Sci.', 'I00005');
INSERT INTO student VALUES ('S00407', 'Christopher', 'Barnes', 'Physics', 'I00025');
INSERT INTO student VALUES ('S00408', 'Jason', 'Nguyen', 'Finance', 'I00014');
INSERT INTO student VALUES ('S00409', 'Dennis', 'Nichols', 'Physics', 'I00025');
INSERT INTO student VALUES ('S00410', 'Shannon', 'Fitzgerald', 'Physics', NULL);
INSERT INTO student VALUES ('S00411', 'David', 'Moran', 'Music', 'I00021');
INSERT INTO student VALUES ('S00412', 'Lindsay', 'Stephens', 'Finance', 'I00016');
INSERT INTO student VALUES ('S00413', 'Lori', 'Diaz', 'Elec. Eng.', 'I00011');
INSERT INTO student VALUES ('S00414', 'Susan', 'Bryant', 'Comp. Sci.', 'I00006');
INSERT INTO student VALUES ('S00415', 'Shawn', 'Martinez', 'Elec. Eng.', 'I00012');
INSERT INTO student VALUES ('S00416', 'Walter', 'Hall', 'Elec. Eng.', 'I00011');
INSERT INTO student VALUES ('S00417', 'Mary', 'Mcintyre', 'Physics', 'I00027');
INSERT INTO student VALUES ('S00418', 'Patricia', 'Sanchez', 'History', 'I00018');
INSERT INTO student VALUES ('S00419', 'Nicholas', 'Allen', 'Elec. Eng.', 'I00012');
INSERT INTO student VALUES ('S00420', 'Erin', 'Scott', 'Elec. Eng.', 'I00011');
INSERT INTO student VALUES ('S00421', 'Heather', 'Padilla', 'Biology', 'I00003');
INSERT INTO student VALUES ('S00422', 'Katherine', 'Ball', 'Finance', 'I00013');
INSERT INTO student VALUES ('S00423', 'Samantha', 'Orr', 'Biology', 'I00004');
INSERT INTO student VALUES ('S00424', 'Emily', 'Williams', 'Physics', 'I00027');
INSERT INTO student VALUES ('S00425', 'Carla', 'White', 'Finance', 'I00016');
INSERT INTO student VALUES ('S00426', 'Raymond', 'Alvarez', 'Finance', 'I00013');
INSERT INTO student VALUES ('S00427', 'Natasha', 'Schroeder', 'Elec. Eng.', 'I00009');
INSERT INTO student VALUES ('S00428', 'Jesse', 'Farley', 'Biology', 'I00004');
INSERT INTO student VALUES ('S00429', 'Kayla', 'Blevins', 'Elec. Eng.', 'I00010');
INSERT INTO student VALUES ('S00430', 'Thomas', 'Hendrix', 'Music', 'I00022');
INSERT INTO student VALUES ('S00431', 'Lawrence', 'Shaffer', 'Biology', 'I00001');
INSERT INTO student VALUES ('S00432', 'Shannon', 'Hawkins', 'History', 'I00017');
INSERT INTO student VALUES ('S00433', 'Justin', 'Green', 'History', 'I00020');
INSERT INTO student VALUES ('S00434', 'Joshua', 'Haley', 'Comp. Sci.', 'I00007');
INSERT INTO student VALUES ('S00435', 'Paula', 'Mcmahon', 'Music', 'I00022');
INSERT INTO student VALUES ('S00436', 'Brooke', 'Stewart', 'Comp. Sci.', 'I00006');
INSERT INTO student VALUES ('S00437', 'Brian', 'Douglas', 'Comp. Sci.', NULL);
INSERT INTO student VALUES ('S00438', 'Joshua', 'Simpson', 'Music', NULL);
INSERT INTO student VALUES ('S00439', 'Duane', 'Greene', 'Music', 'I00022');
INSERT INTO student VALUES ('S00440', 'Jeffery', 'Long', 'Finance', 'I00016');
INSERT INTO student VALUES ('S00441', 'Sarah', 'Ray', 'Comp. Sci.', NULL);
INSERT INTO student VALUES ('S00442', 'Cynthia', 'Stevenson', 'Music', 'I00022');
INSERT INTO student VALUES ('S00443', 'Marilyn', 'Tucker', 'Finance', 'I00015');
INSERT INTO student VALUES ('S00444', 'Eric', 'Delacruz', 'Comp. Sci.', NULL);
INSERT INTO student VALUES ('S00445', 'Gabriella', 'Gross', 'Biology', 'I00002');
INSERT INTO student VALUES ('S00446', 'Wayne', 'Ellis', 'Biology', 'I00002');
INSERT INTO student VALUES ('S00447', 'Tyler', 'Peterson', 'Biology', 'I00001');
INSERT INTO student VALUES ('S00448', 'Mary', 'Rodriguez', 'Comp. Sci.', 'I00005');
INSERT INTO student VALUES ('S00449', 'Joseph', 'Anderson', 'Biology', 'I00003');
INSERT INTO student VALUES ('S00450', 'Thomas', 'Walter', 'History', 'I00019');
INSERT INTO student VALUES ('S00451', 'Wayne', 'Scott', 'Comp. Sci.', 'I00005');
INSERT INTO student VALUES ('S00452', 'William', 'Berger', 'History', 'I00019');
INSERT INTO student VALUES ('S00453', 'Frank', 'Hernandez', 'Physics', 'I00026');
INSERT INTO student VALUES ('S00454', 'Leslie', 'Levy', 'Music', NULL);
INSERT INTO student VALUES ('S00455', 'Michael', 'West', 'History', 'I00017');
INSERT INTO student VALUES ('S00456', 'Kim', 'Lewis', 'Comp. Sci.', 'I00005');
INSERT INTO student VALUES ('S00457', 'Amber', 'Ross', 'Comp. Sci.', NULL);
INSERT INTO student VALUES ('S00458', 'Brendan', 'Calderon', 'Finance', 'I00013');
INSERT INTO student VALUES ('S00459', 'Justin', 'Kirk', 'Finance', 'I00014');
INSERT INTO student VALUES ('S00460', 'Shannon', 'Evans', 'Biology', 'I00001');
INSERT INTO student VALUES ('S00461', 'Tyler', 'Munoz', 'Music', 'I00021');
INSERT INTO student VALUES ('S00462', 'John', 'Brady', 'Music', 'I00024');
INSERT INTO student VALUES ('S00463', 'Dawn', 'Fernandez', 'Physics', 'I00025');
INSERT INTO student VALUES ('S00464', 'Jeffery', 'Guerrero', 'Biology', 'I00003');
INSERT INTO student VALUES ('S00465', 'Shannon', 'Parks', 'Music', 'I00023');
INSERT INTO student VALUES ('S00466', 'Donna', 'Miller', 'Elec. Eng.', 'I00009');
INSERT INTO student VALUES ('S00467', 'Scott', 'Webster', 'Physics', 'I00026');
INSERT INTO student VALUES ('S00468', 'Seth', 'Walton', 'Biology', 'I00001');
INSERT INTO student VALUES ('S00469', 'Jeffrey', 'Morrison', 'Finance', 'I00015');
INSERT INTO student VALUES ('S00470', 'Gwendolyn', 'Young', 'Music', 'I00024');
INSERT INTO student VALUES ('S00471', 'Jacqueline', 'Cortez', 'Biology', 'I00002');
INSERT INTO student VALUES ('S00472', 'Bryan', 'Gonzalez', 'History', 'I00018');
INSERT INTO student VALUES ('S00473', 'Nancy', 'Vazquez', 'Music', 'I00022');
INSERT INTO student VALUES ('S00474', 'Rachel', 'Burch', 'Music', 'I00022');
INSERT INTO student VALUES ('S00475', 'Jacob', 'Santiago', 'History', 'I00017');
INSERT INTO student VALUES ('S00476', 'Ashley', 'Villegas', 'Finance', 'I00015');
INSERT INTO student VALUES ('S00477', 'Thomas', 'Salazar', 'History', 'I00017');
INSERT INTO student VALUES ('S00478', 'Matthew', 'Dyer', 'Finance', 'I00016');
INSERT INTO student VALUES ('S00479', 'Jennifer', 'Sutton', 'Biology', 'I00002');
INSERT INTO student VALUES ('S00480', 'Ronald', 'Lopez', 'Biology', 'I00002');
INSERT INTO student VALUES ('S00481', 'Gregory', 'Greer', 'Biology', 'I00003');
INSERT INTO student VALUES ('S00482', 'Joseph', 'Smith', 'Finance', 'I00013');
INSERT INTO student VALUES ('S00483', 'Michelle', 'Gomez', 'Music', 'I00022');
INSERT INTO student VALUES ('S00484', 'Felicia', 'Carroll', 'Comp. Sci.', NULL);
INSERT INTO student VALUES ('S00485', 'Samuel', 'Rodriguez', 'Comp. Sci.', 'I00007');
INSERT INTO student VALUES ('S00486', 'Nicole', 'Sanchez', 'Biology', 'I00002');
INSERT INTO student VALUES ('S00487', 'Carla', 'Guerrero', 'Elec. Eng.', 'I00012');
INSERT INTO student VALUES ('S00488', 'Michelle', 'Anderson', 'Elec. Eng.', NULL);
INSERT INTO student VALUES ('S00489', 'Michael', 'Shepherd', 'History', 'I00017');
INSERT INTO student VALUES ('S00490', 'Mark', 'Rasmussen', 'Biology', 'I00001');
INSERT INTO student VALUES ('S00491', 'Amy', 'Stein', 'Music', 'I00022');
INSERT INTO student VALUES ('S00492', 'Michael', 'Lucas', 'Physics', 'I00026');
INSERT INTO student VALUES ('S00493', 'Sandra', 'Evans', 'Finance', NULL);
INSERT INTO student VALUES ('S00494', 'Randall', 'Morales', 'Music', 'I00024');
INSERT INTO student VALUES ('S00495', 'Rachel', 'Levine', 'Physics', 'I00026');
INSERT INTO student VALUES ('S00496', 'Anthony', 'Chen', 'Physics', 'I00026');
INSERT INTO student VALUES ('S00497', 'Misty', 'Hayes', 'Physics', 'I00026');
INSERT INTO student VALUES ('S00498', 'Angela', 'Miller', 'History', 'I00018');
INSERT INTO student VALUES ('S00499', 'James', 'Bell', 'Comp. Sci.', NULL);
INSERT INTO student VALUES ('S00500', 'Katrina', 'Taylor', 'Biology', 'I00003');

-- ADMIN
INSERT INTO admin VALUES ('A00', 'Lyra', 'Whitney');
INSERT INTO admin VALUES ('A01', 'Jeffery', 'Bowers');
INSERT INTO admin VALUES ('A02', 'Elisa', 'Burke');

-- LOGIN
INSERT INTO login VALUES ('I00001', 'mpena', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'instructor');
INSERT INTO login VALUES ('I00002', 'mglass', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'instructor');
INSERT INTO login VALUES ('I00003', 'cschroeder', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'instructor');
INSERT INTO login VALUES ('I00004', 'iwalker', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'instructor');
INSERT INTO login VALUES ('I00005', 'hsolis', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'instructor');
INSERT INTO login VALUES ('I00006', 'rfields', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'instructor');
INSERT INTO login VALUES ('I00007', 'abuck', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'instructor');
INSERT INTO login VALUES ('I00008', 'jclarke', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'instructor');
INSERT INTO login VALUES ('I00009', 'kdorsey', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'instructor');
INSERT INTO login VALUES ('I00010', 'ebrowning', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'instructor');
INSERT INTO login VALUES ('I00011', 'phendricks', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'instructor');
INSERT INTO login VALUES ('I00012', 'dmagana', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'instructor');
INSERT INTO login VALUES ('I00013', 'ahoffman', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'instructor');
INSERT INTO login VALUES ('I00014', 'scase', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'instructor');
INSERT INTO login VALUES ('I00015', 'ccastro', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'instructor');
INSERT INTO login VALUES ('I00016', 'jmacdonald', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'instructor');
INSERT INTO login VALUES ('I00017', 'rxiong', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'instructor');
INSERT INTO login VALUES ('I00018', 'ahayden', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'instructor');
INSERT INTO login VALUES ('I00019', 'ashort', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'instructor');
INSERT INTO login VALUES ('I00020', 'hshepard', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'instructor');
INSERT INTO login VALUES ('I00021', 'nstrickland', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'instructor');
INSERT INTO login VALUES ('I00022', 'kburns', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'instructor');
INSERT INTO login VALUES ('I00023', 'esmall', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'instructor');
INSERT INTO login VALUES ('I00024', 'rmcgee', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'instructor');
INSERT INTO login VALUES ('I00025', 'kkent', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'instructor');
INSERT INTO login VALUES ('I00026', 'mrivas', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'instructor');
INSERT INTO login VALUES ('I00027', 'aweiss', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'instructor');
INSERT INTO login VALUES ('I00028', 'kpatrick', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'instructor');
INSERT INTO login VALUES ('S00001', 'jpeterson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00002', 'cthompson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00003', 'lcontreras', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00004', 'gholmes', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00005', 'jpotter', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00006', 'abarrett', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00007', 'nmclaughlin', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00008', 'bstrickland', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00009', 'agrant', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00010', 'jrogers', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00011', 'plong', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00012', 'ajohnson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00013', 'jjackson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00014', 'btaylor', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00015', 'asutton', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00016', 'gvazquez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00017', 'pfaulkner', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00018', 'dgraham', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00019', 'hcooper', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00020', 'whughes', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00021', 'jholmes', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00022', 'djones', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00023', 'vflores', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00024', 'jhouston', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00025', 'lobrien', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00026', 'mmiller', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00027', 'jwolfe', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00028', 'jgarcia', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00029', 'rshepard', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00030', 'efreeman', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00031', 'bdelacruz', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00032', 'abrooks', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00033', 'jcruz', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00034', 'jlyons', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00035', 'pwelch', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00036', 'aschultz', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00037', 'sanderson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00038', 'lbender', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00039', 'jgross', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00040', 'ewhitehead', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00041', 'wwilliams', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00042', 'hashley', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00043', 'pruiz', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00044', 'adixon', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00045', 'jtorres', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00046', 'mcarrillo', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00047', 'adiaz', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00048', 'nstewart', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00049', 'ccohen', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00050', 'bwhite', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00051', 'sramirez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00052', 'bgarner', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00053', 'nshannon', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00054', 'bjackson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00055', 'brogers', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00056', 'jbrown', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00057', 'mmeyers', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00058', 'hcolon', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00059', 'jarias', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00060', 'pkim', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00061', 'jwoods', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00062', 'dharrison', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00063', 'bmontgomery', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00064', 'gdavis', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00065', 'zmarquez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00066', 'cjackson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00067', 'rdominguez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00068', 'bnunez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00069', 'jschneider', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00070', 'aclark', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00071', 'kdean', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00072', 'spowell', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00073', 'lmercer', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00074', 'rharris', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00075', 'jcohen', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00076', 'pcarpenter', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00077', 'shuynh', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00078', 'jrowland', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00079', 'jhiggins', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00080', 'bpeters', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00081', 'jmartinez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00082', 'fwalls', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00083', 'ebennett', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00084', 'eharris', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00085', 'arichardson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00086', 'csantos', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00087', 'ejarvis', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00088', 'jrich', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00089', 'bking', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00090', 'lroach', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00091', 'bthompson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00092', 'jvincent', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00093', 'mmacdonald', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00094', 'vruiz', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00095', 'apetersen', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00096', 'mprice', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00097', 'croberts', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00098', 'jjames', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00099', 'jwarren', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00100', 'ptaylor', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00101', 'cschwartz', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00102', 'bwalsh', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00103', 'mgordon', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00104', 'rbecker', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00105', 'sgutierrez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00106', 'scaldwell', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00107', 'avalencia', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00108', 'amora', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00109', 'dcurtis', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00110', 'rjones', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00111', 'jbryant', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00112', 'tvasquez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00113', 'jjohnson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00114', 'rbyrd', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00115', 'mcoleman', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00116', 'vdunn', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00117', 'mking', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00118', 'twatson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00119', 'wanderson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00120', 'dsimmons', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00121', 'jsmith', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00122', 'ralvarado', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00123', 'dallen', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00124', 'nmiles', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00125', 'corr', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00126', 'wbowers', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00127', 'jjones', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00128', 'shill', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00129', 'sburton', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00130', 'jroberts', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00131', 'mhuffman', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00132', 'benglish', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00133', 'jhernandez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00134', 'slyons', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00135', 'efranco', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00136', 'mlee', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00137', 'jlove', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00138', 'dthomas', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00139', 'jcurtis', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00140', 'sharper', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00141', 'mwilliams', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00142', 'mryan', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00143', 'bhorton', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00144', 'cphillips', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00145', 'jgrimes', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00146', 'asmith', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00147', 'rjenkins', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00148', 'dwhite', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00149', 'asanchez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00150', 'rroman', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00151', 'gbailey', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00152', 'lluna', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00153', 'jmoore', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00154', 'jsmith1', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00155', 'emason', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00156', 'cjohnson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00157', 'tfarrell', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00158', 'chall', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00159', 'jrodriguez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00160', 'bweber', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00161', 'mhayes', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00162', 'cjones', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00163', 'hcole', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00164', 'mturner', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00165', 'jdouglas', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00166', 'moconnell', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00167', 'rhodges', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00168', 'tmathews', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00169', 'dsanchez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00170', 'mhawkins', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00171', 'jmoran', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00172', 'tlittle', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00173', 'tpatel', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00174', 'jtorres1', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00175', 'hreilly', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00176', 'whuff', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00177', 'csmith', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00178', 'mkaiser', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00179', 'pmccormick', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00180', 'ntaylor', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00181', 'sbanks', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00182', 'sgreene', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00183', 'mrodriguez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00184', 'jaustin', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00185', 'gwest', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00186', 'gmiller', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00187', 'dbriggs', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00188', 'jperez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00189', 'wwatson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00190', 'tlowe', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00191', 'dmorales', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00192', 'jjohnson1', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00193', 'mmoss', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00194', 'dlittle', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00195', 'jstevens', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00196', 'yparker', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00197', 'jwarren1', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00198', 'scook', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00199', 'espencer', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00200', 'mthomas', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00201', 'sgreen', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00202', 'sgrant', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00203', 'jbrewer', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00204', 'sjoyce', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00205', 'wwatts', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00206', 'ljennings', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00207', 'bstewart', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00208', 'vsanford', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00209', 'lstewart', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00210', 'dbell', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00211', 'akaiser', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00212', 'malvarez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00213', 'varroyo', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00214', 'tmcgrath', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00215', 'rward', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00216', 'jhood', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00217', 'drivers', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00218', 'cwilliams', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00219', 'jjohnson2', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00220', 'sturner', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00221', 'ltravis', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00222', 'rclark', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00223', 'amoreno', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00224', 'kreese', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00225', 'mcummings', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00226', 'lbailey', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00227', 'aclark1', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00228', 'mcarter', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00229', 'kkelly', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00230', 'jjones1', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00231', 'gcharles', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00232', 'amccoy', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00233', 'kmorrow', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00234', 'kcastro', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00235', 'jmoore1', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00236', 'broberts', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00237', 'kroberts', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00238', 'lguzman', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00239', 'mpalmer', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00240', 'spowell1', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00241', 'bmoran', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00242', 'mdaniels', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00243', 'lgarcia', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00244', 'mmarquez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00245', 'wwalker', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00246', 'jsalazar', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00247', 'mmorales', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00248', 'rlong', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00249', 'adecker', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00250', 'cjackson1', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00251', 'pthompson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00252', 'kwilliams', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00253', 'cnolan', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00254', 'cgarza', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00255', 'jtran', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00256', 'mthomas1', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00257', 'kbrown', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00258', 'eanderson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00259', 'mburgess', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00260', 'mnorman', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00261', 'saustin', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00262', 'kford', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00263', 'criley', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00264', 'stownsend', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00265', 'smoore', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00266', 'amclaughlin', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00267', 'tschaefer', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00268', 'badams', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00269', 'ahenry', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00270', 'kperez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00271', 'gjohnson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00272', 'tsmith', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00273', 'cgoodman', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00274', 'jpearson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00275', 'ahill', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00276', 'kbaker', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00277', 'cberry', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00278', 'ajones', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00279', 'ahernandez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00280', 'mroberts', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00281', 'croach', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00282', 'sfuentes', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00283', 'dflores', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00284', 'chanson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00285', 'cjohnson1', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00286', 'cmiller', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00287', 'aweaver', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00288', 'gdavenport', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00289', 'nanderson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00290', 'smatthews', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00291', 'jcase', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00292', 'zstewart', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00293', 'aalexander', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00294', 'pmartinez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00295', 'rbates', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00296', 'kchung', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00297', 'tlopez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00298', 'dmcdonald', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00299', 'jhunt', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00300', 'itorres', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00301', 'kparker', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00302', 'cward', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00303', 'djenkins', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00304', 'esmith', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00305', 'tmedina', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00306', 'lhawkins', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00307', 'mflores', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00308', 'tmiranda', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00309', 'ahenderson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00310', 'smiller', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00311', 'aadams', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00312', 'mgibson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00313', 'jhernandez1', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00314', 'jkeller', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00315', 'ccampos', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00316', 'jgray', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00317', 'cwoodard', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00318', 'aoneal', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00319', 'bcrawford', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00320', 'mmorrison', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00321', 'dreid', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00322', 'dsmith', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00323', 'mturner1', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00324', 'mgates', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00325', 'jbrown1', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00326', 'sjohns', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00327', 'jwilson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00328', 'anorris', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00329', 'jdougherty', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00330', 'aclark2', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00331', 'tcurry', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00332', 'sshaw', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00333', 'hmeyer', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00334', 'ccarney', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00335', 'drussell', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00336', 'jrussell', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00337', 'spowell2', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00338', 'atownsend', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00339', 'vramsey', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00340', 'tfreeman', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00341', 'mashley', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00342', 'ktaylor', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00343', 'bmaxwell', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00344', 'amalone', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00345', 'erivera', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00346', 'hsalazar', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00347', 'gvaughan', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00348', 'rvasquez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00349', 'abailey', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00350', 'staylor', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00351', 'awu', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00352', 'sevans', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00353', 'awalker', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00354', 'jedwards', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00355', 'tsanders', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00356', 'jnguyen', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00357', 'rmiller', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00358', 'ebailey', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00359', 'lwheeler', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00360', 'ghill', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00361', 'kkaufman', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00362', 'mriley', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00363', 'wwilliams1', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00364', 'thill', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00365', 'wjones', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00366', 'rduarte', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00367', 'jjohnson3', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00368', 'mbauer', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00369', 'egreen', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00370', 'mgonzalez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00371', 'jsmith2', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00372', 'rlloyd', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00373', 'jsanders', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00374', 'jrodriguez1', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00375', 'pflores', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00376', 'aray', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00377', 'mwhite', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00378', 'acruz', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00379', 'mjoseph', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00380', 'mcooper', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00381', 'jmorris', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00382', 'jlynn', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00383', 'thamilton', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00384', 'vwalker', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00385', 'tsimmons', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00386', 'hdavis', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00387', 'cwilson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00388', 'jmartin', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00389', 'showard', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00390', 'acrawford', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00391', 'wgilbert', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00392', 'jharris', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00393', 'cfloyd', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00394', 'lhopkins', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00395', 'wvang', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00396', 'jhenderson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00397', 'spatrick', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00398', 'mdavis', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00399', 'bpeck', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00400', 'ljackson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00401', 'jbrown2', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00402', 'hcline', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00403', 'tgutierrez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00404', 'nspears', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00405', 'mstewart', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00406', 'rhernandez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00407', 'cbarnes', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00408', 'jnguyen1', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00409', 'dnichols', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00410', 'sfitzgerald', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00411', 'dmoran', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00412', 'lstephens', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00413', 'ldiaz', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00414', 'sbryant', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00415', 'smartinez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00416', 'whall', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00417', 'mmcintyre', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00418', 'psanchez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00419', 'nallen', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00420', 'escott', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00421', 'hpadilla', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00422', 'kball', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00423', 'sorr', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00424', 'ewilliams', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00425', 'cwhite', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00426', 'ralvarez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00427', 'nschroeder', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00428', 'jfarley', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00429', 'kblevins', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00430', 'thendrix', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00431', 'lshaffer', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00432', 'shawkins', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00433', 'jgreen', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00434', 'jhaley', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00435', 'pmcmahon', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00436', 'bstewart1', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00437', 'bdouglas', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00438', 'jsimpson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00439', 'dgreene', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00440', 'jlong', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00441', 'sray', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00442', 'cstevenson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00443', 'mtucker', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00444', 'edelacruz', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00445', 'ggross', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00446', 'wellis', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00447', 'tpeterson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00448', 'mrodriguez1', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00449', 'janderson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00450', 'twalter', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00451', 'wscott', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00452', 'wberger', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00453', 'fhernandez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00454', 'llevy', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00455', 'mwest', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00456', 'klewis', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00457', 'aross', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00458', 'bcalderon', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00459', 'jkirk', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00460', 'sevans1', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00461', 'tmunoz', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00462', 'jbrady', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00463', 'dfernandez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00464', 'jguerrero', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00465', 'sparks', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00466', 'dmiller', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00467', 'swebster', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00468', 'swalton', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00469', 'jmorrison', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00470', 'gyoung', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00471', 'jcortez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00472', 'bgonzalez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00473', 'nvazquez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00474', 'rburch', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00475', 'jsantiago', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00476', 'avillegas', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00477', 'tsalazar', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00478', 'mdyer', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00479', 'jsutton', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00480', 'rlopez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00481', 'ggreer', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00482', 'jsmith3', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00483', 'mgomez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00484', 'fcarroll', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00485', 'srodriguez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00486', 'nsanchez', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00487', 'cguerrero', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00488', 'manderson', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00489', 'mshepherd', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00490', 'mrasmussen', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00491', 'astein', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00492', 'mlucas', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00493', 'sevans2', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00494', 'rmorales', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00495', 'rlevine', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00496', 'achen', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00497', 'mhayes1', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00498', 'amiller', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00499', 'jbell', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('S00500', 'ktaylor1', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'student');
INSERT INTO login VALUES ('A00', 'lwhitney', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'admin');
INSERT INTO login VALUES ('A01', 'jbowers', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'admin');
INSERT INTO login VALUES ('A02', 'eburke', 'a3cda681e88ad1772a35013017474c9e5a5b826f7eb00bfce2ca4bf46d6f0002', 'admin');

-- TIME_SLOT_PATTERN
INSERT INTO time_slot_pattern VALUES ('A');
INSERT INTO time_slot_pattern VALUES ('B');
INSERT INTO time_slot_pattern VALUES ('C');
INSERT INTO time_slot_pattern VALUES ('D');
INSERT INTO time_slot_pattern VALUES ('E');
INSERT INTO time_slot_pattern VALUES ('F');
INSERT INTO time_slot_pattern VALUES ('G');
INSERT INTO time_slot_pattern VALUES ('H');
INSERT INTO time_slot_pattern VALUES ('I');
INSERT INTO time_slot_pattern VALUES ('J');

-- TIME_SLOT
INSERT INTO time_slot VALUES ('A', 'M', '08:00:00', '08:50:00');
INSERT INTO time_slot VALUES ('A', 'W', '08:00:00', '08:50:00');
INSERT INTO time_slot VALUES ('A', 'F', '08:00:00', '08:50:00');
INSERT INTO time_slot VALUES ('B', 'M', '09:00:00', '09:50:00');
INSERT INTO time_slot VALUES ('B', 'W', '09:00:00', '09:50:00');
INSERT INTO time_slot VALUES ('B', 'F', '09:00:00', '09:50:00');
INSERT INTO time_slot VALUES ('C', 'M', '11:00:00', '11:50:00');
INSERT INTO time_slot VALUES ('C', 'W', '11:00:00', '11:50:00');
INSERT INTO time_slot VALUES ('C', 'F', '11:00:00', '11:50:00');
INSERT INTO time_slot VALUES ('D', 'M', '13:00:00', '13:50:00');
INSERT INTO time_slot VALUES ('D', 'W', '13:00:00', '13:50:00');
INSERT INTO time_slot VALUES ('D', 'F', '13:00:00', '13:50:00');
INSERT INTO time_slot VALUES ('E', 'T', '10:30:00', '11:45:00');
INSERT INTO time_slot VALUES ('E', 'R', '10:30:00', '11:45:00');
INSERT INTO time_slot VALUES ('F', 'T', '14:30:00', '15:45:00');
INSERT INTO time_slot VALUES ('F', 'R', '14:30:00', '15:45:00');
INSERT INTO time_slot VALUES ('G', 'M', '16:00:00', '16:50:00');
INSERT INTO time_slot VALUES ('G', 'W', '16:00:00', '16:50:00');
INSERT INTO time_slot VALUES ('G', 'F', '16:00:00', '16:50:00');
INSERT INTO time_slot VALUES ('H', 'W', '10:00:00', '12:30:00');
INSERT INTO time_slot VALUES ('I', 'T', '09:00:00', '10:15:00');
INSERT INTO time_slot VALUES ('I', 'R', '09:00:00', '10:15:00');
INSERT INTO time_slot VALUES ('J', 'T', '13:00:00', '14:15:00');
INSERT INTO time_slot VALUES ('J', 'R', '13:00:00', '14:15:00');

-- SECTION
INSERT INTO section VALUES ('BIO-101', '1', 'Fall', 2024, 'ISB', '201', 'C');
INSERT INTO section VALUES ('BIO-101', '1', 'Spring', 2025, 'Smith', '201', 'F');
INSERT INTO section VALUES ('BIO-101', '1', 'Summer', 2025, 'MSB', '301', 'E');
INSERT INTO section VALUES ('BIO-101', '1', 'Fall', 2025, 'Ritchie', '201', 'D');
INSERT INTO section VALUES ('BIO-201', '1', 'Fall', 2024, 'Merrill', '101', 'B');
INSERT INTO section VALUES ('BIO-201', '1', 'Spring', 2025, 'Smith', '301', 'G');
INSERT INTO section VALUES ('BIO-301', '1', 'Fall', 2024, 'Bowman', '101', 'I');
INSERT INTO section VALUES ('BIO-301', '1', 'Spring', 2025, 'Cunningham', '401', 'D');
INSERT INTO section VALUES ('BIO-399', '1', 'Fall', 2024, 'Merrill', '301', 'A');
INSERT INTO section VALUES ('BIO-399', '1', 'Spring', 2025, 'ISB', '201', 'F');
INSERT INTO section VALUES ('BIO-401', '1', 'Spring', 2025, 'Smith', '101', 'I');
INSERT INTO section VALUES ('CS-101', '1', 'Fall', 2024, 'MSB', '401', 'F');
INSERT INTO section VALUES ('CS-101', '1', 'Spring', 2025, 'McGilvrey', '401', 'H');
INSERT INTO section VALUES ('CS-101', '1', 'Summer', 2025, 'Satterfield', '201', 'G');
INSERT INTO section VALUES ('CS-101', '1', 'Fall', 2025, 'Cunningham', '201', 'G');
INSERT INTO section VALUES ('CS-190', '1', 'Fall', 2024, 'Lowry', '101', 'C');
INSERT INTO section VALUES ('CS-190', '1', 'Spring', 2025, 'McGilvrey', '101', 'J');
INSERT INTO section VALUES ('CS-190', '1', 'Summer', 2025, 'Bowman', '201', 'B');
INSERT INTO section VALUES ('CS-190', '1', 'Fall', 2025, 'ISB', '101', 'H');
INSERT INTO section VALUES ('CS-315', '1', 'Fall', 2024, 'Lowry', '201', 'B');
INSERT INTO section VALUES ('CS-315', '1', 'Spring', 2025, 'Merrill', '201', 'D');
INSERT INTO section VALUES ('CS-319', '1', 'Fall', 2024, 'McGilvrey', '201', 'B');
INSERT INTO section VALUES ('CS-319', '1', 'Spring', 2025, 'MSB', '101', 'D');
INSERT INTO section VALUES ('CS-347', '1', 'Fall', 2024, 'Lowry', '301', 'B');
INSERT INTO section VALUES ('CS-347', '1', 'Spring', 2025, 'Merrill', '101', 'B');
INSERT INTO section VALUES ('EE-181', '1', 'Fall', 2024, 'Satterfield', '201', 'E');
INSERT INTO section VALUES ('EE-181', '1', 'Spring', 2025, 'ISB', '201', 'H');
INSERT INTO section VALUES ('EE-181', '1', 'Summer', 2025, 'Smith', '201', 'E');
INSERT INTO section VALUES ('EE-181', '1', 'Fall', 2025, 'Williams', '201', 'D');
INSERT INTO section VALUES ('EE-201', '1', 'Fall', 2024, 'Bowman', '201', 'F');
INSERT INTO section VALUES ('EE-201', '1', 'Spring', 2025, 'McGilvrey', '401', 'F');
INSERT INTO section VALUES ('EE-301', '1', 'Fall', 2024, 'ISB', '401', 'F');
INSERT INTO section VALUES ('EE-301', '1', 'Spring', 2025, 'Bowman', '301', 'I');
INSERT INTO section VALUES ('EE-315', '1', 'Fall', 2024, 'McGilvrey', '401', 'D');
INSERT INTO section VALUES ('EE-315', '1', 'Spring', 2025, 'ISB', '101', 'I');
INSERT INTO section VALUES ('EE-401', '1', 'Spring', 2025, 'MSB', '101', 'D');
INSERT INTO section VALUES ('FIN-101', '1', 'Fall', 2024, 'Cunningham', '301', 'G');
INSERT INTO section VALUES ('FIN-101', '1', 'Spring', 2025, 'McGilvrey', '401', 'I');
INSERT INTO section VALUES ('FIN-101', '1', 'Summer', 2025, 'Ritchie', '201', 'G');
INSERT INTO section VALUES ('FIN-101', '1', 'Fall', 2025, 'Satterfield', '101', 'B');
INSERT INTO section VALUES ('FIN-201', '1', 'Fall', 2024, 'Cunningham', '301', 'D');
INSERT INTO section VALUES ('FIN-201', '1', 'Spring', 2025, 'Merrill', '201', 'B');
INSERT INTO section VALUES ('FIN-301', '1', 'Fall', 2024, 'Satterfield', '201', 'J');
INSERT INTO section VALUES ('FIN-301', '1', 'Spring', 2025, 'McGilvrey', '201', 'D');
INSERT INTO section VALUES ('FIN-315', '1', 'Fall', 2024, 'MSB', '101', 'G');
INSERT INTO section VALUES ('FIN-315', '1', 'Spring', 2025, 'Lowry', '401', 'G');
INSERT INTO section VALUES ('FIN-401', '1', 'Spring', 2025, 'Satterfield', '101', 'F');
INSERT INTO section VALUES ('HIS-101', '1', 'Fall', 2024, 'Smith', '201', 'J');
INSERT INTO section VALUES ('HIS-101', '1', 'Spring', 2025, 'Ritchie', '401', 'J');
INSERT INTO section VALUES ('HIS-101', '1', 'Summer', 2025, 'ISB', '401', 'H');
INSERT INTO section VALUES ('HIS-101', '1', 'Fall', 2025, 'Bowman', '401', 'A');
INSERT INTO section VALUES ('HIS-201', '1', 'Fall', 2024, 'McGilvrey', '101', 'F');
INSERT INTO section VALUES ('HIS-201', '1', 'Spring', 2025, 'Lowry', '201', 'C');
INSERT INTO section VALUES ('HIS-301', '1', 'Fall', 2024, 'ISB', '101', 'D');
INSERT INTO section VALUES ('HIS-301', '1', 'Spring', 2025, 'ISB', '101', 'G');
INSERT INTO section VALUES ('HIS-351', '1', 'Fall', 2024, 'Smith', '101', 'C');
INSERT INTO section VALUES ('HIS-351', '1', 'Spring', 2025, 'Merrill', '101', 'H');
INSERT INTO section VALUES ('HIS-401', '1', 'Spring', 2025, 'Bowman', '401', 'H');
INSERT INTO section VALUES ('MU-101', '1', 'Fall', 2024, 'ISB', '301', 'E');
INSERT INTO section VALUES ('MU-101', '1', 'Spring', 2025, 'Merrill', '101', 'G');
INSERT INTO section VALUES ('MU-101', '1', 'Summer', 2025, 'Lowry', '201', 'D');
INSERT INTO section VALUES ('MU-101', '1', 'Fall', 2025, 'MSB', '201', 'E');
INSERT INTO section VALUES ('MU-199', '1', 'Fall', 2024, 'ISB', '201', 'A');
INSERT INTO section VALUES ('MU-199', '1', 'Spring', 2025, 'Lowry', '401', 'D');
INSERT INTO section VALUES ('MU-199', '1', 'Summer', 2025, 'Bowman', '401', 'D');
INSERT INTO section VALUES ('MU-199', '1', 'Fall', 2025, 'MSB', '401', 'A');
INSERT INTO section VALUES ('MU-201', '1', 'Fall', 2024, 'Cunningham', '301', 'E');
INSERT INTO section VALUES ('MU-201', '1', 'Spring', 2025, 'Cunningham', '301', 'H');
INSERT INTO section VALUES ('MU-301', '1', 'Fall', 2024, 'Bowman', '101', 'A');
INSERT INTO section VALUES ('MU-301', '1', 'Spring', 2025, 'ISB', '301', 'B');
INSERT INTO section VALUES ('MU-401', '1', 'Spring', 2025, 'Smith', '101', 'J');
INSERT INTO section VALUES ('PHY-101', '1', 'Fall', 2024, 'Cunningham', '301', 'I');
INSERT INTO section VALUES ('PHY-101', '1', 'Spring', 2025, 'McGilvrey', '401', 'J');
INSERT INTO section VALUES ('PHY-101', '1', 'Summer', 2025, 'Ritchie', '101', 'D');
INSERT INTO section VALUES ('PHY-101', '1', 'Fall', 2025, 'Smith', '201', 'B');
INSERT INTO section VALUES ('PHY-201', '1', 'Fall', 2024, 'Merrill', '301', 'G');
INSERT INTO section VALUES ('PHY-201', '1', 'Spring', 2025, 'Bowman', '101', 'C');
INSERT INTO section VALUES ('PHY-301', '1', 'Fall', 2024, 'Satterfield', '301', 'B');
INSERT INTO section VALUES ('PHY-301', '1', 'Spring', 2025, 'MSB', '301', 'F');
INSERT INTO section VALUES ('PHY-315', '1', 'Fall', 2024, 'Smith', '401', 'A');
INSERT INTO section VALUES ('PHY-315', '1', 'Spring', 2025, 'Cunningham', '201', 'E');
INSERT INTO section VALUES ('PHY-401', '1', 'Spring', 2025, 'ISB', '301', 'F');

-- TEACHES
INSERT INTO teaches VALUES ('I00001', 'BIO-101', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00002', 'BIO-101', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00003', 'BIO-101', '1', 'Summer', 2025);
INSERT INTO teaches VALUES ('I00004', 'BIO-101', '1', 'Fall', 2025);
INSERT INTO teaches VALUES ('I00001', 'BIO-201', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00002', 'BIO-201', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00003', 'BIO-301', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00004', 'BIO-301', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00001', 'BIO-399', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00002', 'BIO-399', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00003', 'BIO-401', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00005', 'CS-101', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00006', 'CS-101', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00007', 'CS-101', '1', 'Summer', 2025);
INSERT INTO teaches VALUES ('I00008', 'CS-101', '1', 'Fall', 2025);
INSERT INTO teaches VALUES ('I00005', 'CS-190', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00006', 'CS-190', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00007', 'CS-190', '1', 'Summer', 2025);
INSERT INTO teaches VALUES ('I00008', 'CS-190', '1', 'Fall', 2025);
INSERT INTO teaches VALUES ('I00005', 'CS-315', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00006', 'CS-315', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00007', 'CS-319', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00008', 'CS-319', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00005', 'CS-347', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00006', 'CS-347', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00009', 'EE-181', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00010', 'EE-181', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00011', 'EE-181', '1', 'Summer', 2025);
INSERT INTO teaches VALUES ('I00012', 'EE-181', '1', 'Fall', 2025);
INSERT INTO teaches VALUES ('I00009', 'EE-201', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00010', 'EE-201', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00011', 'EE-301', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00012', 'EE-301', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00009', 'EE-315', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00010', 'EE-315', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00011', 'EE-401', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00013', 'FIN-101', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00014', 'FIN-101', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00015', 'FIN-101', '1', 'Summer', 2025);
INSERT INTO teaches VALUES ('I00016', 'FIN-101', '1', 'Fall', 2025);
INSERT INTO teaches VALUES ('I00013', 'FIN-201', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00014', 'FIN-201', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00015', 'FIN-301', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00016', 'FIN-301', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00013', 'FIN-315', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00014', 'FIN-315', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00015', 'FIN-401', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00017', 'HIS-101', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00018', 'HIS-101', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00019', 'HIS-101', '1', 'Summer', 2025);
INSERT INTO teaches VALUES ('I00020', 'HIS-101', '1', 'Fall', 2025);
INSERT INTO teaches VALUES ('I00017', 'HIS-201', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00018', 'HIS-201', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00019', 'HIS-301', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00020', 'HIS-301', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00017', 'HIS-351', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00018', 'HIS-351', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00019', 'HIS-401', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00021', 'MU-101', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00022', 'MU-101', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00023', 'MU-101', '1', 'Summer', 2025);
INSERT INTO teaches VALUES ('I00024', 'MU-101', '1', 'Fall', 2025);
INSERT INTO teaches VALUES ('I00021', 'MU-199', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00022', 'MU-199', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00023', 'MU-199', '1', 'Summer', 2025);
INSERT INTO teaches VALUES ('I00024', 'MU-199', '1', 'Fall', 2025);
INSERT INTO teaches VALUES ('I00021', 'MU-201', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00022', 'MU-201', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00023', 'MU-301', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00024', 'MU-301', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00021', 'MU-401', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00025', 'PHY-101', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00026', 'PHY-101', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00027', 'PHY-101', '1', 'Summer', 2025);
INSERT INTO teaches VALUES ('I00028', 'PHY-101', '1', 'Fall', 2025);
INSERT INTO teaches VALUES ('I00025', 'PHY-201', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00026', 'PHY-201', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00027', 'PHY-301', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00028', 'PHY-301', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00025', 'PHY-315', '1', 'Fall', 2024);
INSERT INTO teaches VALUES ('I00026', 'PHY-315', '1', 'Spring', 2025);
INSERT INTO teaches VALUES ('I00027', 'PHY-401', '1', 'Spring', 2025);

-- GRADE_VALUE
INSERT INTO grade_value VALUES ('A', 4.0);
INSERT INTO grade_value VALUES ('A-', 3.7);
INSERT INTO grade_value VALUES ('B+', 3.3);
INSERT INTO grade_value VALUES ('B', 3.0);
INSERT INTO grade_value VALUES ('B-', 2.7);
INSERT INTO grade_value VALUES ('C+', 2.3);
INSERT INTO grade_value VALUES ('C', 2.0);
INSERT INTO grade_value VALUES ('C-', 1.7);
INSERT INTO grade_value VALUES ('D+', 1.3);
INSERT INTO grade_value VALUES ('D', 1.0);
INSERT INTO grade_value VALUES ('D-', 0.7);
INSERT INTO grade_value VALUES ('F', 0.0);
INSERT INTO grade_value VALUES ('W', 0.0);
INSERT INTO grade_value VALUES ('I', 0.0);

-- TAKES
INSERT INTO takes VALUES ('S00001', 'FIN-315', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00001', 'CS-315', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00001', 'MU-401', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00001', 'BIO-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00001', 'BIO-101', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00002', 'MU-101', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00002', 'MU-199', '1', 'Summer', 2025, 'A');
INSERT INTO takes VALUES ('S00002', 'MU-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00002', 'CS-347', '1', 'Fall', 2024, 'F');
INSERT INTO takes VALUES ('S00002', 'BIO-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00003', 'PHY-401', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00003', 'PHY-315', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00003', 'HIS-351', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00003', 'EE-181', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00004', 'FIN-315', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00004', 'CS-319', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00004', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00004', 'MU-199', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00004', 'PHY-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00004', 'EE-181', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00005', 'HIS-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00005', 'CS-315', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00005', 'MU-101', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00005', 'EE-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00006', 'MU-101', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00006', 'MU-199', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00006', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00006', 'FIN-315', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00006', 'CS-319', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00006', 'FIN-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00007', 'HIS-201', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00007', 'CS-101', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00007', 'HIS-351', '1', 'Fall', 2024, 'D+');
INSERT INTO takes VALUES ('S00007', 'EE-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00007', 'EE-315', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00008', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00008', 'CS-101', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00008', 'CS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00008', 'HIS-201', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00008', 'MU-401', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00009', 'BIO-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00009', 'CS-315', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00009', 'MU-301', '1', 'Fall', 2024, 'D-');
INSERT INTO takes VALUES ('S00009', 'CS-190', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00009', 'PHY-401', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00010', 'MU-199', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00010', 'MU-101', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00010', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00010', 'BIO-101', '1', 'Spring', 2025, 'D');
INSERT INTO takes VALUES ('S00010', 'HIS-101', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00011', 'FIN-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00011', 'EE-181', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00011', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00011', 'FIN-201', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00011', 'MU-199', '1', 'Summer', 2025, 'B-');
INSERT INTO takes VALUES ('S00012', 'PHY-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00012', 'EE-201', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00012', 'MU-199', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00012', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00013', 'PHY-201', '1', 'Fall', 2024, 'D');
INSERT INTO takes VALUES ('S00013', 'PHY-201', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00013', 'CS-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00013', 'FIN-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00013', 'HIS-301', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00014', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00014', 'EE-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00014', 'FIN-101', '1', 'Summer', 2025, 'D');
INSERT INTO takes VALUES ('S00014', 'CS-190', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00015', 'FIN-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00015', 'FIN-101', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00015', 'CS-190', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00015', 'PHY-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00015', 'EE-181', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00015', 'BIO-101', '1', 'Summer', 2025, 'C-');
INSERT INTO takes VALUES ('S00016', 'PHY-101', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00016', 'CS-319', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00016', 'BIO-101', '1', 'Fall', 2024, 'D-');
INSERT INTO takes VALUES ('S00016', 'HIS-101', '1', 'Summer', 2025, 'C');
INSERT INTO takes VALUES ('S00017', 'PHY-315', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00017', 'HIS-401', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00017', 'HIS-351', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00017', 'FIN-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00017', 'EE-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00017', 'FIN-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00018', 'CS-347', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00018', 'CS-101', '1', 'Summer', 2025, 'B-');
INSERT INTO takes VALUES ('S00018', 'FIN-201', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00018', 'FIN-401', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00019', 'PHY-401', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00019', 'BIO-201', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00019', 'BIO-399', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00019', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00019', 'CS-190', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00020', 'EE-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00020', 'BIO-101', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00020', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00020', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00020', 'FIN-401', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00020', 'MU-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00021', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00021', 'EE-181', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00021', 'CS-315', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00021', 'FIN-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00021', 'BIO-399', '1', 'Fall', 2024, 'D+');
INSERT INTO takes VALUES ('S00021', 'BIO-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00022', 'BIO-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00022', 'BIO-201', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00022', 'FIN-101', '1', 'Summer', 2025, 'D+');
INSERT INTO takes VALUES ('S00022', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00023', 'HIS-301', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00023', 'PHY-101', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00023', 'EE-181', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00023', 'EE-181', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00023', 'PHY-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00023', 'FIN-401', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00024', 'CS-347', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00024', 'MU-201', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00024', 'PHY-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00024', 'MU-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00025', 'CS-347', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00025', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00025', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00025', 'PHY-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00025', 'FIN-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00025', 'HIS-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00026', 'CS-190', '1', 'Spring', 2025, 'F');
INSERT INTO takes VALUES ('S00026', 'CS-315', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00026', 'HIS-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00026', 'FIN-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00026', 'PHY-301', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00027', 'MU-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00027', 'FIN-201', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00027', 'PHY-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00027', 'EE-301', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00027', 'HIS-101', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00028', 'CS-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00028', 'PHY-315', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00028', 'MU-199', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00028', 'BIO-101', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00028', 'EE-401', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00029', 'CS-190', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00029', 'BIO-399', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00029', 'BIO-101', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00029', 'FIN-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00029', 'MU-199', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00029', 'PHY-201', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00030', 'EE-301', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00030', 'CS-101', '1', 'Summer', 2025, 'B-');
INSERT INTO takes VALUES ('S00030', 'CS-190', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00030', 'BIO-201', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00030', 'PHY-301', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00030', 'CS-315', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00031', 'BIO-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00031', 'EE-301', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00031', 'FIN-301', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00031', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00032', 'BIO-399', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00032', 'FIN-201', '1', 'Fall', 2024, 'D');
INSERT INTO takes VALUES ('S00032', 'FIN-315', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00032', 'BIO-101', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00033', 'EE-401', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00033', 'EE-201', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00033', 'MU-101', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00033', 'FIN-301', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00033', 'MU-201', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00034', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00034', 'CS-190', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00034', 'BIO-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00034', 'EE-201', '1', 'Fall', 2024, 'F');
INSERT INTO takes VALUES ('S00034', 'HIS-201', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00035', 'MU-199', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00035', 'HIS-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00035', 'BIO-201', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00035', 'EE-181', '1', 'Summer', 2025, 'B-');
INSERT INTO takes VALUES ('S00036', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00036', 'FIN-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00036', 'BIO-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00036', 'CS-101', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00037', 'CS-319', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00037', 'FIN-101', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00037', 'FIN-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00037', 'FIN-315', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00037', 'FIN-301', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00037', 'BIO-101', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00038', 'BIO-201', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00038', 'CS-190', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00038', 'EE-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00038', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00038', 'FIN-101', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00038', 'PHY-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00039', 'EE-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00039', 'FIN-301', '1', 'Fall', 2024, 'D+');
INSERT INTO takes VALUES ('S00039', 'PHY-315', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00039', 'BIO-301', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00039', 'EE-181', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00040', 'EE-181', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00040', 'PHY-301', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00040', 'HIS-201', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00040', 'CS-347', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00040', 'FIN-101', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00041', 'FIN-101', '1', 'Summer', 2025, 'A');
INSERT INTO takes VALUES ('S00041', 'FIN-101', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00041', 'CS-347', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00041', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00041', 'PHY-301', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00041', 'CS-319', '1', 'Fall', 2024, 'D+');
INSERT INTO takes VALUES ('S00042', 'FIN-301', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00042', 'PHY-201', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00042', 'FIN-315', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00042', 'HIS-351', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00043', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00043', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00043', 'FIN-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00043', 'HIS-301', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00043', 'EE-201', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00044', 'BIO-201', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00044', 'MU-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00044', 'FIN-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00044', 'MU-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00044', 'FIN-201', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00045', 'PHY-301', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00045', 'EE-315', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00045', 'CS-319', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00045', 'BIO-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00045', 'CS-190', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00045', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00046', 'EE-301', '1', 'Spring', 2025, 'D-');
INSERT INTO takes VALUES ('S00046', 'FIN-301', '1', 'Spring', 2025, 'D');
INSERT INTO takes VALUES ('S00046', 'BIO-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00046', 'EE-181', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00047', 'CS-190', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00047', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00047', 'FIN-301', '1', 'Spring', 2025, 'F');
INSERT INTO takes VALUES ('S00047', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00047', 'EE-181', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00048', 'EE-181', '1', 'Summer', 2025, 'A');
INSERT INTO takes VALUES ('S00048', 'EE-401', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00048', 'MU-301', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00048', 'HIS-351', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00048', 'CS-190', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00048', 'PHY-315', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00049', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00049', 'CS-101', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00049', 'CS-315', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00049', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00050', 'FIN-101', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00050', 'PHY-201', '1', 'Fall', 2024, 'D-');
INSERT INTO takes VALUES ('S00050', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00050', 'BIO-399', '1', 'Spring', 2025, 'D');
INSERT INTO takes VALUES ('S00051', 'PHY-201', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00051', 'HIS-351', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00051', 'MU-101', '1', 'Fall', 2024, 'D-');
INSERT INTO takes VALUES ('S00051', 'PHY-315', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00051', 'BIO-201', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00051', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00052', 'PHY-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00052', 'BIO-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00052', 'FIN-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00052', 'EE-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00052', 'HIS-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00053', 'BIO-399', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00053', 'HIS-351', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00053', 'HIS-401', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00053', 'HIS-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00054', 'FIN-315', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00054', 'MU-301', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00054', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00054', 'PHY-101', '1', 'Spring', 2025, 'F');
INSERT INTO takes VALUES ('S00055', 'MU-101', '1', 'Summer', 2025, 'A');
INSERT INTO takes VALUES ('S00055', 'MU-199', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00055', 'HIS-101', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00055', 'MU-301', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00055', 'BIO-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00055', 'PHY-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00056', 'HIS-301', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00056', 'CS-347', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00056', 'MU-101', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00056', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00056', 'HIS-101', '1', 'Summer', 2025, 'A');
INSERT INTO takes VALUES ('S00057', 'HIS-101', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00057', 'PHY-301', '1', 'Spring', 2025, 'D');
INSERT INTO takes VALUES ('S00057', 'EE-315', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00057', 'MU-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00058', 'CS-101', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00058', 'PHY-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00058', 'MU-101', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00058', 'MU-301', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00058', 'BIO-399', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00058', 'BIO-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00059', 'CS-101', '1', 'Summer', 2025, 'B-');
INSERT INTO takes VALUES ('S00059', 'CS-347', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00059', 'CS-190', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00059', 'MU-101', '1', 'Summer', 2025, 'B-');
INSERT INTO takes VALUES ('S00059', 'CS-190', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00059', 'FIN-315', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00060', 'PHY-315', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00060', 'FIN-101', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00060', 'MU-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00060', 'FIN-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00061', 'MU-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00061', 'MU-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00061', 'EE-401', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00061', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00062', 'PHY-201', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00062', 'HIS-201', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00062', 'EE-401', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00062', 'HIS-351', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00062', 'MU-201', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00063', 'CS-319', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00063', 'FIN-101', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00063', 'EE-315', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00063', 'BIO-101', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00064', 'FIN-315', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00064', 'HIS-351', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00064', 'EE-315', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00064', 'CS-190', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00064', 'CS-319', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00064', 'FIN-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00065', 'HIS-351', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00065', 'BIO-399', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00065', 'EE-315', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00065', 'CS-347', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00065', 'EE-201', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00065', 'CS-101', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00066', 'EE-201', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00066', 'MU-301', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00066', 'EE-181', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00066', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00067', 'FIN-315', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00067', 'PHY-401', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00067', 'EE-181', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00067', 'EE-181', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00067', 'HIS-351', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00067', 'HIS-101', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00068', 'EE-181', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00068', 'FIN-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00068', 'FIN-301', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00068', 'PHY-101', '1', 'Summer', 2025, 'D+');
INSERT INTO takes VALUES ('S00069', 'CS-319', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00069', 'CS-315', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00069', 'HIS-351', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00069', 'MU-301', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00070', 'MU-301', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00070', 'CS-315', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00070', 'HIS-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00070', 'EE-315', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00070', 'MU-101', '1', 'Summer', 2025, 'F');
INSERT INTO takes VALUES ('S00070', 'BIO-101', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00071', 'EE-315', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00071', 'FIN-315', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00071', 'BIO-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00071', 'PHY-201', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00071', 'MU-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00072', 'BIO-399', '1', 'Fall', 2024, 'D');
INSERT INTO takes VALUES ('S00072', 'PHY-315', '1', 'Fall', 2024, 'D');
INSERT INTO takes VALUES ('S00072', 'PHY-401', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00072', 'CS-190', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00072', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00073', 'MU-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00073', 'MU-201', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00073', 'PHY-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00073', 'HIS-401', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00074', 'FIN-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00074', 'FIN-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00074', 'BIO-201', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00074', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00074', 'CS-315', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00074', 'CS-190', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00075', 'PHY-201', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00075', 'FIN-201', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00075', 'FIN-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00075', 'FIN-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00076', 'MU-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00076', 'FIN-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00076', 'PHY-101', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00076', 'MU-301', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00076', 'EE-181', '1', 'Spring', 2025, 'D-');
INSERT INTO takes VALUES ('S00077', 'MU-199', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00077', 'HIS-351', '1', 'Fall', 2024, 'D-');
INSERT INTO takes VALUES ('S00077', 'BIO-399', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00077', 'BIO-201', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00077', 'FIN-315', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00077', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00078', 'CS-315', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00078', 'MU-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00078', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00078', 'MU-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00078', 'BIO-399', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00079', 'FIN-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00079', 'FIN-101', '1', 'Spring', 2025, 'F');
INSERT INTO takes VALUES ('S00079', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00079', 'MU-201', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00080', 'EE-301', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00080', 'PHY-315', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00080', 'CS-315', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00080', 'EE-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00081', 'EE-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00081', 'EE-201', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00081', 'MU-401', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00081', 'EE-315', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00081', 'PHY-101', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00082', 'BIO-399', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00082', 'CS-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00082', 'MU-201', '1', 'Fall', 2024, 'D+');
INSERT INTO takes VALUES ('S00082', 'HIS-201', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00083', 'CS-319', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00083', 'FIN-201', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00083', 'FIN-101', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00083', 'FIN-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00083', 'EE-181', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00083', 'PHY-101', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00084', 'BIO-201', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00084', 'EE-181', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00084', 'BIO-101', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00084', 'HIS-351', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00084', 'CS-315', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00085', 'MU-301', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00085', 'MU-101', '1', 'Summer', 2025, 'D-');
INSERT INTO takes VALUES ('S00085', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00085', 'EE-401', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00085', 'MU-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00085', 'FIN-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00086', 'EE-201', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00086', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00086', 'EE-301', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00086', 'PHY-315', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00086', 'EE-315', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00087', 'EE-201', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00087', 'PHY-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00087', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00087', 'BIO-399', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00087', 'MU-101', '1', 'Summer', 2025, 'A');
INSERT INTO takes VALUES ('S00088', 'HIS-351', '1', 'Fall', 2024, 'D+');
INSERT INTO takes VALUES ('S00088', 'FIN-401', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00088', 'EE-201', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00088', 'FIN-101', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00089', 'EE-201', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00089', 'BIO-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00089', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00089', 'FIN-315', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00089', 'HIS-201', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00090', 'MU-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00090', 'MU-201', '1', 'Fall', 2024, 'D-');
INSERT INTO takes VALUES ('S00090', 'MU-201', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00090', 'CS-190', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00090', 'FIN-301', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00090', 'PHY-315', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00091', 'BIO-101', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00091', 'CS-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00091', 'HIS-351', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00091', 'EE-201', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00091', 'FIN-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00091', 'MU-201', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00092', 'HIS-351', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00092', 'MU-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00092', 'EE-181', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00092', 'PHY-101', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00093', 'EE-181', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00093', 'MU-199', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00093', 'MU-101', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00093', 'MU-199', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00093', 'MU-301', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00094', 'MU-101', '1', 'Summer', 2025, 'A');
INSERT INTO takes VALUES ('S00094', 'PHY-301', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00094', 'FIN-201', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00094', 'CS-101', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00094', 'BIO-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00094', 'BIO-201', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00095', 'CS-190', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00095', 'CS-190', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00095', 'CS-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00095', 'FIN-315', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00096', 'FIN-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00096', 'CS-190', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00096', 'FIN-301', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00096', 'CS-101', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00097', 'FIN-201', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00097', 'CS-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00097', 'PHY-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00097', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00097', 'BIO-301', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00097', 'BIO-201', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00098', 'FIN-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00098', 'HIS-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00098', 'EE-201', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00098', 'FIN-101', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00098', 'HIS-351', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00098', 'CS-101', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00099', 'MU-199', '1', 'Summer', 2025, 'D');
INSERT INTO takes VALUES ('S00099', 'FIN-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00099', 'PHY-201', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00099', 'BIO-399', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00099', 'HIS-351', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00100', 'MU-199', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00100', 'MU-101', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00100', 'CS-319', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00100', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00100', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00101', 'FIN-101', '1', 'Summer', 2025, 'A');
INSERT INTO takes VALUES ('S00101', 'FIN-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00101', 'MU-401', '1', 'Spring', 2025, 'D');
INSERT INTO takes VALUES ('S00101', 'CS-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00102', 'FIN-315', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00102', 'BIO-399', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00102', 'MU-401', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00102', 'FIN-201', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00102', 'MU-201', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00103', 'FIN-201', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00103', 'EE-401', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00103', 'FIN-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00103', 'BIO-301', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00104', 'EE-181', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00104', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00104', 'PHY-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00104', 'HIS-101', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00104', 'PHY-201', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00104', 'MU-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00105', 'FIN-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00105', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00105', 'PHY-315', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00105', 'CS-319', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00106', 'MU-101', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00106', 'EE-181', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00106', 'MU-199', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00106', 'PHY-101', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00106', 'EE-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00106', 'HIS-101', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00107', 'CS-315', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00107', 'PHY-201', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00107', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00107', 'FIN-101', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00107', 'MU-199', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00107', 'BIO-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00108', 'CS-347', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00108', 'CS-319', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00108', 'BIO-399', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00108', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00108', 'FIN-315', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00109', 'MU-199', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00109', 'MU-401', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00109', 'BIO-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00109', 'PHY-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00109', 'MU-101', '1', 'Summer', 2025, 'B-');
INSERT INTO takes VALUES ('S00109', 'CS-347', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00110', 'PHY-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00110', 'FIN-301', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00110', 'FIN-101', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00110', 'BIO-201', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00110', 'CS-319', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00110', 'EE-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00111', 'EE-401', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00111', 'CS-190', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00111', 'FIN-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00111', 'PHY-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00111', 'EE-315', '1', 'Fall', 2024, 'D');
INSERT INTO takes VALUES ('S00111', 'FIN-301', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00112', 'PHY-101', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00112', 'PHY-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00112', 'MU-301', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00112', 'FIN-201', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00112', 'EE-201', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00112', 'MU-101', '1', 'Fall', 2024, 'D+');
INSERT INTO takes VALUES ('S00113', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00113', 'MU-199', '1', 'Summer', 2025, 'D');
INSERT INTO takes VALUES ('S00113', 'CS-190', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00113', 'MU-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00114', 'FIN-301', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00114', 'EE-181', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00114', 'BIO-301', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00114', 'MU-201', '1', 'Fall', 2024, 'D-');
INSERT INTO takes VALUES ('S00115', 'FIN-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00115', 'FIN-301', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00115', 'FIN-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00115', 'CS-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00116', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00116', 'EE-301', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00116', 'MU-201', '1', 'Fall', 2024, 'D-');
INSERT INTO takes VALUES ('S00116', 'EE-181', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00117', 'MU-201', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00117', 'CS-315', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00117', 'HIS-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00117', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00118', 'CS-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00118', 'FIN-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00118', 'EE-201', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00118', 'MU-101', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00119', 'EE-401', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00119', 'PHY-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00119', 'BIO-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00119', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00119', 'EE-315', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00119', 'EE-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00120', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00120', 'PHY-201', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00120', 'EE-315', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00120', 'MU-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00121', 'EE-181', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00121', 'MU-201', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00121', 'HIS-301', '1', 'Spring', 2025, 'D-');
INSERT INTO takes VALUES ('S00121', 'EE-401', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00122', 'HIS-301', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00122', 'BIO-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00122', 'CS-101', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00122', 'PHY-315', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00122', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00122', 'PHY-101', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00123', 'PHY-101', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00123', 'MU-101', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00123', 'BIO-301', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00123', 'EE-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00123', 'MU-401', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00123', 'CS-190', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00124', 'BIO-101', '1', 'Summer', 2025, 'C');
INSERT INTO takes VALUES ('S00124', 'EE-401', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00124', 'HIS-351', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00124', 'FIN-101', '1', 'Summer', 2025, 'D-');
INSERT INTO takes VALUES ('S00125', 'CS-315', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00125', 'BIO-201', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00125', 'BIO-301', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00125', 'PHY-101', '1', 'Summer', 2025, 'A');
INSERT INTO takes VALUES ('S00125', 'PHY-315', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00125', 'HIS-201', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00126', 'CS-101', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00126', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00126', 'MU-101', '1', 'Summer', 2025, 'C');
INSERT INTO takes VALUES ('S00126', 'PHY-101', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00127', 'HIS-301', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00127', 'HIS-201', '1', 'Spring', 2025, 'D');
INSERT INTO takes VALUES ('S00127', 'PHY-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00127', 'MU-401', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00128', 'FIN-301', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00128', 'MU-101', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00128', 'EE-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00128', 'FIN-401', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00128', 'PHY-101', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00128', 'HIS-351', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00129', 'MU-199', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00129', 'EE-181', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00129', 'PHY-201', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00129', 'MU-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00129', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00129', 'PHY-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00130', 'PHY-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00130', 'EE-181', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00130', 'BIO-399', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00130', 'MU-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00130', 'HIS-101', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00130', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00131', 'PHY-401', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00131', 'CS-315', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00131', 'MU-199', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00131', 'EE-301', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00131', 'CS-101', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00131', 'BIO-201', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00132', 'EE-181', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00132', 'EE-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00132', 'HIS-101', '1', 'Summer', 2025, 'D+');
INSERT INTO takes VALUES ('S00132', 'EE-401', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00132', 'MU-199', '1', 'Spring', 2025, 'D');
INSERT INTO takes VALUES ('S00133', 'MU-199', '1', 'Summer', 2025, 'B-');
INSERT INTO takes VALUES ('S00133', 'FIN-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00133', 'FIN-201', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00133', 'CS-101', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00133', 'CS-190', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00134', 'EE-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00134', 'FIN-201', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00134', 'PHY-315', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00134', 'FIN-101', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00135', 'CS-319', '1', 'Spring', 2025, 'D-');
INSERT INTO takes VALUES ('S00135', 'PHY-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00135', 'EE-181', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00135', 'HIS-101', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00135', 'MU-199', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00135', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00136', 'MU-301', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00136', 'BIO-301', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00136', 'FIN-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00136', 'CS-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00137', 'HIS-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00137', 'MU-401', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00137', 'CS-190', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00137', 'BIO-401', '1', 'Spring', 2025, 'D');
INSERT INTO takes VALUES ('S00138', 'MU-401', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00138', 'PHY-315', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00138', 'FIN-401', '1', 'Spring', 2025, 'F');
INSERT INTO takes VALUES ('S00138', 'MU-101', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00139', 'PHY-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00139', 'PHY-315', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00139', 'EE-301', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00139', 'CS-190', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00139', 'CS-101', '1', 'Summer', 2025, 'B-');
INSERT INTO takes VALUES ('S00140', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00140', 'PHY-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00140', 'HIS-201', '1', 'Fall', 2024, 'F');
INSERT INTO takes VALUES ('S00140', 'BIO-101', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00140', 'BIO-301', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00140', 'PHY-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00141', 'HIS-351', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00141', 'FIN-101', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00141', 'EE-181', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00141', 'FIN-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00141', 'FIN-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00142', 'PHY-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00142', 'PHY-315', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00142', 'CS-315', '1', 'Spring', 2025, 'D-');
INSERT INTO takes VALUES ('S00142', 'HIS-351', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00142', 'CS-347', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00143', 'MU-401', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00143', 'BIO-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00143', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00143', 'MU-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00143', 'MU-199', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00144', 'BIO-201', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00144', 'CS-319', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00144', 'HIS-201', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00144', 'FIN-301', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00145', 'CS-315', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00145', 'MU-199', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00145', 'MU-101', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00145', 'MU-201', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00145', 'HIS-101', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00145', 'FIN-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00146', 'MU-201', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00146', 'BIO-101', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00146', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00146', 'CS-101', '1', 'Summer', 2025, 'D+');
INSERT INTO takes VALUES ('S00146', 'HIS-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00146', 'HIS-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00147', 'FIN-201', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00147', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00147', 'CS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00147', 'HIS-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00147', 'FIN-201', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00148', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00148', 'FIN-315', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00148', 'FIN-315', '1', 'Spring', 2025, 'D');
INSERT INTO takes VALUES ('S00148', 'PHY-315', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00149', 'HIS-101', '1', 'Summer', 2025, 'F');
INSERT INTO takes VALUES ('S00149', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00149', 'MU-301', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00149', 'CS-347', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00149', 'MU-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00149', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00150', 'FIN-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00150', 'FIN-315', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00150', 'CS-315', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00150', 'PHY-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00150', 'HIS-301', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00151', 'EE-301', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00151', 'CS-315', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00151', 'CS-319', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00151', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00151', 'EE-201', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00151', 'MU-301', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00152', 'MU-199', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00152', 'BIO-301', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00152', 'BIO-301', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00152', 'MU-101', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00153', 'BIO-399', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00153', 'FIN-315', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00153', 'HIS-101', '1', 'Summer', 2025, 'C-');
INSERT INTO takes VALUES ('S00153', 'MU-199', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00153', 'PHY-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00154', 'BIO-301', '1', 'Spring', 2025, 'F');
INSERT INTO takes VALUES ('S00154', 'BIO-401', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00154', 'FIN-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00154', 'FIN-301', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00154', 'EE-181', '1', 'Summer', 2025, 'C-');
INSERT INTO takes VALUES ('S00154', 'CS-347', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00155', 'EE-315', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00155', 'BIO-301', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00155', 'FIN-101', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00155', 'FIN-201', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00156', 'HIS-201', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00156', 'FIN-315', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00156', 'MU-199', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00156', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00156', 'CS-190', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00157', 'MU-199', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00157', 'CS-319', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00157', 'CS-101', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00157', 'FIN-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00157', 'MU-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00158', 'BIO-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00158', 'MU-401', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00158', 'HIS-101', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00158', 'PHY-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00158', 'PHY-101', '1', 'Fall', 2024, 'D+');
INSERT INTO takes VALUES ('S00158', 'FIN-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00159', 'BIO-201', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00159', 'FIN-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00159', 'BIO-101', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00159', 'PHY-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00159', 'CS-190', '1', 'Fall', 2024, 'D-');
INSERT INTO takes VALUES ('S00160', 'FIN-101', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00160', 'PHY-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00160', 'EE-181', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00160', 'BIO-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00160', 'FIN-315', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00161', 'HIS-301', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00161', 'PHY-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00161', 'FIN-401', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00161', 'BIO-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00161', 'MU-199', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00162', 'BIO-201', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00162', 'CS-347', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00162', 'MU-401', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00162', 'EE-181', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00163', 'PHY-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00163', 'FIN-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00163', 'HIS-301', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00163', 'HIS-101', '1', 'Fall', 2024, 'D-');
INSERT INTO takes VALUES ('S00163', 'CS-190', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00163', 'FIN-201', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00164', 'MU-201', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00164', 'HIS-401', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00164', 'FIN-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00164', 'BIO-101', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00164', 'CS-315', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00165', 'HIS-201', '1', 'Fall', 2024, 'D+');
INSERT INTO takes VALUES ('S00165', 'HIS-351', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00165', 'EE-181', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00165', 'EE-201', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00165', 'CS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00166', 'BIO-101', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00166', 'CS-190', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00166', 'HIS-101', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00166', 'PHY-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00166', 'EE-401', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00166', 'EE-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00167', 'PHY-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00167', 'EE-181', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00167', 'MU-201', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00167', 'CS-190', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00168', 'MU-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00168', 'PHY-401', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00168', 'FIN-315', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00168', 'PHY-315', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00169', 'HIS-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00169', 'MU-199', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00169', 'MU-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00169', 'HIS-201', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00169', 'EE-181', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00170', 'MU-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00170', 'HIS-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00170', 'CS-101', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00170', 'CS-190', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00170', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00171', 'FIN-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00171', 'FIN-101', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00171', 'CS-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00171', 'CS-347', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00171', 'BIO-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00171', 'MU-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00172', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00172', 'FIN-201', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00172', 'FIN-315', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00172', 'CS-319', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00172', 'CS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00173', 'PHY-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00173', 'EE-181', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00173', 'MU-101', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00173', 'BIO-101', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00173', 'PHY-201', '1', 'Fall', 2024, 'F');
INSERT INTO takes VALUES ('S00174', 'BIO-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00174', 'HIS-201', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00174', 'PHY-315', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00174', 'FIN-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00175', 'PHY-101', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00175', 'FIN-301', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00175', 'BIO-201', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00175', 'HIS-351', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00175', 'FIN-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00175', 'PHY-301', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00176', 'EE-181', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00176', 'HIS-301', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00176', 'FIN-315', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00176', 'EE-201', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00176', 'CS-190', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00177', 'CS-190', '1', 'Summer', 2025, 'B-');
INSERT INTO takes VALUES ('S00177', 'CS-347', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00177', 'HIS-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00177', 'BIO-301', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00177', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00177', 'MU-401', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00178', 'PHY-315', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00178', 'EE-181', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00178', 'HIS-201', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00178', 'EE-181', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00178', 'EE-181', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00179', 'HIS-301', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00179', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00179', 'CS-315', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00179', 'MU-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00179', 'CS-190', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00180', 'MU-301', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00180', 'PHY-101', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00180', 'HIS-101', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00180', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00180', 'CS-319', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00180', 'CS-315', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00181', 'PHY-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00181', 'FIN-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00181', 'FIN-101', '1', 'Summer', 2025, 'D+');
INSERT INTO takes VALUES ('S00181', 'HIS-351', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00181', 'FIN-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00182', 'MU-199', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00182', 'HIS-401', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00182', 'CS-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00182', 'PHY-201', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00183', 'FIN-101', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00183', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00183', 'BIO-399', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00183', 'EE-401', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00183', 'MU-199', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00184', 'MU-201', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00184', 'BIO-301', '1', 'Spring', 2025, 'D');
INSERT INTO takes VALUES ('S00184', 'HIS-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00184', 'MU-199', '1', 'Summer', 2025, 'A');
INSERT INTO takes VALUES ('S00184', 'EE-315', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00185', 'FIN-201', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00185', 'PHY-101', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00185', 'PHY-315', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00185', 'BIO-101', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00185', 'FIN-315', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00186', 'CS-101', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00186', 'HIS-101', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00186', 'FIN-301', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00186', 'FIN-315', '1', 'Fall', 2024, 'F');
INSERT INTO takes VALUES ('S00186', 'PHY-315', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00186', 'PHY-301', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00187', 'MU-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00187', 'BIO-101', '1', 'Spring', 2025, 'F');
INSERT INTO takes VALUES ('S00187', 'CS-315', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00187', 'CS-190', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00187', 'MU-201', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00188', 'MU-101', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00188', 'HIS-351', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00188', 'PHY-101', '1', 'Spring', 2025, 'D-');
INSERT INTO takes VALUES ('S00188', 'MU-401', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00188', 'HIS-301', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00188', 'BIO-101', '1', 'Fall', 2024, 'D-');
INSERT INTO takes VALUES ('S00189', 'BIO-301', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00189', 'MU-401', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00189', 'HIS-101', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00189', 'HIS-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00189', 'CS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00189', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00190', 'CS-315', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00190', 'BIO-401', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00190', 'MU-101', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00190', 'MU-199', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00190', 'FIN-101', '1', 'Summer', 2025, 'C');
INSERT INTO takes VALUES ('S00190', 'EE-315', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00191', 'CS-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00191', 'PHY-101', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00191', 'CS-319', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00191', 'FIN-315', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00191', 'HIS-351', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00191', 'FIN-315', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00192', 'PHY-101', '1', 'Summer', 2025, 'C-');
INSERT INTO takes VALUES ('S00192', 'EE-181', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00192', 'PHY-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00192', 'HIS-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00193', 'HIS-351', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00193', 'HIS-101', '1', 'Fall', 2024, 'D-');
INSERT INTO takes VALUES ('S00193', 'CS-319', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00193', 'FIN-101', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00193', 'CS-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00193', 'CS-190', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00194', 'EE-181', '1', 'Summer', 2025, 'F');
INSERT INTO takes VALUES ('S00194', 'PHY-201', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00194', 'EE-201', '1', 'Spring', 2025, 'D-');
INSERT INTO takes VALUES ('S00194', 'CS-347', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00194', 'HIS-201', '1', 'Fall', 2024, 'F');
INSERT INTO takes VALUES ('S00194', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00195', 'MU-199', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00195', 'CS-190', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00195', 'HIS-301', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00195', 'MU-199', '1', 'Fall', 2024, 'F');
INSERT INTO takes VALUES ('S00196', 'MU-301', '1', 'Spring', 2025, 'D');
INSERT INTO takes VALUES ('S00196', 'MU-199', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00196', 'EE-201', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00196', 'CS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00197', 'EE-315', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00197', 'CS-190', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00197', 'EE-181', '1', 'Spring', 2025, 'D');
INSERT INTO takes VALUES ('S00197', 'FIN-201', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00198', 'BIO-401', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00198', 'HIS-201', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00198', 'MU-101', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00198', 'HIS-101', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00199', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00199', 'BIO-201', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00199', 'MU-201', '1', 'Fall', 2024, 'D+');
INSERT INTO takes VALUES ('S00199', 'EE-401', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00199', 'EE-315', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00200', 'CS-315', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00200', 'PHY-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00200', 'PHY-201', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00200', 'FIN-101', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00200', 'HIS-101', '1', 'Summer', 2025, 'B-');
INSERT INTO takes VALUES ('S00201', 'BIO-399', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00201', 'CS-315', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00201', 'BIO-401', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00201', 'MU-101', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00201', 'MU-199', '1', 'Summer', 2025, 'B-');
INSERT INTO takes VALUES ('S00201', 'FIN-101', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00202', 'HIS-301', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00202', 'BIO-201', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00202', 'HIS-201', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00202', 'HIS-201', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00202', 'FIN-401', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00203', 'EE-301', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00203', 'CS-101', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00203', 'CS-319', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00203', 'BIO-101', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00203', 'MU-101', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00204', 'HIS-301', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00204', 'HIS-401', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00204', 'HIS-101', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00204', 'MU-199', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00204', 'CS-190', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00204', 'PHY-401', '1', 'Spring', 2025, 'D-');
INSERT INTO takes VALUES ('S00205', 'FIN-201', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00205', 'CS-190', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00205', 'CS-315', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00205', 'MU-101', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00206', 'PHY-101', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00206', 'FIN-301', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00206', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00206', 'FIN-201', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00207', 'CS-347', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00207', 'EE-181', '1', 'Summer', 2025, 'B-');
INSERT INTO takes VALUES ('S00207', 'PHY-315', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00207', 'PHY-301', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00207', 'PHY-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00208', 'EE-315', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00208', 'PHY-101', '1', 'Summer', 2025, 'C');
INSERT INTO takes VALUES ('S00208', 'BIO-101', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00208', 'CS-101', '1', 'Summer', 2025, 'B-');
INSERT INTO takes VALUES ('S00208', 'MU-199', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00209', 'PHY-201', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00209', 'EE-181', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00209', 'MU-301', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00209', 'CS-101', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00209', 'CS-190', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00209', 'CS-101', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00210', 'CS-315', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00210', 'PHY-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00210', 'CS-101', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00210', 'PHY-101', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00211', 'BIO-301', '1', 'Fall', 2024, 'D');
INSERT INTO takes VALUES ('S00211', 'CS-190', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00211', 'BIO-399', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00211', 'FIN-101', '1', 'Summer', 2025, 'A');
INSERT INTO takes VALUES ('S00211', 'MU-301', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00211', 'BIO-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00212', 'CS-315', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00212', 'BIO-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00212', 'PHY-201', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00212', 'FIN-315', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00212', 'HIS-351', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00212', 'PHY-315', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00213', 'HIS-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00213', 'CS-101', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00213', 'MU-101', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00213', 'BIO-301', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00213', 'BIO-101', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00214', 'EE-201', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00214', 'FIN-315', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00214', 'CS-101', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00214', 'PHY-315', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00214', 'BIO-201', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00215', 'FIN-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00215', 'HIS-301', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00215', 'PHY-201', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00215', 'CS-190', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00216', 'FIN-301', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00216', 'CS-315', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00216', 'EE-181', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00216', 'HIS-101', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00217', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00217', 'EE-315', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00217', 'BIO-201', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00217', 'PHY-301', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00218', 'CS-190', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00218', 'EE-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00218', 'BIO-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00218', 'CS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00218', 'MU-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00218', 'EE-401', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00219', 'EE-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00219', 'EE-401', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00219', 'HIS-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00219', 'FIN-101', '1', 'Summer', 2025, 'D-');
INSERT INTO takes VALUES ('S00219', 'BIO-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00219', 'FIN-401', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00220', 'CS-315', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00220', 'FIN-101', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00220', 'PHY-401', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00220', 'CS-190', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00220', 'MU-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00220', 'PHY-301', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00221', 'CS-190', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00221', 'PHY-401', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00221', 'PHY-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00221', 'EE-201', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00222', 'EE-315', '1', 'Fall', 2024, 'D');
INSERT INTO takes VALUES ('S00222', 'FIN-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00222', 'BIO-399', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00222', 'CS-319', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00222', 'EE-315', '1', 'Spring', 2025, 'D');
INSERT INTO takes VALUES ('S00223', 'BIO-201', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00223', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00223', 'MU-101', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00223', 'EE-201', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00223', 'FIN-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00224', 'CS-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00224', 'BIO-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00224', 'PHY-101', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00224', 'FIN-101', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00224', 'PHY-301', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00224', 'MU-199', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00225', 'CS-101', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00225', 'CS-190', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00225', 'MU-301', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00225', 'PHY-315', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00226', 'HIS-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00226', 'CS-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00226', 'CS-101', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00226', 'FIN-401', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00226', 'PHY-201', '1', 'Spring', 2025, 'D-');
INSERT INTO takes VALUES ('S00227', 'PHY-101', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00227', 'FIN-401', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00227', 'FIN-301', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00227', 'EE-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00227', 'EE-201', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00228', 'CS-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00228', 'CS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00228', 'CS-347', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00228', 'EE-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00228', 'MU-401', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00228', 'BIO-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00229', 'BIO-399', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00229', 'PHY-101', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00229', 'FIN-315', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00229', 'CS-347', '1', 'Fall', 2024, 'F');
INSERT INTO takes VALUES ('S00229', 'MU-401', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00229', 'HIS-201', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00230', 'MU-199', '1', 'Summer', 2025, 'C');
INSERT INTO takes VALUES ('S00230', 'CS-101', '1', 'Fall', 2024, 'D+');
INSERT INTO takes VALUES ('S00230', 'BIO-201', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00230', 'EE-201', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00231', 'HIS-201', '1', 'Spring', 2025, 'F');
INSERT INTO takes VALUES ('S00231', 'CS-190', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00231', 'MU-101', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00231', 'EE-315', '1', 'Fall', 2024, 'D');
INSERT INTO takes VALUES ('S00232', 'HIS-101', '1', 'Spring', 2025, 'D');
INSERT INTO takes VALUES ('S00232', 'CS-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00232', 'FIN-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00232', 'BIO-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00232', 'EE-301', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00232', 'PHY-101', '1', 'Summer', 2025, 'A');
INSERT INTO takes VALUES ('S00233', 'EE-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00233', 'BIO-101', '1', 'Summer', 2025, 'A');
INSERT INTO takes VALUES ('S00233', 'FIN-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00233', 'CS-319', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00234', 'BIO-399', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00234', 'HIS-351', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00234', 'PHY-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00234', 'EE-201', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00234', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00235', 'BIO-301', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00235', 'HIS-201', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00235', 'FIN-101', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00235', 'PHY-401', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00236', 'FIN-201', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00236', 'BIO-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00236', 'CS-315', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00236', 'BIO-101', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00236', 'FIN-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00237', 'PHY-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00237', 'BIO-201', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00237', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00237', 'EE-315', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00237', 'CS-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00237', 'HIS-201', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00238', 'PHY-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00238', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00238', 'CS-347', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00238', 'PHY-201', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00238', 'BIO-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00239', 'FIN-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00239', 'PHY-101', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00239', 'HIS-351', '1', 'Fall', 2024, 'D-');
INSERT INTO takes VALUES ('S00239', 'MU-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00239', 'EE-315', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00239', 'EE-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00240', 'FIN-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00240', 'BIO-101', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00240', 'CS-190', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00240', 'EE-181', '1', 'Summer', 2025, 'D+');
INSERT INTO takes VALUES ('S00241', 'HIS-101', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00241', 'MU-199', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00241', 'BIO-101', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00241', 'CS-315', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00241', 'BIO-101', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00242', 'HIS-101', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00242', 'PHY-101', '1', 'Summer', 2025, 'C');
INSERT INTO takes VALUES ('S00242', 'EE-181', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00242', 'HIS-101', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00242', 'CS-347', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00242', 'PHY-101', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00243', 'CS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00243', 'EE-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00243', 'FIN-301', '1', 'Fall', 2024, 'F');
INSERT INTO takes VALUES ('S00243', 'PHY-101', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00243', 'EE-301', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00244', 'CS-101', '1', 'Summer', 2025, 'D');
INSERT INTO takes VALUES ('S00244', 'EE-181', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00244', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00244', 'CS-101', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00245', 'CS-319', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00245', 'FIN-201', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00245', 'PHY-315', '1', 'Spring', 2025, 'F');
INSERT INTO takes VALUES ('S00245', 'PHY-401', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00246', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00246', 'BIO-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00246', 'FIN-101', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00246', 'FIN-101', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00247', 'BIO-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00247', 'EE-401', '1', 'Spring', 2025, 'F');
INSERT INTO takes VALUES ('S00247', 'MU-401', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00247', 'MU-199', '1', 'Fall', 2024, 'F');
INSERT INTO takes VALUES ('S00248', 'PHY-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00248', 'CS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00248', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00248', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00249', 'FIN-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00249', 'CS-190', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00249', 'CS-190', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00249', 'FIN-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00250', 'CS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00250', 'EE-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00250', 'FIN-201', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00250', 'FIN-401', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00250', 'PHY-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00251', 'MU-101', '1', 'Summer', 2025, 'C');
INSERT INTO takes VALUES ('S00251', 'BIO-399', '1', 'Spring', 2025, 'D-');
INSERT INTO takes VALUES ('S00251', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00251', 'CS-190', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00251', 'MU-301', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00252', 'HIS-101', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00252', 'FIN-201', '1', 'Fall', 2024, 'D-');
INSERT INTO takes VALUES ('S00252', 'HIS-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00252', 'FIN-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00253', 'FIN-101', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00253', 'PHY-201', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00253', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00253', 'MU-201', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00253', 'MU-199', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00253', 'MU-101', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00254', 'MU-401', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00254', 'PHY-315', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00254', 'PHY-201', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00254', 'FIN-315', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00255', 'BIO-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00255', 'CS-190', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00255', 'FIN-101', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00255', 'HIS-101', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00255', 'MU-199', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00256', 'FIN-201', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00256', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00256', 'CS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00256', 'HIS-401', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00257', 'BIO-101', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00257', 'CS-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00257', 'PHY-401', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00257', 'CS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00258', 'BIO-401', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00258', 'BIO-399', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00258', 'MU-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00258', 'CS-190', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00258', 'HIS-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00258', 'BIO-201', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00259', 'EE-181', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00259', 'EE-181', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00259', 'BIO-399', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00259', 'BIO-101', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00260', 'PHY-315', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00260', 'MU-101', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00260', 'PHY-401', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00260', 'FIN-101', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00261', 'PHY-315', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00261', 'PHY-101', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00261', 'FIN-101', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00261', 'CS-319', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00261', 'HIS-351', '1', 'Fall', 2024, 'D+');
INSERT INTO takes VALUES ('S00262', 'CS-347', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00262', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00262', 'HIS-301', '1', 'Spring', 2025, 'F');
INSERT INTO takes VALUES ('S00262', 'CS-101', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00263', 'CS-101', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00263', 'HIS-101', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00263', 'FIN-301', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00263', 'EE-201', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00264', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00264', 'PHY-301', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00264', 'HIS-101', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00264', 'MU-199', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00264', 'CS-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00265', 'MU-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00265', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00265', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00265', 'BIO-201', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00265', 'CS-190', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00266', 'BIO-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00266', 'CS-315', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00266', 'CS-347', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00266', 'CS-319', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00266', 'FIN-401', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00266', 'PHY-101', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00267', 'HIS-101', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00267', 'PHY-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00267', 'BIO-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00267', 'HIS-101', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00268', 'EE-201', '1', 'Fall', 2024, 'D+');
INSERT INTO takes VALUES ('S00268', 'BIO-401', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00268', 'FIN-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00268', 'FIN-401', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00269', 'HIS-101', '1', 'Summer', 2025, 'D+');
INSERT INTO takes VALUES ('S00269', 'BIO-399', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00269', 'PHY-101', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00269', 'CS-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00269', 'HIS-301', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00269', 'FIN-301', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00270', 'MU-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00270', 'MU-199', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00270', 'CS-190', '1', 'Summer', 2025, 'C');
INSERT INTO takes VALUES ('S00270', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00271', 'CS-347', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00271', 'FIN-201', '1', 'Fall', 2024, 'D');
INSERT INTO takes VALUES ('S00271', 'HIS-401', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00271', 'BIO-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00272', 'CS-190', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00272', 'MU-199', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00272', 'FIN-315', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00272', 'BIO-101', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00273', 'BIO-201', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00273', 'MU-199', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00273', 'PHY-101', '1', 'Summer', 2025, 'C');
INSERT INTO takes VALUES ('S00273', 'PHY-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00273', 'PHY-301', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00274', 'FIN-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00274', 'BIO-101', '1', 'Summer', 2025, 'B-');
INSERT INTO takes VALUES ('S00274', 'FIN-315', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00274', 'MU-199', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00275', 'CS-190', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00275', 'MU-301', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00275', 'HIS-201', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00275', 'MU-101', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00275', 'MU-199', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00276', 'PHY-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00276', 'HIS-351', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00276', 'MU-199', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00276', 'CS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00277', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00277', 'CS-190', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00277', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00277', 'EE-181', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00277', 'FIN-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00277', 'CS-101', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00278', 'EE-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00278', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00278', 'HIS-351', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00278', 'HIS-101', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00278', 'BIO-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00278', 'PHY-201', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00279', 'HIS-351', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00279', 'FIN-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00279', 'PHY-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00279', 'MU-199', '1', 'Fall', 2024, 'D+');
INSERT INTO takes VALUES ('S00279', 'CS-190', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00280', 'BIO-399', '1', 'Spring', 2025, 'F');
INSERT INTO takes VALUES ('S00280', 'CS-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00280', 'PHY-101', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00280', 'BIO-101', '1', 'Spring', 2025, 'D-');
INSERT INTO takes VALUES ('S00280', 'PHY-201', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00281', 'HIS-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00281', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00281', 'CS-101', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00281', 'PHY-201', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00281', 'EE-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00282', 'EE-181', '1', 'Summer', 2025, 'D+');
INSERT INTO takes VALUES ('S00282', 'MU-101', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00282', 'FIN-201', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00282', 'HIS-351', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00282', 'FIN-101', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00283', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00283', 'MU-199', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00283', 'BIO-301', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00283', 'MU-401', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00284', 'BIO-399', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00284', 'MU-401', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00284', 'HIS-351', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00284', 'BIO-399', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00284', 'HIS-101', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00285', 'HIS-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00285', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00285', 'BIO-401', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00285', 'BIO-301', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00286', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00286', 'BIO-101', '1', 'Summer', 2025, 'B-');
INSERT INTO takes VALUES ('S00286', 'EE-301', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00286', 'EE-201', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00287', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00287', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00287', 'EE-301', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00287', 'PHY-315', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00287', 'EE-181', '1', 'Fall', 2024, 'D+');
INSERT INTO takes VALUES ('S00287', 'PHY-101', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00288', 'CS-190', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00288', 'BIO-101', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00288', 'HIS-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00288', 'MU-301', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00288', 'BIO-399', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00289', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00289', 'FIN-315', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00289', 'BIO-101', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00289', 'HIS-101', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00289', 'CS-347', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00289', 'EE-401', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00290', 'BIO-101', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00290', 'BIO-201', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00290', 'FIN-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00290', 'HIS-301', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00290', 'HIS-101', '1', 'Summer', 2025, 'A');
INSERT INTO takes VALUES ('S00291', 'CS-101', '1', 'Summer', 2025, 'B-');
INSERT INTO takes VALUES ('S00291', 'EE-181', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00291', 'BIO-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00291', 'FIN-315', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00291', 'CS-347', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00292', 'HIS-401', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00292', 'CS-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00292', 'PHY-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00292', 'MU-199', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00292', 'MU-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00292', 'FIN-101', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00293', 'CS-190', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00293', 'MU-401', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00293', 'HIS-401', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00293', 'HIS-201', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00293', 'EE-181', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00293', 'CS-190', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00294', 'BIO-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00294', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00294', 'CS-315', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00294', 'HIS-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00294', 'MU-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00294', 'BIO-399', '1', 'Fall', 2024, 'D-');
INSERT INTO takes VALUES ('S00295', 'FIN-315', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00295', 'PHY-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00295', 'MU-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00295', 'EE-201', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00296', 'HIS-201', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00296', 'EE-315', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00296', 'MU-199', '1', 'Summer', 2025, 'B-');
INSERT INTO takes VALUES ('S00296', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00296', 'EE-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00296', 'CS-347', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00297', 'BIO-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00297', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00297', 'BIO-401', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00297', 'FIN-101', '1', 'Fall', 2024, 'D-');
INSERT INTO takes VALUES ('S00297', 'HIS-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00298', 'MU-201', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00298', 'MU-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00298', 'MU-101', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00298', 'EE-201', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00298', 'HIS-101', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00298', 'PHY-315', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00299', 'CS-315', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00299', 'EE-181', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00299', 'BIO-201', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00299', 'MU-101', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00299', 'PHY-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00300', 'BIO-301', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00300', 'HIS-401', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00300', 'CS-315', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00300', 'HIS-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00301', 'PHY-301', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00301', 'CS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00301', 'BIO-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00301', 'HIS-201', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00301', 'EE-315', '1', 'Fall', 2024, 'D+');
INSERT INTO takes VALUES ('S00302', 'CS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00302', 'MU-201', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00302', 'PHY-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00302', 'PHY-301', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00302', 'EE-181', '1', 'Summer', 2025, 'C-');
INSERT INTO takes VALUES ('S00303', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00303', 'HIS-301', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00303', 'EE-201', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00303', 'MU-201', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00303', 'BIO-401', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00303', 'PHY-401', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00304', 'PHY-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00304', 'MU-101', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00304', 'PHY-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00304', 'FIN-101', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00305', 'FIN-101', '1', 'Spring', 2025, 'F');
INSERT INTO takes VALUES ('S00305', 'MU-199', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00305', 'MU-101', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00305', 'CS-347', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00305', 'EE-181', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00305', 'BIO-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00306', 'FIN-101', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00306', 'HIS-351', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00306', 'MU-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00306', 'EE-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00306', 'BIO-201', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00306', 'PHY-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00307', 'HIS-101', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00307', 'EE-181', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00307', 'MU-199', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00307', 'PHY-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00307', 'CS-190', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00308', 'FIN-201', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00308', 'EE-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00308', 'BIO-399', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00308', 'BIO-301', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00308', 'PHY-315', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00308', 'CS-319', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00309', 'CS-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00309', 'EE-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00309', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00309', 'EE-401', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00309', 'FIN-101', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00309', 'CS-190', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00310', 'BIO-301', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00310', 'MU-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00310', 'MU-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00310', 'PHY-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00311', 'BIO-201', '1', 'Spring', 2025, 'F');
INSERT INTO takes VALUES ('S00311', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00311', 'HIS-351', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00311', 'EE-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00312', 'MU-401', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00312', 'CS-190', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00312', 'HIS-301', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00312', 'EE-181', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00313', 'PHY-201', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00313', 'EE-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00313', 'BIO-399', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00313', 'FIN-401', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00313', 'PHY-315', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00313', 'HIS-101', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00314', 'CS-190', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00314', 'PHY-201', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00314', 'BIO-401', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00314', 'CS-190', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00315', 'MU-199', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00315', 'BIO-399', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00315', 'CS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00315', 'EE-201', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00315', 'BIO-101', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00316', 'HIS-101', '1', 'Fall', 2024, 'D+');
INSERT INTO takes VALUES ('S00316', 'EE-181', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00316', 'BIO-399', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00316', 'CS-347', '1', 'Fall', 2024, 'D');
INSERT INTO takes VALUES ('S00317', 'MU-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00317', 'CS-101', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00317', 'EE-181', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00317', 'PHY-101', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00318', 'HIS-201', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00318', 'PHY-301', '1', 'Spring', 2025, 'F');
INSERT INTO takes VALUES ('S00318', 'BIO-399', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00318', 'FIN-301', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00318', 'EE-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00318', 'CS-347', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00319', 'FIN-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00319', 'HIS-351', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00319', 'EE-315', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00319', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00319', 'MU-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00320', 'EE-315', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00320', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00320', 'PHY-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00320', 'BIO-399', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00320', 'PHY-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00321', 'BIO-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00321', 'HIS-301', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00321', 'EE-315', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00321', 'FIN-301', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00321', 'MU-301', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00322', 'MU-301', '1', 'Fall', 2024, 'D');
INSERT INTO takes VALUES ('S00322', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00322', 'CS-101', '1', 'Summer', 2025, 'C-');
INSERT INTO takes VALUES ('S00322', 'BIO-201', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00322', 'EE-401', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00323', 'MU-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00323', 'MU-101', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00323', 'HIS-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00323', 'CS-190', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00323', 'PHY-101', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00324', 'CS-319', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00324', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00324', 'BIO-101', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00324', 'FIN-201', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00324', 'PHY-315', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00324', 'FIN-401', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00325', 'CS-190', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00325', 'HIS-351', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00325', 'CS-319', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00325', 'FIN-101', '1', 'Summer', 2025, 'D');
INSERT INTO takes VALUES ('S00325', 'BIO-399', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00326', 'FIN-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00326', 'CS-190', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00326', 'PHY-315', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00326', 'CS-347', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00326', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00327', 'CS-315', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00327', 'MU-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00327', 'EE-181', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00327', 'CS-347', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00327', 'MU-401', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00327', 'PHY-315', '1', 'Fall', 2024, 'F');
INSERT INTO takes VALUES ('S00328', 'CS-347', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00328', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00328', 'CS-315', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00328', 'FIN-101', '1', 'Summer', 2025, 'A');
INSERT INTO takes VALUES ('S00328', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00328', 'HIS-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00329', 'HIS-101', '1', 'Summer', 2025, 'C-');
INSERT INTO takes VALUES ('S00329', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00329', 'FIN-101', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00329', 'MU-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00330', 'EE-315', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00330', 'HIS-101', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00330', 'BIO-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00330', 'FIN-201', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00330', 'CS-347', '1', 'Spring', 2025, 'D-');
INSERT INTO takes VALUES ('S00331', 'FIN-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00331', 'PHY-101', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00331', 'FIN-301', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00331', 'CS-315', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00331', 'PHY-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00332', 'MU-199', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00332', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00332', 'FIN-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00332', 'FIN-301', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00333', 'BIO-101', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00333', 'HIS-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00333', 'BIO-399', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00333', 'MU-201', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00334', 'CS-190', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00334', 'BIO-101', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00334', 'MU-199', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00334', 'MU-201', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00335', 'HIS-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00335', 'CS-315', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00335', 'CS-190', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00335', 'EE-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00335', 'CS-347', '1', 'Fall', 2024, 'D+');
INSERT INTO takes VALUES ('S00336', 'BIO-201', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00336', 'BIO-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00336', 'PHY-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00336', 'MU-199', '1', 'Spring', 2025, 'D');
INSERT INTO takes VALUES ('S00336', 'CS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00337', 'FIN-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00337', 'CS-347', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00337', 'CS-347', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00337', 'HIS-101', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00338', 'HIS-101', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00338', 'EE-315', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00338', 'EE-301', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00338', 'CS-101', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00338', 'MU-101', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00338', 'MU-199', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00339', 'MU-199', '1', 'Summer', 2025, 'A');
INSERT INTO takes VALUES ('S00339', 'PHY-301', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00339', 'BIO-401', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00339', 'CS-190', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00339', 'MU-199', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00339', 'EE-315', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00340', 'FIN-315', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00340', 'CS-101', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00340', 'CS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00340', 'HIS-351', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00341', 'PHY-201', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00341', 'PHY-101', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00341', 'FIN-401', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00341', 'CS-190', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00341', 'MU-101', '1', 'Fall', 2024, 'D+');
INSERT INTO takes VALUES ('S00342', 'CS-319', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00342', 'PHY-101', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00342', 'MU-101', '1', 'Spring', 2025, 'D-');
INSERT INTO takes VALUES ('S00342', 'CS-315', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00343', 'HIS-301', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00343', 'PHY-315', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00343', 'PHY-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00343', 'FIN-301', '1', 'Fall', 2024, 'D-');
INSERT INTO takes VALUES ('S00343', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00344', 'PHY-201', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00344', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00344', 'FIN-315', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00344', 'MU-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00344', 'CS-315', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00344', 'MU-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00345', 'FIN-101', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00345', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00345', 'CS-190', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00345', 'CS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00346', 'HIS-351', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00346', 'MU-101', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00346', 'HIS-351', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00346', 'PHY-201', '1', 'Fall', 2024, 'D+');
INSERT INTO takes VALUES ('S00346', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00347', 'HIS-201', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00347', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00347', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00347', 'HIS-101', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00348', 'CS-190', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00348', 'BIO-399', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00348', 'MU-301', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00348', 'HIS-351', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00348', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00348', 'BIO-101', '1', 'Summer', 2025, 'C-');
INSERT INTO takes VALUES ('S00349', 'BIO-101', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00349', 'HIS-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00349', 'CS-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00349', 'HIS-101', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00349', 'CS-319', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00350', 'BIO-399', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00350', 'MU-101', '1', 'Summer', 2025, 'B-');
INSERT INTO takes VALUES ('S00350', 'CS-315', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00350', 'HIS-401', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00351', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00351', 'FIN-101', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00351', 'FIN-401', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00351', 'EE-401', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00351', 'CS-190', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00352', 'CS-315', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00352', 'HIS-351', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00352', 'CS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00352', 'CS-319', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00352', 'HIS-201', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00353', 'BIO-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00353', 'EE-181', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00353', 'FIN-401', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00353', 'FIN-315', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00353', 'CS-190', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00353', 'HIS-401', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00354', 'FIN-315', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00354', 'EE-201', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00354', 'BIO-399', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00354', 'FIN-201', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00354', 'PHY-201', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00355', 'FIN-101', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00355', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00355', 'CS-190', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00355', 'CS-101', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00355', 'HIS-401', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00356', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00356', 'FIN-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00356', 'HIS-101', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00356', 'BIO-399', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00356', 'BIO-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00356', 'CS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00357', 'MU-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00357', 'BIO-101', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00357', 'HIS-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00357', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00358', 'FIN-315', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00358', 'FIN-101', '1', 'Summer', 2025, 'C-');
INSERT INTO takes VALUES ('S00358', 'EE-181', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00358', 'MU-401', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00358', 'EE-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00359', 'CS-347', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00359', 'CS-315', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00359', 'EE-181', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00359', 'BIO-399', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00359', 'FIN-301', '1', 'Spring', 2025, 'F');
INSERT INTO takes VALUES ('S00359', 'EE-301', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00360', 'MU-199', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00360', 'PHY-101', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00360', 'HIS-101', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00360', 'HIS-101', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00360', 'EE-181', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00361', 'BIO-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00361', 'BIO-301', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00361', 'HIS-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00361', 'FIN-101', '1', 'Summer', 2025, 'A');
INSERT INTO takes VALUES ('S00361', 'BIO-201', '1', 'Spring', 2025, 'F');
INSERT INTO takes VALUES ('S00361', 'PHY-201', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00362', 'HIS-351', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00362', 'HIS-351', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00362', 'MU-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00362', 'PHY-101', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00363', 'EE-315', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00363', 'MU-201', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00363', 'PHY-201', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00363', 'MU-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00364', 'BIO-301', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00364', 'PHY-401', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00364', 'PHY-101', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00364', 'CS-190', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00364', 'FIN-101', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00364', 'CS-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00365', 'CS-190', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00365', 'MU-201', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00365', 'EE-181', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00365', 'PHY-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00366', 'EE-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00366', 'BIO-399', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00366', 'CS-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00366', 'MU-401', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00367', 'CS-319', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00367', 'PHY-101', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00367', 'EE-181', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00367', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00367', 'BIO-301', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00367', 'HIS-401', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00368', 'BIO-399', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00368', 'EE-301', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00368', 'BIO-101', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00368', 'EE-181', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00368', 'EE-181', '1', 'Summer', 2025, 'B-');
INSERT INTO takes VALUES ('S00369', 'PHY-101', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00369', 'FIN-401', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00369', 'MU-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00369', 'EE-401', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00369', 'MU-201', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00370', 'BIO-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00370', 'FIN-401', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00370', 'BIO-101', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00370', 'HIS-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00370', 'BIO-101', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00370', 'HIS-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00371', 'HIS-351', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00371', 'FIN-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00371', 'HIS-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00371', 'MU-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00372', 'CS-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00372', 'MU-201', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00372', 'EE-181', '1', 'Spring', 2025, 'D-');
INSERT INTO takes VALUES ('S00372', 'CS-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00373', 'HIS-351', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00373', 'CS-190', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00373', 'EE-181', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00373', 'HIS-401', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00373', 'BIO-399', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00373', 'PHY-301', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00374', 'EE-181', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00374', 'FIN-315', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00374', 'CS-190', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00374', 'EE-315', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00374', 'CS-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00374', 'PHY-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00375', 'EE-315', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00375', 'EE-201', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00375', 'BIO-399', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00375', 'HIS-351', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00375', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00375', 'PHY-301', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00376', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00376', 'MU-201', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00376', 'CS-190', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00376', 'MU-101', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00376', 'HIS-201', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00377', 'PHY-315', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00377', 'HIS-301', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00377', 'PHY-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00377', 'EE-401', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00378', 'EE-181', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00378', 'CS-319', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00378', 'PHY-301', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00378', 'EE-201', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00378', 'FIN-315', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00379', 'HIS-101', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00379', 'FIN-101', '1', 'Summer', 2025, 'C');
INSERT INTO takes VALUES ('S00379', 'PHY-101', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00379', 'HIS-301', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00379', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00380', 'CS-347', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00380', 'PHY-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00380', 'HIS-301', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00380', 'PHY-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00380', 'CS-190', '1', 'Fall', 2024, 'D');
INSERT INTO takes VALUES ('S00380', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00381', 'CS-315', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00381', 'EE-181', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00381', 'HIS-351', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00381', 'CS-101', '1', 'Fall', 2024, 'D');
INSERT INTO takes VALUES ('S00381', 'MU-301', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00382', 'CS-190', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00382', 'EE-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00382', 'PHY-301', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00382', 'MU-101', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00382', 'EE-401', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00383', 'FIN-201', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00383', 'PHY-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00383', 'MU-199', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00383', 'PHY-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00383', 'EE-181', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00383', 'BIO-301', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00384', 'PHY-401', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00384', 'CS-347', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00384', 'MU-199', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00384', 'MU-201', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00385', 'HIS-401', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00385', 'EE-181', '1', 'Fall', 2024, 'F');
INSERT INTO takes VALUES ('S00385', 'EE-315', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00385', 'BIO-301', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00385', 'BIO-401', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00386', 'HIS-401', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00386', 'PHY-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00386', 'CS-190', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00386', 'CS-347', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00387', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00387', 'HIS-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00387', 'CS-315', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00387', 'EE-181', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00387', 'HIS-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00387', 'CS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00388', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00388', 'MU-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00388', 'EE-301', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00388', 'PHY-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00388', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00388', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00389', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00389', 'HIS-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00389', 'EE-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00389', 'HIS-201', '1', 'Fall', 2024, 'D+');
INSERT INTO takes VALUES ('S00390', 'FIN-201', '1', 'Spring', 2025, 'D');
INSERT INTO takes VALUES ('S00390', 'FIN-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00390', 'HIS-401', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00390', 'BIO-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00390', 'MU-201', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00390', 'PHY-315', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00391', 'EE-181', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00391', 'BIO-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00391', 'PHY-201', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00391', 'MU-101', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00391', 'PHY-301', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00391', 'EE-401', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00392', 'BIO-201', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00392', 'MU-101', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00392', 'PHY-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00392', 'CS-101', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00393', 'CS-190', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00393', 'PHY-401', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00393', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00393', 'HIS-201', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00393', 'MU-301', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00393', 'EE-401', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00394', 'MU-199', '1', 'Summer', 2025, 'C-');
INSERT INTO takes VALUES ('S00394', 'BIO-201', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00394', 'CS-190', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00394', 'FIN-315', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00395', 'CS-347', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00395', 'FIN-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00395', 'EE-301', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00395', 'HIS-201', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00395', 'FIN-315', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00395', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00396', 'MU-301', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00396', 'EE-181', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00396', 'CS-315', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00396', 'EE-301', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00397', 'BIO-399', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00397', 'EE-181', '1', 'Spring', 2025, 'F');
INSERT INTO takes VALUES ('S00397', 'MU-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00397', 'BIO-201', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00397', 'FIN-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00398', 'PHY-101', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00398', 'BIO-101', '1', 'Summer', 2025, 'A');
INSERT INTO takes VALUES ('S00398', 'BIO-401', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00398', 'HIS-401', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00398', 'PHY-201', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00399', 'BIO-401', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00399', 'BIO-101', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00399', 'MU-199', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00399', 'PHY-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00399', 'CS-319', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00399', 'CS-190', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00400', 'CS-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00400', 'BIO-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00400', 'BIO-399', '1', 'Spring', 2025, 'D-');
INSERT INTO takes VALUES ('S00400', 'FIN-401', '1', 'Spring', 2025, 'D');
INSERT INTO takes VALUES ('S00401', 'HIS-351', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00401', 'BIO-101', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00401', 'MU-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00401', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00401', 'HIS-101', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00402', 'MU-199', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00402', 'CS-315', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00402', 'PHY-301', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00402', 'CS-190', '1', 'Summer', 2025, 'A');
INSERT INTO takes VALUES ('S00403', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00403', 'BIO-101', '1', 'Summer', 2025, 'C');
INSERT INTO takes VALUES ('S00403', 'FIN-201', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00403', 'CS-190', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00404', 'PHY-401', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00404', 'FIN-101', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00404', 'MU-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00404', 'FIN-201', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00404', 'MU-201', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00405', 'PHY-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00405', 'FIN-201', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00405', 'BIO-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00405', 'MU-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00405', 'MU-201', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00405', 'CS-101', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00406', 'PHY-201', '1', 'Fall', 2024, 'D');
INSERT INTO takes VALUES ('S00406', 'PHY-101', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00406', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00406', 'FIN-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00407', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00407', 'MU-201', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00407', 'CS-101', '1', 'Fall', 2024, 'D-');
INSERT INTO takes VALUES ('S00407', 'EE-181', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00407', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00407', 'HIS-101', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00408', 'CS-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00408', 'CS-101', '1', 'Summer', 2025, 'D-');
INSERT INTO takes VALUES ('S00408', 'EE-301', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00408', 'MU-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00408', 'CS-319', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00408', 'FIN-315', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00409', 'CS-101', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00409', 'BIO-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00409', 'CS-315', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00409', 'EE-181', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00409', 'PHY-401', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00409', 'CS-190', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00410', 'EE-401', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00410', 'BIO-399', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00410', 'PHY-315', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00410', 'BIO-301', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00411', 'HIS-201', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00411', 'PHY-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00411', 'CS-190', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00411', 'BIO-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00411', 'CS-190', '1', 'Spring', 2025, 'F');
INSERT INTO takes VALUES ('S00411', 'CS-319', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00412', 'EE-315', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00412', 'MU-101', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00412', 'EE-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00412', 'CS-347', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00412', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00413', 'EE-201', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00413', 'BIO-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00413', 'HIS-301', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00413', 'EE-315', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00413', 'PHY-101', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00414', 'BIO-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00414', 'MU-401', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00414', 'EE-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00414', 'BIO-399', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00414', 'CS-315', '1', 'Spring', 2025, 'D-');
INSERT INTO takes VALUES ('S00414', 'PHY-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00415', 'EE-301', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00415', 'MU-201', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00415', 'EE-181', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00415', 'HIS-101', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00415', 'EE-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00416', 'FIN-301', '1', 'Fall', 2024, 'D');
INSERT INTO takes VALUES ('S00416', 'CS-101', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00416', 'HIS-201', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00416', 'FIN-101', '1', 'Fall', 2024, 'D-');
INSERT INTO takes VALUES ('S00416', 'BIO-399', '1', 'Spring', 2025, 'F');
INSERT INTO takes VALUES ('S00416', 'PHY-101', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00417', 'FIN-301', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00417', 'CS-101', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00417', 'PHY-401', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00417', 'MU-101', '1', 'Summer', 2025, 'D');
INSERT INTO takes VALUES ('S00417', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00418', 'PHY-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00418', 'CS-347', '1', 'Fall', 2024, 'D+');
INSERT INTO takes VALUES ('S00418', 'CS-190', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00418', 'PHY-101', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00418', 'MU-101', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00419', 'HIS-101', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00419', 'HIS-301', '1', 'Fall', 2024, 'D+');
INSERT INTO takes VALUES ('S00419', 'MU-101', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00419', 'CS-347', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00419', 'PHY-315', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00419', 'MU-301', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00420', 'CS-347', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00420', 'PHY-201', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00420', 'EE-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00420', 'MU-199', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00421', 'MU-201', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00421', 'EE-301', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00421', 'MU-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00421', 'EE-301', '1', 'Spring', 2025, 'D');
INSERT INTO takes VALUES ('S00421', 'PHY-201', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00421', 'FIN-301', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00422', 'CS-315', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00422', 'EE-201', '1', 'Fall', 2024, 'D-');
INSERT INTO takes VALUES ('S00422', 'MU-401', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00422', 'CS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00423', 'CS-101', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00423', 'PHY-101', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00423', 'EE-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00423', 'HIS-351', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00423', 'CS-315', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00424', 'HIS-201', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00424', 'HIS-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00424', 'BIO-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00424', 'BIO-301', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00424', 'MU-199', '1', 'Summer', 2025, 'A');
INSERT INTO takes VALUES ('S00425', 'FIN-315', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00425', 'MU-301', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00425', 'PHY-401', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00425', 'PHY-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00425', 'FIN-101', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00425', 'HIS-101', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00426', 'HIS-101', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00426', 'EE-201', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00426', 'CS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00426', 'FIN-201', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00426', 'EE-315', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00427', 'FIN-101', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00427', 'FIN-401', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00427', 'EE-181', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00427', 'CS-190', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00427', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00428', 'MU-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00428', 'FIN-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00428', 'EE-181', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00428', 'BIO-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00428', 'PHY-301', '1', 'Fall', 2024, 'D');
INSERT INTO takes VALUES ('S00429', 'CS-315', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00429', 'BIO-399', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00429', 'CS-190', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00429', 'FIN-101', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00429', 'MU-101', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00429', 'PHY-201', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00430', 'MU-401', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00430', 'CS-190', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00430', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00430', 'PHY-301', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00430', 'CS-190', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00430', 'HIS-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00431', 'CS-347', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00431', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00431', 'MU-101', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00431', 'FIN-201', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00431', 'CS-315', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00432', 'HIS-401', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00432', 'MU-199', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00432', 'CS-319', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00432', 'BIO-201', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00433', 'BIO-301', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00433', 'CS-347', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00433', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00433', 'EE-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00433', 'CS-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00433', 'CS-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00434', 'HIS-201', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00434', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00434', 'CS-190', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00434', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00434', 'BIO-101', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00435', 'CS-101', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00435', 'FIN-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00435', 'HIS-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00435', 'CS-347', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00436', 'CS-319', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00436', 'PHY-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00436', 'EE-181', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00436', 'PHY-101', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00437', 'HIS-301', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00437', 'PHY-101', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00437', 'FIN-315', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00437', 'PHY-315', '1', 'Fall', 2024, 'D+');
INSERT INTO takes VALUES ('S00437', 'BIO-301', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00438', 'FIN-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00438', 'MU-301', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00438', 'PHY-201', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00438', 'EE-201', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00438', 'BIO-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00439', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00439', 'MU-199', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00439', 'EE-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00439', 'CS-190', '1', 'Summer', 2025, 'D');
INSERT INTO takes VALUES ('S00439', 'HIS-101', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00440', 'EE-201', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00440', 'PHY-315', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00440', 'BIO-101', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00440', 'HIS-301', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00441', 'EE-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00441', 'CS-319', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00441', 'PHY-315', '1', 'Fall', 2024, 'D');
INSERT INTO takes VALUES ('S00441', 'FIN-201', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00442', 'CS-190', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00442', 'CS-315', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00442', 'HIS-351', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00442', 'CS-319', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00442', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00442', 'MU-401', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00443', 'EE-181', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00443', 'EE-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00443', 'CS-347', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00443', 'BIO-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00444', 'BIO-399', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00444', 'EE-201', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00444', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00444', 'FIN-301', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00444', 'FIN-315', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00444', 'CS-101', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00445', 'FIN-201', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00445', 'EE-201', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00445', 'PHY-315', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00445', 'CS-319', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00445', 'CS-315', '1', 'Fall', 2024, 'F');
INSERT INTO takes VALUES ('S00446', 'EE-181', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00446', 'FIN-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00446', 'CS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00446', 'PHY-201', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00446', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00447', 'MU-101', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00447', 'BIO-101', '1', 'Spring', 2025, 'D-');
INSERT INTO takes VALUES ('S00447', 'BIO-399', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00447', 'BIO-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00447', 'CS-315', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00448', 'HIS-351', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00448', 'EE-315', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00448', 'PHY-201', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00448', 'EE-181', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00448', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00448', 'PHY-301', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00449', 'EE-181', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00449', 'BIO-301', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00449', 'PHY-201', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00449', 'PHY-401', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00449', 'BIO-401', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00449', 'CS-347', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00450', 'BIO-399', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00450', 'BIO-201', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00450', 'PHY-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00450', 'PHY-301', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00450', 'FIN-201', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00451', 'PHY-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00451', 'PHY-101', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00451', 'HIS-301', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00451', 'CS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00451', 'EE-301', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00451', 'HIS-101', '1', 'Spring', 2025, 'D-');
INSERT INTO takes VALUES ('S00452', 'CS-101', '1', 'Summer', 2025, 'A');
INSERT INTO takes VALUES ('S00452', 'HIS-351', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00452', 'HIS-351', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00452', 'HIS-301', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00452', 'PHY-101', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00452', 'FIN-401', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00453', 'EE-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00453', 'PHY-101', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00453', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00453', 'BIO-201', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00453', 'HIS-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00453', 'CS-101', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00454', 'FIN-315', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00454', 'HIS-351', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00454', 'EE-401', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00454', 'PHY-101', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00455', 'BIO-301', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00455', 'MU-199', '1', 'Summer', 2025, 'B-');
INSERT INTO takes VALUES ('S00455', 'MU-201', '1', 'Fall', 2024, 'D-');
INSERT INTO takes VALUES ('S00455', 'PHY-401', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00455', 'HIS-351', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00455', 'PHY-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00456', 'CS-319', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00456', 'FIN-201', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00456', 'HIS-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00456', 'BIO-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00456', 'HIS-351', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00456', 'CS-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00457', 'PHY-201', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00457', 'EE-301', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00457', 'EE-181', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00457', 'PHY-101', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00458', 'MU-199', '1', 'Fall', 2024, 'D+');
INSERT INTO takes VALUES ('S00458', 'BIO-301', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00458', 'CS-315', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00458', 'MU-199', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00459', 'MU-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00459', 'PHY-315', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00459', 'CS-319', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00459', 'CS-190', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00459', 'PHY-101', '1', 'Summer', 2025, 'C');
INSERT INTO takes VALUES ('S00460', 'CS-347', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00460', 'PHY-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00460', 'MU-101', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00460', 'EE-401', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00461', 'PHY-301', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00461', 'MU-401', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00461', 'MU-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00461', 'PHY-101', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00461', 'CS-190', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00461', 'FIN-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00462', 'CS-319', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00462', 'EE-181', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00462', 'CS-101', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00462', 'PHY-201', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00462', 'MU-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00463', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00463', 'CS-190', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00463', 'EE-181', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00463', 'EE-181', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00463', 'MU-301', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00463', 'EE-201', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00464', 'MU-199', '1', 'Summer', 2025, 'A');
INSERT INTO takes VALUES ('S00464', 'PHY-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00464', 'FIN-401', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00464', 'FIN-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00465', 'PHY-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00465', 'FIN-101', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00465', 'MU-301', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00465', 'BIO-301', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00465', 'CS-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00466', 'CS-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00466', 'FIN-301', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00466', 'EE-181', '1', 'Summer', 2025, 'A');
INSERT INTO takes VALUES ('S00466', 'BIO-301', '1', 'Fall', 2024, 'D+');
INSERT INTO takes VALUES ('S00467', 'CS-190', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00467', 'HIS-201', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00467', 'MU-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00467', 'HIS-351', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00467', 'PHY-101', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00467', 'CS-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00468', 'EE-201', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00468', 'BIO-301', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00468', 'CS-319', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00468', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00468', 'FIN-301', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00468', 'BIO-201', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00469', 'BIO-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00469', 'MU-101', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00469', 'FIN-301', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00469', 'HIS-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00470', 'HIS-201', '1', 'Fall', 2024, 'D-');
INSERT INTO takes VALUES ('S00470', 'EE-201', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00470', 'MU-199', '1', 'Summer', 2025, 'A');
INSERT INTO takes VALUES ('S00470', 'EE-301', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00471', 'FIN-201', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00471', 'CS-101', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00471', 'CS-315', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00471', 'HIS-101', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00471', 'PHY-201', '1', 'Spring', 2025, 'D-');
INSERT INTO takes VALUES ('S00471', 'EE-181', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00472', 'BIO-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00472', 'PHY-101', '1', 'Spring', 2025, 'D-');
INSERT INTO takes VALUES ('S00472', 'BIO-201', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00472', 'HIS-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00472', 'CS-190', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00473', 'FIN-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00473', 'HIS-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00473', 'MU-101', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00473', 'EE-315', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00473', 'BIO-101', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00474', 'FIN-101', '1', 'Summer', 2025, 'C');
INSERT INTO takes VALUES ('S00474', 'FIN-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00474', 'PHY-315', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00474', 'FIN-401', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00475', 'FIN-301', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00475', 'BIO-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00475', 'CS-190', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00475', 'HIS-101', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00475', 'CS-190', '1', 'Summer', 2025, 'B-');
INSERT INTO takes VALUES ('S00475', 'CS-190', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00476', 'MU-201', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00476', 'FIN-401', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00476', 'CS-190', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00476', 'PHY-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00476', 'FIN-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00477', 'MU-199', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00477', 'PHY-315', '1', 'Spring', 2025, 'D');
INSERT INTO takes VALUES ('S00477', 'MU-101', '1', 'Summer', 2025, 'C+');
INSERT INTO takes VALUES ('S00477', 'PHY-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00478', 'MU-201', '1', 'Fall', 2024, 'C');
INSERT INTO takes VALUES ('S00478', 'CS-190', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00478', 'EE-301', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00478', 'MU-199', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00479', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00479', 'HIS-101', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00479', 'HIS-351', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00479', 'MU-201', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00479', 'CS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00479', 'EE-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00480', 'MU-101', '1', 'Summer', 2025, 'F');
INSERT INTO takes VALUES ('S00480', 'CS-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00480', 'EE-181', '1', 'Summer', 2025, 'B-');
INSERT INTO takes VALUES ('S00480', 'HIS-201', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00480', 'PHY-301', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00480', 'HIS-101', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00481', 'MU-101', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00481', 'CS-190', '1', 'Summer', 2025, 'B-');
INSERT INTO takes VALUES ('S00481', 'MU-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00481', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00482', 'PHY-315', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00482', 'EE-301', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00482', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00482', 'CS-315', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00483', 'FIN-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00483', 'PHY-401', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00483', 'BIO-301', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00483', 'EE-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00483', 'EE-201', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00484', 'BIO-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00484', 'EE-181', '1', 'Summer', 2025, 'B-');
INSERT INTO takes VALUES ('S00484', 'BIO-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00484', 'EE-201', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00485', 'PHY-201', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00485', 'EE-181', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00485', 'HIS-351', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00485', 'MU-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00485', 'PHY-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00486', 'EE-181', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00486', 'MU-301', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00486', 'EE-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00486', 'BIO-101', '1', 'Spring', 2025, 'D+');
INSERT INTO takes VALUES ('S00487', 'FIN-101', '1', 'Spring', 2025, 'D-');
INSERT INTO takes VALUES ('S00487', 'PHY-101', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00487', 'PHY-315', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00487', 'CS-190', '1', 'Summer', 2025, 'F');
INSERT INTO takes VALUES ('S00487', 'HIS-201', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00487', 'HIS-101', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00488', 'MU-301', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00488', 'MU-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00488', 'EE-401', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00488', 'FIN-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00488', 'PHY-315', '1', 'Fall', 2024, 'A');
INSERT INTO takes VALUES ('S00488', 'CS-347', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00489', 'PHY-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00489', 'PHY-301', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00489', 'PHY-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00489', 'EE-315', '1', 'Spring', 2025, 'A-');
INSERT INTO takes VALUES ('S00489', 'HIS-351', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00490', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00490', 'EE-181', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00490', 'BIO-301', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00490', 'CS-347', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00490', 'BIO-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00491', 'CS-347', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00491', 'EE-181', '1', 'Fall', 2024, 'F');
INSERT INTO takes VALUES ('S00491', 'BIO-301', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00491', 'EE-181', '1', 'Summer', 2025, 'B');
INSERT INTO takes VALUES ('S00491', 'HIS-201', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00492', 'BIO-399', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00492', 'BIO-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00492', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00492', 'MU-199', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00492', 'MU-301', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00493', 'BIO-101', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00493', 'PHY-101', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00493', 'FIN-401', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00493', 'HIS-301', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00494', 'HIS-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00494', 'CS-190', '1', 'Spring', 2025, 'D');
INSERT INTO takes VALUES ('S00494', 'CS-190', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00494', 'EE-201', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00495', 'BIO-101', '1', 'Spring', 2025, 'B-');
INSERT INTO takes VALUES ('S00495', 'BIO-401', '1', 'Spring', 2025, 'C-');
INSERT INTO takes VALUES ('S00495', 'EE-301', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00495', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00495', 'MU-101', '1', 'Spring', 2025, 'F');
INSERT INTO takes VALUES ('S00495', 'PHY-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00496', 'HIS-301', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00496', 'PHY-101', '1', 'Summer', 2025, 'B-');
INSERT INTO takes VALUES ('S00496', 'BIO-201', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00496', 'BIO-401', '1', 'Spring', 2025, 'C');
INSERT INTO takes VALUES ('S00496', 'CS-347', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00496', 'BIO-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00497', 'FIN-301', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00497', 'MU-201', '1', 'Spring', 2025, 'B');
INSERT INTO takes VALUES ('S00497', 'HIS-301', '1', 'Fall', 2024, 'C-');
INSERT INTO takes VALUES ('S00497', 'FIN-101', '1', 'Spring', 2025, 'F');
INSERT INTO takes VALUES ('S00497', 'BIO-399', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00497', 'CS-190', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00498', 'EE-201', '1', 'Fall', 2024, 'F');
INSERT INTO takes VALUES ('S00498', 'PHY-315', '1', 'Fall', 2024, 'B+');
INSERT INTO takes VALUES ('S00498', 'BIO-201', '1', 'Fall', 2024, 'A-');
INSERT INTO takes VALUES ('S00498', 'FIN-301', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00498', 'PHY-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00498', 'HIS-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00499', 'CS-347', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00499', 'PHY-401', '1', 'Spring', 2025, 'A');
INSERT INTO takes VALUES ('S00499', 'PHY-315', '1', 'Fall', 2024, 'B');
INSERT INTO takes VALUES ('S00499', 'CS-190', '1', 'Summer', 2025, 'B+');
INSERT INTO takes VALUES ('S00499', 'PHY-101', '1', 'Fall', 2024, 'B-');
INSERT INTO takes VALUES ('S00499', 'HIS-201', '1', 'Fall', 2024, 'C+');
INSERT INTO takes VALUES ('S00500', 'MU-199', '1', 'Spring', 2025, 'C+');
INSERT INTO takes VALUES ('S00500', 'MU-199', '1', 'Summer', 2025, 'A-');
INSERT INTO takes VALUES ('S00500', 'CS-347', '1', 'Spring', 2025, 'B+');
INSERT INTO takes VALUES ('S00500', 'MU-101', '1', 'Fall', 2025, NULL);
INSERT INTO takes VALUES ('S00500', 'MU-101', '1', 'Spring', 2025, 'B-');

-- TRANSCRIPT
INSERT INTO transcript VALUES ('S00001', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00001', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00001', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00001', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00001', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00002', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00002', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Summer', 2025, 'A');
INSERT INTO transcript VALUES ('S00002', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00002', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'F');
INSERT INTO transcript VALUES ('S00002', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00003', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00003', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00003', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00003', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00004', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00004', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00004', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00004', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00004', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00005', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00005', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00005', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00005', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00006', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00006', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00006', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00006', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00006', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00007', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00007', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00007', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'D+');
INSERT INTO transcript VALUES ('S00007', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00007', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00008', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00008', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00008', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00009', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00009', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00009', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'D-');
INSERT INTO transcript VALUES ('S00009', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00010', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00010', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00010', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'D');
INSERT INTO transcript VALUES ('S00010', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00011', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00011', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00011', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Summer', 2025, 'B-');
INSERT INTO transcript VALUES ('S00012', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00012', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00012', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00013', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'D');
INSERT INTO transcript VALUES ('S00013', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00013', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00013', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00014', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00014', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'D');
INSERT INTO transcript VALUES ('S00014', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00015', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00015', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00015', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00015', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00015', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00015', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'C-');
INSERT INTO transcript VALUES ('S00016', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00016', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00016', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'D-');
INSERT INTO transcript VALUES ('S00016', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Summer', 2025, 'C');
INSERT INTO transcript VALUES ('S00017', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00017', 'HIS-401', '1', 'Advanced History', 3, 'History', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00017', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00017', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00017', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00017', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00018', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00018', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Summer', 2025, 'B-');
INSERT INTO transcript VALUES ('S00018', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00018', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00019', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00019', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00019', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00019', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00020', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00020', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00020', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00020', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00021', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00021', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00021', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00021', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Fall', 2024, 'D+');
INSERT INTO transcript VALUES ('S00021', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00022', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00022', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00022', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'D+');
INSERT INTO transcript VALUES ('S00023', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00023', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00023', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00023', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00023', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00023', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00024', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00024', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00024', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00024', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00025', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00025', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00025', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00025', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00026', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Spring', 2025, 'F');
INSERT INTO transcript VALUES ('S00026', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00026', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00026', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00026', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00027', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00027', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00027', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00027', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00027', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00028', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00028', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00028', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00028', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00028', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00029', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00029', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00029', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00029', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00029', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00029', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00030', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00030', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Summer', 2025, 'B-');
INSERT INTO transcript VALUES ('S00030', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00030', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00030', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00030', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00031', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00031', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00031', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00032', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00032', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'D');
INSERT INTO transcript VALUES ('S00032', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00032', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00033', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00033', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00033', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00033', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00033', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00034', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00034', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00034', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'F');
INSERT INTO transcript VALUES ('S00034', 'HIS-201', '1', 'American History', 3, 'History', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00035', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00035', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00035', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00035', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'B-');
INSERT INTO transcript VALUES ('S00036', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00036', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00036', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00037', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00037', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00037', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00037', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00037', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00037', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00038', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00038', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00038', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00038', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00039', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00039', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'D+');
INSERT INTO transcript VALUES ('S00039', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00039', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00039', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00040', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00040', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00040', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00040', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00040', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00041', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'A');
INSERT INTO transcript VALUES ('S00041', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00041', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00041', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00041', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Fall', 2024, 'D+');
INSERT INTO transcript VALUES ('S00042', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00042', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00042', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00042', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00043', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00043', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00044', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00044', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00044', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00044', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00044', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00045', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00045', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00045', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00045', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00045', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00046', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'D-');
INSERT INTO transcript VALUES ('S00046', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'D');
INSERT INTO transcript VALUES ('S00046', 'BIO-401', '1', 'Advanced Biology', 3, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00046', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00047', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00047', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'F');
INSERT INTO transcript VALUES ('S00047', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00048', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'A');
INSERT INTO transcript VALUES ('S00048', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00048', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00048', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00048', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00048', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00049', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00049', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00050', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00050', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'D-');
INSERT INTO transcript VALUES ('S00050', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'D');
INSERT INTO transcript VALUES ('S00051', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00051', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00051', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Fall', 2024, 'D-');
INSERT INTO transcript VALUES ('S00051', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00051', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00052', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00052', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00052', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00052', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00053', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00053', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00053', 'HIS-401', '1', 'Advanced History', 3, 'History', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00053', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00054', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00054', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00054', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'F');
INSERT INTO transcript VALUES ('S00055', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'A');
INSERT INTO transcript VALUES ('S00055', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00055', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00055', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00055', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00056', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00056', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00056', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00056', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Summer', 2025, 'A');
INSERT INTO transcript VALUES ('S00057', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00057', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Spring', 2025, 'D');
INSERT INTO transcript VALUES ('S00057', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00057', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00058', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00058', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00058', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00058', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00058', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00058', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00059', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Summer', 2025, 'B-');
INSERT INTO transcript VALUES ('S00059', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00059', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00059', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'B-');
INSERT INTO transcript VALUES ('S00059', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00059', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00060', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00060', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00060', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00060', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00061', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00061', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00061', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00062', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00062', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00062', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00062', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00062', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00063', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00063', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00063', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00063', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00064', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00064', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00064', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00064', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00064', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00064', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00065', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00065', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00065', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00065', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00065', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00065', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00066', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00066', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00066', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00067', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00067', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00067', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00067', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00067', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00067', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00068', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00068', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00068', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00068', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Summer', 2025, 'D+');
INSERT INTO transcript VALUES ('S00069', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00069', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00069', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00069', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00070', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00070', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00070', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00070', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00070', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'F');
INSERT INTO transcript VALUES ('S00070', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00071', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00071', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00071', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00071', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00071', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00072', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Fall', 2024, 'D');
INSERT INTO transcript VALUES ('S00072', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'D');
INSERT INTO transcript VALUES ('S00072', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00072', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00073', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00073', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00073', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00073', 'HIS-401', '1', 'Advanced History', 3, 'History', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00074', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00074', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00074', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00074', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00074', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00075', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00075', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00075', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00076', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00076', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00076', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00076', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00076', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'D-');
INSERT INTO transcript VALUES ('S00077', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00077', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'D-');
INSERT INTO transcript VALUES ('S00077', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00077', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00077', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00078', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00078', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00078', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00078', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00079', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Spring', 2025, 'F');
INSERT INTO transcript VALUES ('S00079', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00080', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00080', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00080', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00080', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00081', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00081', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00081', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00081', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00081', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00082', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00082', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00082', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Fall', 2024, 'D+');
INSERT INTO transcript VALUES ('S00082', 'HIS-201', '1', 'American History', 3, 'History', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00083', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00083', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00083', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00083', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00083', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00083', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00084', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00084', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00084', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00084', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00084', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00085', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00085', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'D-');
INSERT INTO transcript VALUES ('S00085', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00085', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00086', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00086', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00086', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00086', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00087', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00087', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00087', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00087', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'A');
INSERT INTO transcript VALUES ('S00088', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'D+');
INSERT INTO transcript VALUES ('S00088', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00088', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00088', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00089', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00089', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00089', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00089', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00090', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00090', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Fall', 2024, 'D-');
INSERT INTO transcript VALUES ('S00090', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00090', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00090', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00090', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00091', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00091', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00091', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00091', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00091', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00091', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00092', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00092', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00092', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00092', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00093', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00093', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00093', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00093', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00093', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00094', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'A');
INSERT INTO transcript VALUES ('S00094', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00094', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00094', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00094', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00094', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00095', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00095', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00095', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00095', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00096', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00096', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00096', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00097', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00097', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00097', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00097', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00097', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00098', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00098', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00098', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00098', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00098', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00099', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Summer', 2025, 'D');
INSERT INTO transcript VALUES ('S00099', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00099', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00099', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00099', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00100', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00100', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00100', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00101', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'A');
INSERT INTO transcript VALUES ('S00101', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00101', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'D');
INSERT INTO transcript VALUES ('S00101', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00102', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00102', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00102', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00102', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00102', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00103', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00103', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00103', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00103', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00104', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00104', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00104', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00104', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00104', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00105', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00105', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00105', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00106', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00106', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00106', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00106', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00106', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00106', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00107', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00107', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00107', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00107', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00107', 'BIO-401', '1', 'Advanced Biology', 3, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00108', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00108', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00108', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00108', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00109', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00109', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00109', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00109', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00109', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'B-');
INSERT INTO transcript VALUES ('S00109', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00110', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00110', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00110', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00110', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00110', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00110', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00111', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00111', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00111', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00111', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'D');
INSERT INTO transcript VALUES ('S00111', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00112', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00112', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00112', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00112', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00112', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Fall', 2024, 'D+');
INSERT INTO transcript VALUES ('S00113', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Summer', 2025, 'D');
INSERT INTO transcript VALUES ('S00113', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00113', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00114', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00114', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00114', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00114', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Fall', 2024, 'D-');
INSERT INTO transcript VALUES ('S00115', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00115', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00115', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00115', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00116', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00116', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Fall', 2024, 'D-');
INSERT INTO transcript VALUES ('S00116', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00117', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00117', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00117', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00118', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00118', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00118', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00118', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00119', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00119', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00119', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00119', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00119', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00120', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00120', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00120', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00121', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00121', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00121', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'D-');
INSERT INTO transcript VALUES ('S00121', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00122', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00122', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00122', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00122', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00122', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00123', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00123', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00123', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00123', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00123', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00124', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'C');
INSERT INTO transcript VALUES ('S00124', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00124', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00124', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'D-');
INSERT INTO transcript VALUES ('S00125', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00125', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00125', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00125', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Summer', 2025, 'A');
INSERT INTO transcript VALUES ('S00125', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00125', 'HIS-201', '1', 'American History', 3, 'History', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00126', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00126', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'C');
INSERT INTO transcript VALUES ('S00126', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00127', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00127', 'HIS-201', '1', 'American History', 3, 'History', 'Spring', 2025, 'D');
INSERT INTO transcript VALUES ('S00127', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00127', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00128', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00128', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00128', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00128', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00128', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00128', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00129', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00129', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00129', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00129', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00129', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00130', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00130', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00130', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00130', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00130', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00131', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00131', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00131', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00131', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00131', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00131', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00132', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00132', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00132', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Summer', 2025, 'D+');
INSERT INTO transcript VALUES ('S00132', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00132', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Spring', 2025, 'D');
INSERT INTO transcript VALUES ('S00133', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Summer', 2025, 'B-');
INSERT INTO transcript VALUES ('S00133', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00133', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00133', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00133', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00134', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00134', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00134', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00134', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00135', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Spring', 2025, 'D-');
INSERT INTO transcript VALUES ('S00135', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00135', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00135', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00136', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00136', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00136', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00137', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00137', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00137', 'BIO-401', '1', 'Advanced Biology', 3, 'Biology', 'Spring', 2025, 'D');
INSERT INTO transcript VALUES ('S00138', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00138', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00138', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'F');
INSERT INTO transcript VALUES ('S00138', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00139', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00139', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00139', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00139', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00139', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Summer', 2025, 'B-');
INSERT INTO transcript VALUES ('S00140', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00140', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'F');
INSERT INTO transcript VALUES ('S00140', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00140', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00140', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00141', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00141', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00141', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00141', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00142', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00142', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00142', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'D-');
INSERT INTO transcript VALUES ('S00142', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00142', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00143', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00143', 'BIO-401', '1', 'Advanced Biology', 3, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00143', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00143', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00144', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00144', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00144', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00144', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00145', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00145', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00145', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00145', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00145', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00145', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00146', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00146', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00146', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Summer', 2025, 'D+');
INSERT INTO transcript VALUES ('S00146', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00146', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00147', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00147', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00147', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00148', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00148', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'D');
INSERT INTO transcript VALUES ('S00148', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00149', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Summer', 2025, 'F');
INSERT INTO transcript VALUES ('S00149', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00149', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00149', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00150', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00150', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00150', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00150', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00150', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00151', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00151', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00151', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00151', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00151', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00152', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00152', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00152', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00152', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00153', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00153', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00153', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Summer', 2025, 'C-');
INSERT INTO transcript VALUES ('S00153', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00153', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00154', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'F');
INSERT INTO transcript VALUES ('S00154', 'BIO-401', '1', 'Advanced Biology', 3, 'Biology', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00154', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00154', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00154', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'C-');
INSERT INTO transcript VALUES ('S00154', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00155', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00155', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00155', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00155', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00156', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00156', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00156', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00156', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00157', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00157', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00157', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00157', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00157', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00158', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00158', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00158', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00158', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00158', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'D+');
INSERT INTO transcript VALUES ('S00158', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00159', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00159', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00159', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00159', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00159', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'D-');
INSERT INTO transcript VALUES ('S00160', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00160', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00160', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00160', 'BIO-401', '1', 'Advanced Biology', 3, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00160', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00161', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00161', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00161', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00161', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00161', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00162', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00162', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00162', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00162', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00163', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00163', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00163', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'D-');
INSERT INTO transcript VALUES ('S00163', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00164', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00164', 'HIS-401', '1', 'Advanced History', 3, 'History', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00164', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00164', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00164', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00165', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'D+');
INSERT INTO transcript VALUES ('S00165', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00165', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00165', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00166', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00166', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00166', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00166', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00166', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00166', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00167', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00167', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00167', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00167', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00168', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00168', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00168', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00168', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00169', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00169', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00169', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00169', 'HIS-201', '1', 'American History', 3, 'History', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00169', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00170', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00170', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00170', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00170', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00171', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00171', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00171', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00171', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00171', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00171', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00172', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00172', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00172', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00173', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00173', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00173', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00173', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00173', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'F');
INSERT INTO transcript VALUES ('S00174', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00174', 'HIS-201', '1', 'American History', 3, 'History', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00174', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00174', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00175', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00175', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00175', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00175', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00175', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00175', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00176', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00176', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00176', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00176', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00176', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00177', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'B-');
INSERT INTO transcript VALUES ('S00177', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00177', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00177', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00177', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00178', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00178', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00178', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00178', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00178', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00179', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00179', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00179', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00179', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00180', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00180', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00180', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00180', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00180', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00181', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00181', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00181', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'D+');
INSERT INTO transcript VALUES ('S00181', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00182', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00182', 'HIS-401', '1', 'Advanced History', 3, 'History', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00182', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00182', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00183', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00183', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00183', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00183', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00184', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00184', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'D');
INSERT INTO transcript VALUES ('S00184', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00184', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Summer', 2025, 'A');
INSERT INTO transcript VALUES ('S00184', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00185', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00185', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00185', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00185', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00185', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00186', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00186', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00186', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00186', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Fall', 2024, 'F');
INSERT INTO transcript VALUES ('S00186', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00186', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00187', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00187', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'F');
INSERT INTO transcript VALUES ('S00187', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00187', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00187', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00188', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00188', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00188', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'D-');
INSERT INTO transcript VALUES ('S00188', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00188', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00188', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'D-');
INSERT INTO transcript VALUES ('S00189', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00189', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00189', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00189', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00190', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00190', 'BIO-401', '1', 'Advanced Biology', 3, 'Biology', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00190', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00190', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00190', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'C');
INSERT INTO transcript VALUES ('S00190', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00191', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00191', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00191', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00191', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00191', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00191', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00192', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Summer', 2025, 'C-');
INSERT INTO transcript VALUES ('S00192', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00192', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00192', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00193', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00193', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'D-');
INSERT INTO transcript VALUES ('S00193', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00193', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00193', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00194', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'F');
INSERT INTO transcript VALUES ('S00194', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00194', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Spring', 2025, 'D-');
INSERT INTO transcript VALUES ('S00194', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00194', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'F');
INSERT INTO transcript VALUES ('S00195', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00195', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00195', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00195', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'F');
INSERT INTO transcript VALUES ('S00196', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'D');
INSERT INTO transcript VALUES ('S00196', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00196', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00197', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00197', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'D');
INSERT INTO transcript VALUES ('S00197', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00198', 'BIO-401', '1', 'Advanced Biology', 3, 'Biology', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00198', 'HIS-201', '1', 'American History', 3, 'History', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00198', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00198', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00199', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00199', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Fall', 2024, 'D+');
INSERT INTO transcript VALUES ('S00199', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00199', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00200', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00200', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00200', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00200', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00200', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Summer', 2025, 'B-');
INSERT INTO transcript VALUES ('S00201', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00201', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00201', 'BIO-401', '1', 'Advanced Biology', 3, 'Biology', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00201', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00201', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Summer', 2025, 'B-');
INSERT INTO transcript VALUES ('S00201', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00202', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00202', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00202', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00202', 'HIS-201', '1', 'American History', 3, 'History', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00202', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00203', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00203', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00203', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00203', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00203', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00204', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00204', 'HIS-401', '1', 'Advanced History', 3, 'History', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00204', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00204', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00204', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00204', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'D-');
INSERT INTO transcript VALUES ('S00205', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00205', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00205', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00205', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00206', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00206', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00206', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00207', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00207', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'B-');
INSERT INTO transcript VALUES ('S00207', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00207', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00207', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00208', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00208', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Summer', 2025, 'C');
INSERT INTO transcript VALUES ('S00208', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00208', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Summer', 2025, 'B-');
INSERT INTO transcript VALUES ('S00208', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00209', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00209', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00209', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00209', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00209', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00210', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00210', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00210', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00211', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'D');
INSERT INTO transcript VALUES ('S00211', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00211', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00211', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'A');
INSERT INTO transcript VALUES ('S00211', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00211', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00212', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00212', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00212', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00212', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00212', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00212', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00213', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00213', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00213', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00213', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00213', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00214', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00214', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00214', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00214', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00214', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00215', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00215', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00215', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00216', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00216', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00216', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00216', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00217', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00217', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00217', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00218', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00218', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00218', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00218', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00218', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00219', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00219', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00219', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00219', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'D-');
INSERT INTO transcript VALUES ('S00219', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00219', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00220', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00220', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00220', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00220', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00220', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00220', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00221', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00221', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00221', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00221', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00222', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'D');
INSERT INTO transcript VALUES ('S00222', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00222', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00222', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00222', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Spring', 2025, 'D');
INSERT INTO transcript VALUES ('S00223', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00223', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00223', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00224', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00224', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00224', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00224', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00224', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00224', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00225', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00225', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00225', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00225', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00226', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00226', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00226', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00226', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00226', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Spring', 2025, 'D-');
INSERT INTO transcript VALUES ('S00227', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00227', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00227', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00227', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00227', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00228', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00228', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00228', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00228', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00228', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00229', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00229', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00229', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00229', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'F');
INSERT INTO transcript VALUES ('S00229', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00229', 'HIS-201', '1', 'American History', 3, 'History', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00230', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Summer', 2025, 'C');
INSERT INTO transcript VALUES ('S00230', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'D+');
INSERT INTO transcript VALUES ('S00230', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00230', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00231', 'HIS-201', '1', 'American History', 3, 'History', 'Spring', 2025, 'F');
INSERT INTO transcript VALUES ('S00231', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00231', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00231', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'D');
INSERT INTO transcript VALUES ('S00232', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Spring', 2025, 'D');
INSERT INTO transcript VALUES ('S00232', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00232', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00232', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00232', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00232', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Summer', 2025, 'A');
INSERT INTO transcript VALUES ('S00233', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00233', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'A');
INSERT INTO transcript VALUES ('S00233', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00233', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00234', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00234', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00234', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00234', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00235', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00235', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00235', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00235', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00236', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00236', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00236', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00236', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00236', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00237', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00237', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00237', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00237', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00237', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00238', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00238', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00238', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00238', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00239', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00239', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'D-');
INSERT INTO transcript VALUES ('S00239', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00239', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00239', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00240', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00240', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00240', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00240', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'D+');
INSERT INTO transcript VALUES ('S00241', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00241', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00241', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00241', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00241', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00242', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00242', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Summer', 2025, 'C');
INSERT INTO transcript VALUES ('S00242', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00242', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00242', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00242', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00243', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00243', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'F');
INSERT INTO transcript VALUES ('S00243', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00243', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00244', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Summer', 2025, 'D');
INSERT INTO transcript VALUES ('S00244', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00244', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00245', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00245', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00245', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Spring', 2025, 'F');
INSERT INTO transcript VALUES ('S00245', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00246', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00246', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00246', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00247', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00247', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'F');
INSERT INTO transcript VALUES ('S00247', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00247', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'F');
INSERT INTO transcript VALUES ('S00248', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00249', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00249', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00249', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00250', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00250', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00250', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00251', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'C');
INSERT INTO transcript VALUES ('S00251', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'D-');
INSERT INTO transcript VALUES ('S00251', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00252', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00252', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'D-');
INSERT INTO transcript VALUES ('S00252', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00252', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00253', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00253', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00253', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00253', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00253', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00254', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00254', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00254', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00254', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00255', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00255', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00255', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00255', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00255', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00256', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00256', 'HIS-401', '1', 'Advanced History', 3, 'History', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00257', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00257', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00257', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00258', 'BIO-401', '1', 'Advanced Biology', 3, 'Biology', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00258', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00258', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00258', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00258', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00259', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00259', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00259', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00259', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00260', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00260', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00260', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00260', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00261', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00261', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00261', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00261', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00261', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'D+');
INSERT INTO transcript VALUES ('S00262', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00262', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'F');
INSERT INTO transcript VALUES ('S00262', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00263', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00263', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00263', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00263', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00264', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00264', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00264', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00264', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00265', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00265', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00266', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00266', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00266', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00266', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00266', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00266', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00267', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00267', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00267', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00268', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'D+');
INSERT INTO transcript VALUES ('S00268', 'BIO-401', '1', 'Advanced Biology', 3, 'Biology', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00268', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00269', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Summer', 2025, 'D+');
INSERT INTO transcript VALUES ('S00269', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00269', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00269', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00269', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00269', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00270', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00270', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00270', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'C');
INSERT INTO transcript VALUES ('S00271', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00271', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'D');
INSERT INTO transcript VALUES ('S00271', 'HIS-401', '1', 'Advanced History', 3, 'History', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00271', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00272', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00272', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00272', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00272', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00273', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00273', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00273', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Summer', 2025, 'C');
INSERT INTO transcript VALUES ('S00273', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00273', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00274', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'B-');
INSERT INTO transcript VALUES ('S00274', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00274', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00275', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00275', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00275', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00275', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00276', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00276', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00277', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00277', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00277', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00277', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00278', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00278', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00278', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00278', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00278', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00279', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00279', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'D+');
INSERT INTO transcript VALUES ('S00279', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00280', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'F');
INSERT INTO transcript VALUES ('S00280', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00280', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00280', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'D-');
INSERT INTO transcript VALUES ('S00280', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00281', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00281', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00281', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00281', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00282', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'D+');
INSERT INTO transcript VALUES ('S00282', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00282', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00282', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00282', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00283', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00283', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00283', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00284', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00284', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00284', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00284', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00284', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00285', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00285', 'BIO-401', '1', 'Advanced Biology', 3, 'Biology', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00285', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00286', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'B-');
INSERT INTO transcript VALUES ('S00286', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00286', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00287', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00287', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00287', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'D+');
INSERT INTO transcript VALUES ('S00287', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00288', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00288', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00288', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00288', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00288', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00289', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00289', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00289', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00289', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00289', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00290', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00290', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00290', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00290', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Summer', 2025, 'A');
INSERT INTO transcript VALUES ('S00291', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Summer', 2025, 'B-');
INSERT INTO transcript VALUES ('S00291', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00291', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00291', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00291', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00292', 'HIS-401', '1', 'Advanced History', 3, 'History', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00292', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00292', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00292', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00292', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00292', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00293', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00293', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00293', 'HIS-401', '1', 'Advanced History', 3, 'History', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00293', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00293', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00293', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00294', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00294', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00294', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00294', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00294', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Fall', 2024, 'D-');
INSERT INTO transcript VALUES ('S00295', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00295', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00295', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00295', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00296', 'HIS-201', '1', 'American History', 3, 'History', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00296', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00296', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Summer', 2025, 'B-');
INSERT INTO transcript VALUES ('S00296', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00296', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00297', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00297', 'BIO-401', '1', 'Advanced Biology', 3, 'Biology', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00297', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Fall', 2024, 'D-');
INSERT INTO transcript VALUES ('S00297', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00298', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00298', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00298', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00298', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00298', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00298', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00299', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00299', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00299', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00299', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00300', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00300', 'HIS-401', '1', 'Advanced History', 3, 'History', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00300', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00300', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00301', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00301', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00301', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00301', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'D+');
INSERT INTO transcript VALUES ('S00302', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00302', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00302', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'C-');
INSERT INTO transcript VALUES ('S00303', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00303', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00303', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00303', 'BIO-401', '1', 'Advanced Biology', 3, 'Biology', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00303', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00304', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00304', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00304', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00304', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00305', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Spring', 2025, 'F');
INSERT INTO transcript VALUES ('S00305', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00305', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00305', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00305', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00305', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00306', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00306', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00306', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00306', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00306', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00306', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00307', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00307', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00307', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00307', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00308', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00308', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00308', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00308', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00308', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00308', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00309', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00309', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00309', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00309', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00309', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00310', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00310', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00310', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00310', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00311', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Spring', 2025, 'F');
INSERT INTO transcript VALUES ('S00311', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00311', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00312', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00312', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00312', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00312', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00313', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00313', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00313', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00313', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00313', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00313', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00314', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00314', 'BIO-401', '1', 'Advanced Biology', 3, 'Biology', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00314', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00315', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00315', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00315', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00315', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00316', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'D+');
INSERT INTO transcript VALUES ('S00316', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00316', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00316', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'D');
INSERT INTO transcript VALUES ('S00317', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00317', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00317', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00317', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00318', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00318', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Spring', 2025, 'F');
INSERT INTO transcript VALUES ('S00318', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00318', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00318', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00318', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00319', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00319', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00319', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00319', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00320', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00320', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00320', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00320', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00321', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00321', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00321', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00321', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00321', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00322', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'D');
INSERT INTO transcript VALUES ('S00322', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Summer', 2025, 'C-');
INSERT INTO transcript VALUES ('S00322', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00322', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00323', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00323', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00323', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00323', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00323', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00324', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00324', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00324', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00324', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00324', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00325', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00325', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00325', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'D');
INSERT INTO transcript VALUES ('S00325', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00326', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00326', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00326', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00326', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00327', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00327', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00327', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00327', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00327', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00327', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'F');
INSERT INTO transcript VALUES ('S00328', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00328', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00328', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'A');
INSERT INTO transcript VALUES ('S00328', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00329', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Summer', 2025, 'C-');
INSERT INTO transcript VALUES ('S00329', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00329', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00330', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00330', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00330', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00330', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00330', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Spring', 2025, 'D-');
INSERT INTO transcript VALUES ('S00331', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00331', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00331', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00331', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00331', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00332', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00332', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00332', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00333', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00333', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00333', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00333', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00334', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00334', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00334', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00334', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00335', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00335', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00335', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00335', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00335', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'D+');
INSERT INTO transcript VALUES ('S00336', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00336', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00336', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00336', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Spring', 2025, 'D');
INSERT INTO transcript VALUES ('S00337', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00337', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00337', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00337', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00338', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00338', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00338', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00338', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00338', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00338', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00339', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Summer', 2025, 'A');
INSERT INTO transcript VALUES ('S00339', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00339', 'BIO-401', '1', 'Advanced Biology', 3, 'Biology', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00339', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00339', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00340', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00340', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00340', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00341', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00341', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00341', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00341', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00341', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Fall', 2024, 'D+');
INSERT INTO transcript VALUES ('S00342', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00342', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00342', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'D-');
INSERT INTO transcript VALUES ('S00342', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00343', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00343', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00343', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'D-');
INSERT INTO transcript VALUES ('S00344', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00344', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00344', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00344', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00344', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00345', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00345', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00346', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00346', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00346', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00346', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'D+');
INSERT INTO transcript VALUES ('S00347', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00347', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00348', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00348', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00348', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00348', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00348', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'C-');
INSERT INTO transcript VALUES ('S00349', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00349', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00349', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00349', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00349', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00350', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00350', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'B-');
INSERT INTO transcript VALUES ('S00350', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00350', 'HIS-401', '1', 'Advanced History', 3, 'History', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00351', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00351', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00351', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00352', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00352', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00352', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00352', 'HIS-201', '1', 'American History', 3, 'History', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00353', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00353', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00353', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00353', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00353', 'HIS-401', '1', 'Advanced History', 3, 'History', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00354', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00354', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00354', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00354', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00354', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00355', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00355', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00355', 'HIS-401', '1', 'Advanced History', 3, 'History', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00356', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00356', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00356', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00356', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00357', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00357', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00357', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00358', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00358', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'C-');
INSERT INTO transcript VALUES ('S00358', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00358', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00358', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00359', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00359', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00359', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00359', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00359', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'F');
INSERT INTO transcript VALUES ('S00359', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00360', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00360', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00360', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00360', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00360', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00361', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00361', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00361', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00361', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'A');
INSERT INTO transcript VALUES ('S00361', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Spring', 2025, 'F');
INSERT INTO transcript VALUES ('S00361', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00362', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00362', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00362', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00362', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00363', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00363', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00363', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00363', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00364', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00364', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00364', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00364', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00364', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00364', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00365', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00365', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00365', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00365', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00366', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00366', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00366', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00366', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00367', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00367', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00367', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00367', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00367', 'HIS-401', '1', 'Advanced History', 3, 'History', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00368', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00368', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00368', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00368', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00368', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'B-');
INSERT INTO transcript VALUES ('S00369', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00369', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00369', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00369', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00369', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00370', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00370', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00370', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00370', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00370', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00370', 'HIS-201', '1', 'American History', 3, 'History', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00371', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00371', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00371', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00371', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00372', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00372', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00372', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'D-');
INSERT INTO transcript VALUES ('S00372', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00373', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00373', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00373', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00373', 'HIS-401', '1', 'Advanced History', 3, 'History', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00373', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00373', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00374', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00374', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00374', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00374', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00374', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00374', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00375', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00375', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00375', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00375', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00375', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00376', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00376', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00376', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00376', 'HIS-201', '1', 'American History', 3, 'History', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00377', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00377', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00377', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00377', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00378', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00378', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00378', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00378', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00378', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00379', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00379', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'C');
INSERT INTO transcript VALUES ('S00379', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00379', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00380', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00380', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00380', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00380', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'D');
INSERT INTO transcript VALUES ('S00381', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00381', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00381', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00381', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'D');
INSERT INTO transcript VALUES ('S00381', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00382', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00382', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00382', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00382', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00383', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00383', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00383', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00383', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00383', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00383', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00384', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00384', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00384', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00384', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00385', 'HIS-401', '1', 'Advanced History', 3, 'History', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00385', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'F');
INSERT INTO transcript VALUES ('S00385', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00385', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00385', 'BIO-401', '1', 'Advanced Biology', 3, 'Biology', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00386', 'HIS-401', '1', 'Advanced History', 3, 'History', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00386', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00386', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00387', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00387', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00387', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00387', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00388', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00388', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00388', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00389', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00389', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00389', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'D+');
INSERT INTO transcript VALUES ('S00390', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Spring', 2025, 'D');
INSERT INTO transcript VALUES ('S00390', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00390', 'HIS-401', '1', 'Advanced History', 3, 'History', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00390', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00390', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00390', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00391', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00391', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00391', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00391', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00391', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00391', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00392', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00392', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00392', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00392', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00393', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00393', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00393', 'HIS-201', '1', 'American History', 3, 'History', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00393', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00393', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00394', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Summer', 2025, 'C-');
INSERT INTO transcript VALUES ('S00394', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00394', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00395', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00395', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00395', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00395', 'HIS-201', '1', 'American History', 3, 'History', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00395', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00396', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00396', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00396', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00396', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00397', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00397', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'F');
INSERT INTO transcript VALUES ('S00397', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00397', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00398', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00398', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'A');
INSERT INTO transcript VALUES ('S00398', 'BIO-401', '1', 'Advanced Biology', 3, 'Biology', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00398', 'HIS-401', '1', 'Advanced History', 3, 'History', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00398', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00399', 'BIO-401', '1', 'Advanced Biology', 3, 'Biology', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00399', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00399', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00399', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00399', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00399', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00400', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00400', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00400', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'D-');
INSERT INTO transcript VALUES ('S00400', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'D');
INSERT INTO transcript VALUES ('S00401', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00401', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00401', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00401', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00402', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00402', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00402', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00402', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'A');
INSERT INTO transcript VALUES ('S00403', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'C');
INSERT INTO transcript VALUES ('S00403', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00404', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00404', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00404', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00404', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00404', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00405', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00405', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00405', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00405', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00405', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00406', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'D');
INSERT INTO transcript VALUES ('S00406', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00406', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00407', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00407', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'D-');
INSERT INTO transcript VALUES ('S00407', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00407', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00408', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00408', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Summer', 2025, 'D-');
INSERT INTO transcript VALUES ('S00408', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00408', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00408', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00408', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00409', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00409', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00409', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00409', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00409', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00410', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00410', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00410', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00410', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00411', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00411', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00411', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00411', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00411', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Spring', 2025, 'F');
INSERT INTO transcript VALUES ('S00411', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00412', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00412', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00412', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00412', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00413', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00413', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00413', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00413', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00413', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00414', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00414', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00414', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00414', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00414', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'D-');
INSERT INTO transcript VALUES ('S00414', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00415', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00415', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00415', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00415', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00415', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00416', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'D');
INSERT INTO transcript VALUES ('S00416', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00416', 'HIS-201', '1', 'American History', 3, 'History', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00416', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Fall', 2024, 'D-');
INSERT INTO transcript VALUES ('S00416', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'F');
INSERT INTO transcript VALUES ('S00416', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00417', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00417', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00417', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00417', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'D');
INSERT INTO transcript VALUES ('S00418', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'D+');
INSERT INTO transcript VALUES ('S00418', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00418', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00418', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00419', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00419', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'D+');
INSERT INTO transcript VALUES ('S00419', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00419', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00419', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00419', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00420', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00420', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00420', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00420', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00421', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00421', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00421', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00421', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'D');
INSERT INTO transcript VALUES ('S00421', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00421', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00422', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00422', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'D-');
INSERT INTO transcript VALUES ('S00422', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00423', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00423', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00423', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00423', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00423', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00424', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00424', 'HIS-201', '1', 'American History', 3, 'History', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00424', 'BIO-401', '1', 'Advanced Biology', 3, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00424', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00424', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Summer', 2025, 'A');
INSERT INTO transcript VALUES ('S00425', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00425', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00425', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00425', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00425', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00426', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00426', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00426', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00426', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00427', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00427', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00427', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00427', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00428', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00428', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00428', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00428', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'D');
INSERT INTO transcript VALUES ('S00429', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00429', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00429', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00429', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00429', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00429', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00430', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00430', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00430', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00430', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00430', 'HIS-401', '1', 'Advanced History', 3, 'History', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00431', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00431', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00431', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00431', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00432', 'HIS-401', '1', 'Advanced History', 3, 'History', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00432', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00432', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00432', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00433', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00433', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00433', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00433', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00433', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00434', 'HIS-201', '1', 'American History', 3, 'History', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00434', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00434', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00435', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00435', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00435', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00436', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00436', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00436', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00436', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00437', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00437', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00437', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00437', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'D+');
INSERT INTO transcript VALUES ('S00437', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00438', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00438', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00438', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00438', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00439', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00439', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00439', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'D');
INSERT INTO transcript VALUES ('S00439', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00440', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00440', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00440', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00440', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00441', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00441', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00441', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'D');
INSERT INTO transcript VALUES ('S00441', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00442', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00442', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00442', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00442', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00442', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00443', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00443', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00443', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00443', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00444', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00444', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00444', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00444', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00444', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00445', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00445', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00445', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00445', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00445', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'F');
INSERT INTO transcript VALUES ('S00446', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00446', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00446', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00447', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00447', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'D-');
INSERT INTO transcript VALUES ('S00447', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00447', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00447', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00448', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00448', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00448', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00448', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00448', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00449', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00449', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00449', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00449', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00449', 'BIO-401', '1', 'Advanced Biology', 3, 'Biology', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00449', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00450', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00450', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00450', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00450', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00451', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00451', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00451', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00451', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00451', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Spring', 2025, 'D-');
INSERT INTO transcript VALUES ('S00452', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Summer', 2025, 'A');
INSERT INTO transcript VALUES ('S00452', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00452', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00452', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00452', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00452', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00453', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00453', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00453', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00453', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00453', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00454', 'FIN-315', '1', 'Financial Analysis', 3, 'Finance', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00454', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00454', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00454', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00455', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00455', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Summer', 2025, 'B-');
INSERT INTO transcript VALUES ('S00455', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Fall', 2024, 'D-');
INSERT INTO transcript VALUES ('S00455', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00455', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00455', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00456', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00456', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00456', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00456', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00456', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00456', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00457', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00457', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00457', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00457', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00458', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Fall', 2024, 'D+');
INSERT INTO transcript VALUES ('S00458', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00458', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00458', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00459', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00459', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00459', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00459', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00459', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Summer', 2025, 'C');
INSERT INTO transcript VALUES ('S00460', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00460', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00460', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00460', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00461', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00461', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00461', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00461', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00461', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00461', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00462', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00462', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00462', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00462', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00462', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00463', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00463', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00463', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00463', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00463', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00464', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Summer', 2025, 'A');
INSERT INTO transcript VALUES ('S00464', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00465', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00465', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00465', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00465', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00466', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00466', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00466', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'A');
INSERT INTO transcript VALUES ('S00466', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'D+');
INSERT INTO transcript VALUES ('S00467', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00467', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00467', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00467', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00467', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00467', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00468', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00468', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00468', 'CS-319', '1', 'Image Processing', 3, 'Comp. Sci.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00468', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00468', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00469', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00469', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00469', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00469', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00470', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'D-');
INSERT INTO transcript VALUES ('S00470', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00470', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Summer', 2025, 'A');
INSERT INTO transcript VALUES ('S00470', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00471', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00471', 'CS-101', '1', 'Intro. to Computer Science', 4, 'Comp. Sci.', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00471', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00471', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00471', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Spring', 2025, 'D-');
INSERT INTO transcript VALUES ('S00471', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00472', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00472', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'D-');
INSERT INTO transcript VALUES ('S00472', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00472', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00473', 'HIS-201', '1', 'American History', 3, 'History', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00473', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00473', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00473', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00474', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'C');
INSERT INTO transcript VALUES ('S00474', 'FIN-201', '1', 'Investment Banking', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00474', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00474', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00475', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00475', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00475', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00475', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'B-');
INSERT INTO transcript VALUES ('S00475', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00476', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00476', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00476', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00476', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00476', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00477', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00477', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Spring', 2025, 'D');
INSERT INTO transcript VALUES ('S00477', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'C+');
INSERT INTO transcript VALUES ('S00477', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00478', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Fall', 2024, 'C');
INSERT INTO transcript VALUES ('S00478', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00478', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00478', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00479', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00479', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00479', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00479', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00480', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'F');
INSERT INTO transcript VALUES ('S00480', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00480', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'B-');
INSERT INTO transcript VALUES ('S00480', 'HIS-201', '1', 'American History', 3, 'History', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00480', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00480', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00481', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00481', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'B-');
INSERT INTO transcript VALUES ('S00481', 'MU-401', '1', 'Advanced Music', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00482', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00482', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00482', 'CS-315', '1', 'Robotics', 3, 'Comp. Sci.', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00483', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00483', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00483', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00483', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00483', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00484', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00484', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'B-');
INSERT INTO transcript VALUES ('S00484', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00484', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00485', 'PHY-201', '1', 'Physics II', 4, 'Physics', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00485', 'HIS-351', '1', 'World History', 3, 'History', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00485', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00486', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00486', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00486', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00486', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'D+');
INSERT INTO transcript VALUES ('S00487', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Spring', 2025, 'D-');
INSERT INTO transcript VALUES ('S00487', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00487', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00487', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'F');
INSERT INTO transcript VALUES ('S00487', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00487', 'HIS-101', '1', 'Intro. to History', 3, 'History', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00488', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00488', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00488', 'EE-401', '1', 'Advanced Electronics', 3, 'Elec. Eng.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00488', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00488', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'A');
INSERT INTO transcript VALUES ('S00488', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00489', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00489', 'PHY-301', '1', 'Physics III', 3, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00489', 'EE-315', '1', 'Signal Processing', 3, 'Elec. Eng.', 'Spring', 2025, 'A-');
INSERT INTO transcript VALUES ('S00489', 'HIS-351', '1', 'World History', 3, 'History', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00490', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00490', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00490', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00491', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00491', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Fall', 2024, 'F');
INSERT INTO transcript VALUES ('S00491', 'BIO-301', '1', 'Genetics', 4, 'Biology', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00491', 'EE-181', '1', 'Intro. to Digital Systems', 3, 'Elec. Eng.', 'Summer', 2025, 'B');
INSERT INTO transcript VALUES ('S00491', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00492', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00492', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00492', 'MU-301', '1', 'Music Composition', 3, 'Music', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00493', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00493', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00493', 'FIN-401', '1', 'Advanced Finance', 3, 'Finance', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00493', 'HIS-301', '1', 'European History', 3, 'History', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00494', 'HIS-201', '1', 'American History', 3, 'History', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00494', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Spring', 2025, 'D');
INSERT INTO transcript VALUES ('S00494', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00494', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00495', 'BIO-101', '1', 'Intro. to Biology', 4, 'Biology', 'Spring', 2025, 'B-');
INSERT INTO transcript VALUES ('S00495', 'BIO-401', '1', 'Advanced Biology', 3, 'Biology', 'Spring', 2025, 'C-');
INSERT INTO transcript VALUES ('S00495', 'EE-301', '1', 'Circuits II', 3, 'Elec. Eng.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00495', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'F');
INSERT INTO transcript VALUES ('S00495', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00496', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00496', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Summer', 2025, 'B-');
INSERT INTO transcript VALUES ('S00496', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00496', 'BIO-401', '1', 'Advanced Biology', 3, 'Biology', 'Spring', 2025, 'C');
INSERT INTO transcript VALUES ('S00496', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00496', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00497', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00497', 'MU-201', '1', 'Music Theory', 3, 'Music', 'Spring', 2025, 'B');
INSERT INTO transcript VALUES ('S00497', 'HIS-301', '1', 'European History', 3, 'History', 'Fall', 2024, 'C-');
INSERT INTO transcript VALUES ('S00497', 'FIN-101', '1', 'Intro. to Finance', 3, 'Finance', 'Spring', 2025, 'F');
INSERT INTO transcript VALUES ('S00497', 'BIO-399', '1', 'Computational Biology', 3, 'Biology', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00497', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00498', 'EE-201', '1', 'Circuits I', 3, 'Elec. Eng.', 'Fall', 2024, 'F');
INSERT INTO transcript VALUES ('S00498', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'B+');
INSERT INTO transcript VALUES ('S00498', 'BIO-201', '1', 'Biology II', 4, 'Biology', 'Fall', 2024, 'A-');
INSERT INTO transcript VALUES ('S00498', 'FIN-301', '1', 'Corporate Finance', 3, 'Finance', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00499', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00499', 'PHY-401', '1', 'Physics Seminar', 3, 'Physics', 'Spring', 2025, 'A');
INSERT INTO transcript VALUES ('S00499', 'PHY-315', '1', 'Advanced Physics', 3, 'Physics', 'Fall', 2024, 'B');
INSERT INTO transcript VALUES ('S00499', 'CS-190', '1', 'Game Design', 4, 'Comp. Sci.', 'Summer', 2025, 'B+');
INSERT INTO transcript VALUES ('S00499', 'PHY-101', '1', 'Physical Principles', 4, 'Physics', 'Fall', 2024, 'B-');
INSERT INTO transcript VALUES ('S00499', 'HIS-201', '1', 'American History', 3, 'History', 'Fall', 2024, 'C+');
INSERT INTO transcript VALUES ('S00500', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Spring', 2025, 'C+');
INSERT INTO transcript VALUES ('S00500', 'MU-199', '1', 'Music Video Production', 3, 'Music', 'Summer', 2025, 'A-');
INSERT INTO transcript VALUES ('S00500', 'CS-347', '1', 'Database System Concepts', 3, 'Comp. Sci.', 'Spring', 2025, 'B+');
INSERT INTO transcript VALUES ('S00500', 'MU-101', '1', 'Intro. to Music', 3, 'Music', 'Spring', 2025, 'B-');

-- Test Logins
INSERT INTO admin VALUES('A03','Test','Admin');
INSERT INTO login VALUES('A03','testadmin',SHA2('password123',256),'admin');

INSERT INTO instructor VALUES ('I00029', 'Test', 'Instructor', 'Comp. Sci.', 60000);
INSERT INTO login VALUES ('I00029', 'testinstructor', SHA2('instructor123', 256), 'instructor');

INSERT INTO student VALUES ('S00501', 'Test', 'Student', 'Comp. Sci.', 'I00029');
INSERT INTO login VALUES ('S00501', 'teststudent', SHA2('student123', 256), 'student');

-- update student with username gholmes and bjackson so i can test schedule page and transcript
UPDATE login SET password = SHA2('test123', 256) WHERE user_id = 'S00004';

UPDATE login SET password = SHA2('test123', 256) WHERE user_id = 'S00054';


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
        COUNT(takes.ID) as enrolled_students,
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


-- Spring 2026
INSERT INTO section VALUES ('BIO-101', '1', 'Spring', 2026, 'Smith', '201', 'F');
INSERT INTO section VALUES ('BIO-201', '1', 'Spring', 2026, 'Smith', '301', 'G');
INSERT INTO section VALUES ('BIO-301', '1', 'Spring', 2026, 'Cunningham', '401', 'D');
INSERT INTO section VALUES ('BIO-399', '1', 'Spring', 2026, 'ISB', '201', 'F');
INSERT INTO section VALUES ('BIO-401', '1', 'Spring', 2026, 'Smith', '101', 'I');
INSERT INTO section VALUES ('CS-101', '1', 'Spring', 2026, 'McGilvrey', '401', 'H');
INSERT INTO section VALUES ('CS-190', '1', 'Spring', 2026, 'McGilvrey', '101', 'J');
INSERT INTO section VALUES ('CS-315', '1', 'Spring', 2026, 'Merrill', '201', 'D');
INSERT INTO section VALUES ('CS-319', '1', 'Spring', 2026, 'MSB', '101', 'D');
INSERT INTO section VALUES ('CS-347', '1', 'Spring', 2026, 'Merrill', '101', 'B');
INSERT INTO section VALUES ('EE-181', '1', 'Spring', 2026, 'ISB', '201', 'H');
INSERT INTO section VALUES ('EE-201', '1', 'Spring', 2026, 'McGilvrey', '401', 'F');
INSERT INTO section VALUES ('EE-301', '1', 'Spring', 2026, 'Bowman', '301', 'I');
INSERT INTO section VALUES ('EE-315', '1', 'Spring', 2026, 'ISB', '101', 'I');
INSERT INTO section VALUES ('EE-401', '1', 'Spring', 2026, 'MSB', '101', 'D');
INSERT INTO section VALUES ('FIN-101', '1', 'Spring', 2026, 'McGilvrey', '401', 'I');
INSERT INTO section VALUES ('FIN-201', '1', 'Spring', 2026, 'Merrill', '201', 'B');
INSERT INTO section VALUES ('FIN-301', '1', 'Spring', 2026, 'McGilvrey', '201', 'D');
INSERT INTO section VALUES ('FIN-315', '1', 'Spring', 2026, 'Lowry', '401', 'G');
INSERT INTO section VALUES ('FIN-401', '1', 'Spring', 2026, 'Satterfield', '101', 'F');
INSERT INTO section VALUES ('HIS-101', '1', 'Spring', 2026, 'Ritchie', '401', 'J');
INSERT INTO section VALUES ('HIS-201', '1', 'Spring', 2026, 'Lowry', '201', 'C');
INSERT INTO section VALUES ('HIS-301', '1', 'Spring', 2026, 'ISB', '101', 'G');
INSERT INTO section VALUES ('HIS-351', '1', 'Spring', 2026, 'Merrill', '101', 'H');
INSERT INTO section VALUES ('HIS-401', '1', 'Spring', 2026, 'Bowman', '401', 'H');
INSERT INTO section VALUES ('MU-101', '1', 'Spring', 2026, 'Merrill', '101', 'G');
INSERT INTO section VALUES ('MU-199', '1', 'Spring', 2026, 'Lowry', '401', 'D');
INSERT INTO section VALUES ('MU-201', '1', 'Spring', 2026, 'Cunningham', '301', 'H');
INSERT INTO section VALUES ('MU-301', '1', 'Spring', 2026, 'ISB', '301', 'B');
INSERT INTO section VALUES ('MU-401', '1', 'Spring', 2026, 'Smith', '101', 'J');
INSERT INTO section VALUES ('PHY-101', '1', 'Spring', 2026, 'McGilvrey', '401', 'J');
INSERT INTO section VALUES ('PHY-201', '1', 'Spring', 2026, 'Bowman', '101', 'C');
INSERT INTO section VALUES ('PHY-301', '1', 'Spring', 2026, 'MSB', '301', 'F');
INSERT INTO section VALUES ('PHY-315', '1', 'Spring', 2026, 'Cunningham', '201', 'E');
INSERT INTO section VALUES ('PHY-401', '1', 'Spring', 2026, 'ISB', '301', 'F');

-- Summer 2026
INSERT INTO section VALUES ('BIO-101', '1', 'Summer', 2026, 'MSB', '301', 'E');
INSERT INTO section VALUES ('CS-101', '1', 'Summer', 2026, 'Satterfield', '201', 'G');
INSERT INTO section VALUES ('CS-190', '1', 'Summer', 2026, 'Bowman', '201', 'B');
INSERT INTO section VALUES ('EE-181', '1', 'Summer', 2026, 'Smith', '201', 'E');
INSERT INTO section VALUES ('FIN-101', '1', 'Summer', 2026, 'Ritchie', '201', 'G');
INSERT INTO section VALUES ('HIS-101', '1', 'Summer', 2026, 'ISB', '401', 'H');
INSERT INTO section VALUES ('MU-101', '1', 'Summer', 2026, 'Lowry', '201', 'D');
INSERT INTO section VALUES ('MU-199', '1', 'Summer', 2026, 'Bowman', '401', 'D');
INSERT INTO section VALUES ('PHY-101', '1', 'Summer', 2026, 'Ritchie', '101', 'D');

-- Fall 2026
INSERT INTO section VALUES ('BIO-101', '1', 'Fall', 2026, 'ISB', '201', 'C');
INSERT INTO section VALUES ('BIO-201', '1', 'Fall', 2026, 'Merrill', '101', 'B');
INSERT INTO section VALUES ('BIO-301', '1', 'Fall', 2026, 'Bowman', '101', 'I');
INSERT INTO section VALUES ('BIO-399', '1', 'Fall', 2026, 'Merrill', '301', 'A');
INSERT INTO section VALUES ('CS-101', '1', 'Fall', 2026, 'Cunningham', '201', 'G');
INSERT INTO section VALUES ('CS-190', '1', 'Fall', 2026, 'ISB', '101', 'H');
INSERT INTO section VALUES ('CS-315', '1', 'Fall', 2026, 'Lowry', '201', 'B');
INSERT INTO section VALUES ('CS-319', '1', 'Fall', 2026, 'McGilvrey', '201', 'B');
INSERT INTO section VALUES ('CS-347', '1', 'Fall', 2026, 'Lowry', '301', 'B');
INSERT INTO section VALUES ('EE-181', '1', 'Fall', 2026, 'Williams', '201', 'D');
INSERT INTO section VALUES ('EE-201', '1', 'Fall', 2026, 'Bowman', '201', 'F');
INSERT INTO section VALUES ('EE-301', '1', 'Fall', 2026, 'ISB', '401', 'F');
INSERT INTO section VALUES ('EE-315', '1', 'Fall', 2026, 'McGilvrey', '401', 'D');
INSERT INTO section VALUES ('FIN-101', '1', 'Fall', 2026, 'Satterfield', '101', 'B');
INSERT INTO section VALUES ('FIN-201', '1', 'Fall', 2026, 'Cunningham', '301', 'D');
INSERT INTO section VALUES ('FIN-301', '1', 'Fall', 2026, 'Satterfield', '201', 'J');
INSERT INTO section VALUES ('FIN-315', '1', 'Fall', 2026, 'MSB', '101', 'G');
INSERT INTO section VALUES ('HIS-101', '1', 'Fall', 2026, 'Bowman', '401', 'A');
INSERT INTO section VALUES ('HIS-201', '1', 'Fall', 2026, 'McGilvrey', '101', 'F');
INSERT INTO section VALUES ('HIS-301', '1', 'Fall', 2026, 'ISB', '101', 'D');
INSERT INTO section VALUES ('HIS-351', '1', 'Fall', 2026, 'Smith', '101', 'C');
INSERT INTO section VALUES ('MU-101', '1', 'Fall', 2026, 'MSB', '201', 'E');
INSERT INTO section VALUES ('MU-199', '1', 'Fall', 2026, 'MSB', '401', 'A');
INSERT INTO section VALUES ('MU-201', '1', 'Fall', 2026, 'Cunningham', '301', 'E');
INSERT INTO section VALUES ('MU-301', '1', 'Fall', 2026, 'Bowman', '101', 'A');
INSERT INTO section VALUES ('PHY-101', '1', 'Fall', 2026, 'Smith', '201', 'B');
INSERT INTO section VALUES ('PHY-201', '1', 'Fall', 2026, 'Merrill', '301', 'G');
INSERT INTO section VALUES ('PHY-301', '1', 'Fall', 2026, 'Satterfield', '301', 'B');
INSERT INTO section VALUES ('PHY-315', '1', 'Fall', 2026, 'Smith', '401', 'A');