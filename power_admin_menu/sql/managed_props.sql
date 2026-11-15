-- Run once on existing Power Admin Menu installations.
CREATE TABLE IF NOT EXISTS `pam_managed_props` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `model` VARCHAR(64) NOT NULL,
  `coords` JSON NOT NULL,
  `rotation` JSON NOT NULL,
  `created_by` VARCHAR(100) NOT NULL DEFAULT 'Unknown',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_pam_managed_props_model` (`model`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
