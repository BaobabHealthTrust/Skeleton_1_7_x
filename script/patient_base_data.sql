/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;


/* Update users */
INSERT INTO openmrs_b2.users (user_id, username, password, salt, secret_answer, secret_question, creator, retired, retired_by, retire_reason, date_retired, date_created, uuid)
SELECT user_id, username, password, salt, secret_answer, secret_question, 1 AS creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid FROM openmrs_bart1.users WHERE user_id > 1;

UPDATE openmrs_bart1.role SET role = "Provider" WHERE role = "provider";
UPDATE openmrs_bart1.role SET role = "Superuser" WHERE role = "superuser";

DELETE FROM openmrs_b2.user_role;
INSERT INTO openmrs_b2.user_role (user_id, role)
SELECT ur.user_id, r.role FROM openmrs_bart1.user_role ur LEFT JOIN openmrs_bart1.role r ON ur.role_id = r.role_id WHERE ur.user_id IN (SELECT user_id FROM openmrs_bart1.users) AND r.role NOT IN ('Data Entry Clerk') ;

INSERT INTO openmrs_b2.user_role (user_id, role)
SELECT ur.user_id, 'Data Assistant' FROM openmrs_bart1.user_role ur LEFT JOIN openmrs_bart1.role r ON ur.role_id = r.role_id WHERE ur.user_id IN (SELECT user_id FROM openmrs_bart1.users) AND r.role IN ("Data Entry Clerk") ;

/* Update locations 
DELETE FROM openmrs_b2.location_tag_map;
DELETE FROM openmrs_b2.location;

INSERT INTO openmrs_b2.location (location_id, name, description, address1, address2, city_village, country, postal_code, creator, date_created, uuid)
SELECT location_id, name, description, address1, address2, city_village, country, postal_code, creator, date_created, (SELECT UUID()) AS uuid FROM openmrs_bart1.location WHERE location_id < 1000;

INSERT INTO openmrs_b2.location (name, description, creator, date_created, uuid)
	VALUES ('Registration', 'Workstation Location', 1, (NOW()), (SELECT UUID())),
	('Vitals', 'Workstation Location', 1, (NOW()), (SELECT UUID())),
	('Outpatient', 'Workstation Location', 1, (NOW()), (SELECT UUID())),
	('HIV Reception', 'Workstation Location', 1, (NOW()), (SELECT UUID())),
	('HIV Clinician Station', 'Workstation Location', 1, (NOW()), (SELECT UUID())),
	('HIV Nurse Station', 'Workstation Location', 1, (NOW()), (SELECT UUID())),
	('Chronic Cough', 'Workstation Location', 1, (NOW()), (SELECT UUID())),
	('TB Reception', 'Workstation Location', 1, (NOW()), (SELECT UUID())),
	('TB Sputum Submission Station', 'Workstation Location', 1, (NOW()), (SELECT UUID()));

INSERT INTO `location_tag_map` (`location_id`, `location_tag_id`) VALUES
	((SELECT location_id FROM location WHERE name = 'Registration'),(SELECT location_tag_id FROM location_tag WHERE name = "Workstation Location") );
INSERT INTO `location_tag_map` (`location_id`, `location_tag_id`) VALUES
	((SELECT location_id FROM location WHERE name = 'Vitals'),(SELECT location_tag_id FROM location_tag WHERE name = "Workstation Location") );
INSERT INTO `location_tag_map` (`location_id`, `location_tag_id`) VALUES
	((SELECT location_id FROM location WHERE name = 'Outpatient'),(SELECT location_tag_id FROM location_tag WHERE name = "Workstation Location") );
INSERT INTO `location_tag_map` (`location_id`, `location_tag_id`) VALUES
	((SELECT location_id FROM location WHERE name = 'HIV Reception'),(SELECT location_tag_id FROM location_tag WHERE name = "Workstation Location") );
INSERT INTO `location_tag_map` (`location_id`, `location_tag_id`) VALUES
	((SELECT location_id FROM location WHERE name = 'HIV Clinician Station'),(SELECT location_tag_id FROM location_tag WHERE name = "Workstation Location") );
INSERT INTO `location_tag_map` (`location_id`, `location_tag_id`) VALUES
	((SELECT location_id FROM location WHERE name = 'HIV Nurse Station'),(SELECT location_tag_id FROM location_tag WHERE name = "Workstation Location") );
INSERT INTO `location_tag_map` (`location_id`, `location_tag_id`) VALUES
	((SELECT location_id FROM location WHERE name = 'Chronic Cough'),(SELECT location_tag_id FROM location_tag WHERE name = "Workstation Location") );
INSERT INTO `location_tag_map` (`location_id`, `location_tag_id`) VALUES
	((SELECT location_id FROM location WHERE name = 'TB Reception'),(SELECT location_tag_id FROM location_tag WHERE name = "Workstation Location") );
INSERT INTO `location_tag_map` (`location_id`, `location_tag_id`) VALUES
	((SELECT location_id FROM location WHERE name = 'TB Sputum Submission Station'),(SELECT location_tag_id FROM location_tag WHERE name = "Workstation Location") );
*/
INSERT INTO openmrs_b2.location (location_id, name, description, address1, address2, city_village, country, postal_code, creator, date_created, uuid)
SELECT location_id, name, description, address1, address2, city_village, country, postal_code, creator, date_created, (SELECT UUID()) AS uuid FROM openmrs_bart1.location WHERE location_id > 999;

/* Update patient and person details */
INSERT INTO openmrs_b2.person (person_id, birthdate, birthdate_estimated, gender, death_date, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT patient_id, birthdate, birthdate_estimated, gender, death_date, creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid FROM openmrs_bart1.patient;

UPDATE openmrs_b2.person SET gender = LEFT(RTRIM(LTRIM(gender)), 1);

INSERT INTO openmrs_b2.patient (patient_id, creator, voided, voided_by, void_reason, date_voided, date_created)
SELECT patient_id, creator, voided, voided_by, void_reason, date_voided, date_created FROM openmrs_bart1.patient;

/* Update patient person addresses */
INSERT INTO openmrs_b2.person_address (person_id, city_village, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT patient_id, city_village, creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid FROM openmrs_bart1.patient_address;

/* Update patient identifiers and attributes */
INSERT INTO openmrs_b2.patient_identifier (patient_id, identifier_type, preferred, location_id, identifier, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT patient_id, 3 AS identifier_type, preferred, location_id, identifier, creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid FROM openmrs_bart1.patient_identifier WHERE identifier_type = 1;

INSERT INTO openmrs_b2.patient_identifier (patient_id, identifier_type, preferred, location_id, identifier, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT patient_id, 17 AS identifier_type, preferred, location_id, identifier, creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid FROM openmrs_bart1.patient_identifier WHERE identifier_type = 10;

INSERT INTO openmrs_b2.patient_identifier (patient_id, identifier_type, preferred, location_id, identifier, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT patient_id, 4 AS identifier_type, preferred, location_id, identifier, creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid FROM openmrs_bart1.patient_identifier WHERE identifier_type = 18;

INSERT INTO openmrs_b2.patient_identifier (patient_id, identifier_type, preferred, location_id, identifier, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT patient_id, 18 AS identifier_type, preferred, location_id, identifier, creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid FROM openmrs_bart1.patient_identifier WHERE identifier_type = 19;

INSERT INTO openmrs_b2.person_attribute (person_id, person_attribute_type_id, value, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT patient_id, 13 AS identifier_type, identifier, creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid FROM openmrs_bart1.patient_identifier WHERE identifier_type = 3;

INSERT INTO openmrs_b2.person_attribute (person_id, person_attribute_type_id, value, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT patient_id, 12 AS identifier_type, identifier, creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid FROM openmrs_bart1.patient_identifier WHERE identifier_type = 5;

INSERT INTO openmrs_b2.person_attribute (person_id, person_attribute_type_id, value, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT patient_id, 14 AS identifier_type, identifier, creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid FROM openmrs_bart1.patient_identifier WHERE identifier_type = 11;

INSERT INTO openmrs_b2.person_attribute (person_id, person_attribute_type_id, value, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT patient_id, 15 AS identifier_type, identifier, creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid FROM openmrs_bart1.patient_identifier WHERE identifier_type = 12;

/* Update patient person names */
INSERT INTO openmrs_b2.person_name (person_id, middle_name, given_name, family_name, preferred, prefix, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT patient_id, middle_name, given_name, family_name, preferred, prefix, creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid FROM openmrs_bart1.patient_name;

/* Update users persons */
SET @'max_person_id' = (SELECT MAX(person_id) FROM openmrs_b2.person);

INSERT INTO openmrs_b2.person (person_id, birthdate, birthdate_estimated, gender, death_date, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT (user_id + @'max_person_id') AS user_id, NOW(), 0, 'M', NULL, creator, retired, retired_by, retire_reason, date_retired, date_created, (SELECT UUID()) AS uuid FROM openmrs_b2.users;

UPDATE openmrs_b2.users SET person_id = user_id + @'max_person_id';
 
INSERT INTO openmrs_b2.person_name (person_id, middle_name, given_name, family_name, preferred, prefix, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT person_id, username, username, username,  1, NULL, creator, retired, retired_by, retire_reason, date_retired, date_created, (SELECT UUID()) AS uuid FROM openmrs_b2.users;

/* Update patient programs */
INSERT INTO openmrs_b2.patient_program (patient_program_id, patient_id, program_id, date_enrolled, date_completed, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT patient_program_id, patient_id, program_id, date_enrolled, date_completed, creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid FROM openmrs_bart1.patient_program WHERE patient_id IN (SELECT patient_id FROM openmrs_bart1.patient);

UPDATE openmrs_b2.patient_program program SET program.date_enrolled = IFNULL((SELECT dates.start_date FROM openmrs_bart1.patient_start_dates dates WHERE program.patient_id = dates.patient_id), program.date_created);

INSERT INTO openmrs_b2.patient_state (patient_program_id, state, start_date, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT patient_program_id, 1, date_enrolled, creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid FROM openmrs_b2.patient_program WHERE program_id = 1;

INSERT INTO openmrs_b2.patient_state (patient_program_id, state, start_date, creator, voided, voided_by, void_reason, date_voided, date_created, uuid)
SELECT patient_program_id, 18, date_enrolled, creator, voided, voided_by, void_reason, date_voided, date_created, (SELECT UUID()) AS uuid FROM openmrs_b2.patient_program WHERE program_id = 2;


INSERT INTO openmrs_b2.relationship (person_a, relationship, person_b, creator, date_created, voided, voided_by, date_voided, void_reason, uuid)
SELECT p1.patient_id, 13, p2.patient_id, creator, date_created, voided, voided_by, date_voided, void_reason, (SELECT UUID()) AS uuid FROM openmrs_bart1.relationship rel LEFT JOIN openmrs_bart1.person p1 ON rel.person_id = p1.person_id LEFT JOIN openmrs_bart1.person p2 ON rel.relative_id = p2.person_id;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

