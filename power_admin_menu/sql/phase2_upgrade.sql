-- Power Admin Menu Phase 2 additive migration for existing Phase 1 databases.
-- Run this in the same database used by oxmysql. Safe to re-run.

CREATE TABLE IF NOT EXISTS `pam_ban_identifiers` (
  `ban_id` BIGINT UNSIGNED NOT NULL,
  `identifier` VARCHAR(120) NOT NULL,
  PRIMARY KEY (`ban_id`, `identifier`),
  KEY `idx_identifier` (`identifier`),
  CONSTRAINT `fk_pam_ban_identifier` FOREIGN KEY (`ban_id`) REFERENCES `pam_bans` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pam_warnings` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_identifier` VARCHAR(120) NOT NULL,
  `player_name` VARCHAR(100) NULL,
  `staff_identifier` VARCHAR(120) NOT NULL,
  `staff_name` VARCHAR(100) NULL,
  `reason` VARCHAR(250) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `idx_player_identifier` (`player_identifier`), KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pam_money_transactions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_identifier` VARCHAR(120) NOT NULL,
  `player_name` VARCHAR(100) NULL,
  `staff_identifier` VARCHAR(120) NOT NULL,
  `staff_name` VARCHAR(100) NULL,
  `account` VARCHAR(20) NOT NULL,
  `amount` BIGINT NOT NULL,
  `reason` VARCHAR(250) NOT NULL,
  `status` ENUM('pending','success','failed') NOT NULL DEFAULT 'pending',
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `idx_player_identifier` (`player_identifier`), KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pam_player_activity` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_identifier` VARCHAR(120) NOT NULL,
  `event_type` VARCHAR(80) NOT NULL,
  `details` LONGTEXT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `idx_player_identifier` (`player_identifier`), KEY `idx_event_type` (`event_type`), KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET @pam_schema = DATABASE();

SET @pam_sql = IF((SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA=@pam_schema AND TABLE_NAME='pam_bans' AND COLUMN_NAME='staff_name')=0,
  'ALTER TABLE `pam_bans` ADD COLUMN `staff_name` VARCHAR(100) NULL AFTER `staff_identifier`', 'SELECT 1');
PREPARE pam_stmt FROM @pam_sql; EXECUTE pam_stmt; DEALLOCATE PREPARE pam_stmt;

SET @pam_sql = IF((SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA=@pam_schema AND TABLE_NAME='pam_bans' AND COLUMN_NAME='revoked_at')=0,
  'ALTER TABLE `pam_bans` ADD COLUMN `revoked_at` DATETIME NULL', 'SELECT 1');
PREPARE pam_stmt FROM @pam_sql; EXECUTE pam_stmt; DEALLOCATE PREPARE pam_stmt;

SET @pam_sql = IF((SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA=@pam_schema AND TABLE_NAME='pam_bans' AND COLUMN_NAME='revoked_by')=0,
  'ALTER TABLE `pam_bans` ADD COLUMN `revoked_by` VARCHAR(120) NULL', 'SELECT 1');
PREPARE pam_stmt FROM @pam_sql; EXECUTE pam_stmt; DEALLOCATE PREPARE pam_stmt;

SET @pam_sql = IF((SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA=@pam_schema AND TABLE_NAME='pam_staff_notes' AND COLUMN_NAME='staff_name')=0,
  'ALTER TABLE `pam_staff_notes` ADD COLUMN `staff_name` VARCHAR(100) NULL AFTER `staff_identifier`', 'SELECT 1');
PREPARE pam_stmt FROM @pam_sql; EXECUTE pam_stmt; DEALLOCATE PREPARE pam_stmt;


SET @pam_has_money_status = (SELECT COUNT(*) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA=@pam_schema AND TABLE_NAME='pam_money_transactions' AND COLUMN_NAME='status');
SET @pam_sql = IF(@pam_has_money_status=0, 'ALTER TABLE `pam_money_transactions` ADD COLUMN `status` ENUM(''pending'',''success'',''failed'') NOT NULL DEFAULT ''pending'' AFTER `reason`', 'SELECT 1');
PREPARE pam_stmt FROM @pam_sql; EXECUTE pam_stmt; DEALLOCATE PREPARE pam_stmt;
