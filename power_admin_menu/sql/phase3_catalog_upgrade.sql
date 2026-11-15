-- Phase 3: persistent dynamic item/job definitions. Safe to run more than once.
CREATE TABLE IF NOT EXISTS `pam_dynamic_definitions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `definition_type` ENUM('item','job') NOT NULL,
  `definition_name` VARCHAR(64) NOT NULL,
  `definition_json` LONGTEXT NOT NULL,
  `created_by` VARCHAR(120) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_pam_definition` (`definition_type`, `definition_name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
