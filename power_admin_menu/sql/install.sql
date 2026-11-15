-- Power Admin Menu fresh-install schema (Phase 1 + Phase 2).
-- Existing installations should run phase2_upgrade.sql instead of dropping/recreating tables.
CREATE TABLE IF NOT EXISTS `pam_audit_logs` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `actor_identifier` VARCHAR(120) NOT NULL,
  `actor_name` VARCHAR(100) NOT NULL,
  `action` VARCHAR(100) NOT NULL,
  `target_identifier` VARCHAR(120) NULL,
  `target_name` VARCHAR(100) NULL,
  `details` LONGTEXT NULL,
  `success` TINYINT(1) NOT NULL DEFAULT 0,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `idx_actor_identifier` (`actor_identifier`),
  KEY `idx_target_identifier` (`target_identifier`), KEY `idx_action` (`action`), KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pam_bans` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_identifier` VARCHAR(120) NOT NULL,
  `player_name` VARCHAR(100) NULL,
  `reason` VARCHAR(250) NOT NULL,
  `staff_identifier` VARCHAR(120) NOT NULL,
  `staff_name` VARCHAR(100) NULL,
  `expires_at` DATETIME NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  `active` TINYINT(1) NOT NULL DEFAULT 1,
  `revoked_at` DATETIME NULL,
  `revoked_by` VARCHAR(120) NULL,
  PRIMARY KEY (`id`), KEY `idx_player_identifier` (`player_identifier`), KEY `idx_active_expires` (`active`, `expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pam_ban_identifiers` (
  `ban_id` BIGINT UNSIGNED NOT NULL,
  `identifier` VARCHAR(120) NOT NULL,
  PRIMARY KEY (`ban_id`, `identifier`), KEY `idx_identifier` (`identifier`),
  CONSTRAINT `fk_pam_ban_identifier` FOREIGN KEY (`ban_id`) REFERENCES `pam_bans` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pam_staff_notes` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_identifier` VARCHAR(120) NOT NULL,
  `staff_identifier` VARCHAR(120) NOT NULL,
  `staff_name` VARCHAR(100) NULL,
  `note` TEXT NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `idx_player_identifier` (`player_identifier`), KEY `idx_staff_identifier` (`staff_identifier`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pam_warnings` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_identifier` VARCHAR(120) NOT NULL,
  `player_name` VARCHAR(100) NOT NULL,
  `staff_identifier` VARCHAR(120) NOT NULL,
  `staff_name` VARCHAR(100) NOT NULL,
  `reason` VARCHAR(250) NOT NULL,
  `created_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`), KEY `idx_player_identifier` (`player_identifier`), KEY `idx_created_at` (`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pam_money_transactions` (
  `id` BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `player_identifier` VARCHAR(120) NOT NULL,
  `player_name` VARCHAR(100) NOT NULL,
  `staff_identifier` VARCHAR(120) NOT NULL,
  `staff_name` VARCHAR(100) NOT NULL,
  `account` ENUM('cash','bank') NOT NULL,
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
