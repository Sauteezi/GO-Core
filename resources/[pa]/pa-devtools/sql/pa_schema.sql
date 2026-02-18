-- Port Aurora base schema (MariaDB/MySQL)
-- Target scale: up to 128 concurrent players.
-- Apply manually in production. Use pa-devtools safe apply only for local/dev bootstrap.

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

CREATE TABLE IF NOT EXISTS characters (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    license VARCHAR(64) NOT NULL,
    citizen_id VARCHAR(32) NOT NULL,
    first_name VARCHAR(64) NOT NULL,
    last_name VARCHAR(64) NOT NULL,
    date_of_birth DATE NULL,
    active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_characters_citizen_id (citizen_id),
    KEY idx_characters_license (license),
    KEY idx_characters_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS character_profiles (
    char_id BIGINT UNSIGNED NOT NULL,
    phone_number VARCHAR(32) NULL,
    profile_photo_url VARCHAR(255) NULL,
    bio TEXT NULL,
    pronouns VARCHAR(32) NULL,
    emergency_contact VARCHAR(128) NULL,
    licenses_json JSON NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (char_id),
    CONSTRAINT fk_character_profiles_char FOREIGN KEY (char_id) REFERENCES characters(id) ON DELETE CASCADE,
    KEY idx_character_profiles_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS accounts (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    char_id BIGINT UNSIGNED NOT NULL,
    account_type ENUM('cash','bank','dirty','business','society') NOT NULL DEFAULT 'bank',
    balance BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_accounts_char FOREIGN KEY (char_id) REFERENCES characters(id) ON DELETE CASCADE,
    UNIQUE KEY uq_accounts_char_type (char_id, account_type),
    KEY idx_accounts_char_id (char_id),
    KEY idx_accounts_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS transactions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    account_id BIGINT UNSIGNED NOT NULL,
    char_id BIGINT UNSIGNED NULL,
    txn_type VARCHAR(32) NOT NULL,
    amount BIGINT NOT NULL,
    direction ENUM('credit','debit') NOT NULL,
    reference VARCHAR(128) NULL,
    metadata JSON NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_transactions_account FOREIGN KEY (account_id) REFERENCES accounts(id) ON DELETE CASCADE,
    CONSTRAINT fk_transactions_char FOREIGN KEY (char_id) REFERENCES characters(id) ON DELETE SET NULL,
    KEY idx_transactions_account_id (account_id),
    KEY idx_transactions_char_id (char_id),
    KEY idx_transactions_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;



CREATE TABLE IF NOT EXISTS logs (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    level VARCHAR(32) NOT NULL,
    resource VARCHAR(64) NOT NULL,
    message TEXT NOT NULL,
    meta JSON NULL,
    correlation_id VARCHAR(64) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_logs_level (level),
    KEY idx_logs_resource (resource),
    KEY idx_logs_correlation_id (correlation_id),
    KEY idx_logs_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS staff_roles (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    license VARCHAR(64) NOT NULL,
    role_name VARCHAR(64) NOT NULL,
    granted_by VARCHAR(64) NULL,
    notes VARCHAR(255) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_staff_roles_license_role (license, role_name),
    KEY idx_staff_roles_license (license),
    KEY idx_staff_roles_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS bans (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    license VARCHAR(64) NOT NULL,
    reason VARCHAR(255) NOT NULL,
    expires_at TIMESTAMP NULL,
    issued_by VARCHAR(64) NOT NULL,
    active TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_bans_license (license),
    KEY idx_bans_created_at (created_at),
    KEY idx_bans_active_expires (active, expires_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS admin_actions (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    actor_license VARCHAR(64) NOT NULL,
    target_license VARCHAR(64) NULL,
    action_type VARCHAR(64) NOT NULL,
    action_details JSON NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    KEY idx_admin_actions_actor_license (actor_license),
    KEY idx_admin_actions_target_license (target_license),
    KEY idx_admin_actions_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS jobs (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    job_name VARCHAR(64) NOT NULL,
    label VARCHAR(128) NOT NULL,
    default_grade TINYINT UNSIGNED NOT NULL DEFAULT 0,
    enabled TINYINT(1) NOT NULL DEFAULT 1,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_jobs_job_name (job_name),
    KEY idx_jobs_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS job_duty (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    char_id BIGINT UNSIGNED NOT NULL,
    job_name VARCHAR(64) NOT NULL,
    grade TINYINT UNSIGNED NOT NULL DEFAULT 0,
    on_duty TINYINT(1) NOT NULL DEFAULT 0,
    last_toggled_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_job_duty_char FOREIGN KEY (char_id) REFERENCES characters(id) ON DELETE CASCADE,
    CONSTRAINT fk_job_duty_job_name FOREIGN KEY (job_name) REFERENCES jobs(job_name) ON DELETE RESTRICT,
    UNIQUE KEY uq_job_duty_char_job (char_id, job_name),
    KEY idx_job_duty_char_id (char_id),
    KEY idx_job_duty_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS garages (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    garage_key VARCHAR(64) NOT NULL,
    label VARCHAR(128) NOT NULL,
    zone VARCHAR(128) NULL,
    capacity SMALLINT UNSIGNED NOT NULL DEFAULT 50,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY uq_garages_garage_key (garage_key),
    KEY idx_garages_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS vehicles (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    char_id BIGINT UNSIGNED NOT NULL,
    plate VARCHAR(16) NOT NULL,
    model VARCHAR(64) NOT NULL,
    props_json JSON NULL,
    state ENUM('out','garage','impound') NOT NULL DEFAULT 'garage',
    garage_key VARCHAR(64) NULL,
    insured TINYINT(1) NOT NULL DEFAULT 0,
    metadata JSON NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_vehicles_char FOREIGN KEY (char_id) REFERENCES characters(id) ON DELETE CASCADE,
    CONSTRAINT fk_vehicles_garage FOREIGN KEY (garage_key) REFERENCES garages(garage_key) ON DELETE SET NULL,
    UNIQUE KEY uq_vehicles_plate (plate),
    KEY idx_vehicles_plate (plate),
    KEY idx_vehicles_char_id (char_id),
    KEY idx_vehicles_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS vehicle_keys (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    vehicle_id BIGINT UNSIGNED NOT NULL,
    char_id BIGINT UNSIGNED NOT NULL,
    key_type ENUM('owner','shared','temp') NOT NULL DEFAULT 'owner',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_vehicle_keys_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE,
    CONSTRAINT fk_vehicle_keys_char FOREIGN KEY (char_id) REFERENCES characters(id) ON DELETE CASCADE,
    UNIQUE KEY uq_vehicle_keys_pair (vehicle_id, char_id),
    KEY idx_vehicle_keys_char_id (char_id),
    KEY idx_vehicle_keys_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;



CREATE TABLE IF NOT EXISTS vehicle_insurance_claims (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    vehicle_id BIGINT UNSIGNED NOT NULL,
    char_id BIGINT UNSIGNED NOT NULL,
    payout BIGINT NOT NULL DEFAULT 0,
    reason VARCHAR(128) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_vehicle_claims_vehicle FOREIGN KEY (vehicle_id) REFERENCES vehicles(id) ON DELETE CASCADE,
    CONSTRAINT fk_vehicle_claims_char FOREIGN KEY (char_id) REFERENCES characters(id) ON DELETE CASCADE,
    KEY idx_vehicle_claims_vehicle_id (vehicle_id),
    KEY idx_vehicle_claims_char_id (char_id),
    KEY idx_vehicle_claims_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS properties (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    property_key VARCHAR(64) NOT NULL,
    label VARCHAR(128) NOT NULL,
    owner_char_id BIGINT UNSIGNED NULL,
    value BIGINT NOT NULL DEFAULT 0,
    entry_coords JSON NULL,
    rent_amount BIGINT NOT NULL DEFAULT 0,
    interior_type VARCHAR(64) NULL,
    metadata JSON NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_properties_owner_char FOREIGN KEY (owner_char_id) REFERENCES characters(id) ON DELETE SET NULL,
    UNIQUE KEY uq_properties_property_key (property_key),
    KEY idx_properties_owner_char_id (owner_char_id),
    KEY idx_properties_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS property_keys (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    property_id BIGINT UNSIGNED NOT NULL,
    char_id BIGINT UNSIGNED NOT NULL,
    key_type ENUM('owner','tenant','guest') NOT NULL DEFAULT 'tenant',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_property_keys_property FOREIGN KEY (property_id) REFERENCES properties(id) ON DELETE CASCADE,
    CONSTRAINT fk_property_keys_char FOREIGN KEY (char_id) REFERENCES characters(id) ON DELETE CASCADE,
    UNIQUE KEY uq_property_keys_pair (property_id, char_id),
    KEY idx_property_keys_char_id (char_id),
    KEY idx_property_keys_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS business_registry (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    business_key VARCHAR(64) NOT NULL,
    business_name VARCHAR(128) NOT NULL,
    owner_char_id BIGINT UNSIGNED NULL,
    status ENUM('active','suspended','closed') NOT NULL DEFAULT 'active',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_business_registry_owner_char FOREIGN KEY (owner_char_id) REFERENCES characters(id) ON DELETE SET NULL,
    UNIQUE KEY uq_business_registry_key (business_key),
    KEY idx_business_registry_owner_char_id (owner_char_id),
    KEY idx_business_registry_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS business_accounts (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    business_id BIGINT UNSIGNED NOT NULL,
    balance BIGINT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_business_accounts_business FOREIGN KEY (business_id) REFERENCES business_registry(id) ON DELETE CASCADE,
    UNIQUE KEY uq_business_accounts_business_id (business_id),
    KEY idx_business_accounts_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS invoices (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    issuer_char_id BIGINT UNSIGNED NULL,
    receiver_char_id BIGINT UNSIGNED NOT NULL,
    business_id BIGINT UNSIGNED NULL,
    amount BIGINT NOT NULL,
    status ENUM('pending','paid','cancelled') NOT NULL DEFAULT 'pending',
    due_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_invoices_issuer_char FOREIGN KEY (issuer_char_id) REFERENCES characters(id) ON DELETE SET NULL,
    CONSTRAINT fk_invoices_receiver_char FOREIGN KEY (receiver_char_id) REFERENCES characters(id) ON DELETE CASCADE,
    CONSTRAINT fk_invoices_business FOREIGN KEY (business_id) REFERENCES business_registry(id) ON DELETE SET NULL,
    KEY idx_invoices_receiver_char_id (receiver_char_id),
    KEY idx_invoices_business_id (business_id),
    KEY idx_invoices_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS dispatch_calls (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    call_type VARCHAR(64) NOT NULL,
    priority ENUM('low','medium','high','critical') NOT NULL DEFAULT 'medium',
    coords_json JSON NOT NULL,
    description TEXT NOT NULL,
    caller_char_id BIGINT UNSIGNED NULL,
    assigned_units_json JSON NOT NULL,
    status ENUM('open','assigned','enroute','onscene','closed','cancelled') NOT NULL DEFAULT 'open',
    status_timeline_json JSON NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_dispatch_calls_caller_char FOREIGN KEY (caller_char_id) REFERENCES characters(id) ON DELETE SET NULL,
    KEY idx_dispatch_calls_caller_char_id (caller_char_id),
    KEY idx_dispatch_calls_status (status),
    KEY idx_dispatch_calls_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS police_reports (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    officer_char_id BIGINT UNSIGNED NOT NULL,
    subject_char_id BIGINT UNSIGNED NULL,
    report_type VARCHAR(64) NOT NULL,
    summary TEXT NOT NULL,
    report_json JSON NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_police_reports_officer_char FOREIGN KEY (officer_char_id) REFERENCES characters(id) ON DELETE CASCADE,
    CONSTRAINT fk_police_reports_subject_char FOREIGN KEY (subject_char_id) REFERENCES characters(id) ON DELETE SET NULL,
    KEY idx_police_reports_officer_char_id (officer_char_id),
    KEY idx_police_reports_subject_char_id (subject_char_id),
    KEY idx_police_reports_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS police_citations (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    officer_char_id BIGINT UNSIGNED NOT NULL,
    target_char_id BIGINT UNSIGNED NOT NULL,
    amount BIGINT NOT NULL,
    offense_code VARCHAR(32) NOT NULL,
    reason VARCHAR(255) NOT NULL,
    status ENUM('issued','paid','void') NOT NULL DEFAULT 'issued',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    paid_at TIMESTAMP NULL,
    CONSTRAINT fk_police_citations_officer FOREIGN KEY (officer_char_id) REFERENCES characters(id) ON DELETE CASCADE,
    CONSTRAINT fk_police_citations_target FOREIGN KEY (target_char_id) REFERENCES characters(id) ON DELETE CASCADE,
    KEY idx_police_citations_target (target_char_id),
    KEY idx_police_citations_status (status),
    KEY idx_police_citations_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS police_warrants (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    target_char_id BIGINT UNSIGNED NOT NULL,
    requested_by_char_id BIGINT UNSIGNED NOT NULL,
    reason VARCHAR(255) NOT NULL,
    status ENUM('active','served','expired','cancelled') NOT NULL DEFAULT 'active',
    expires_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_police_warrants_target FOREIGN KEY (target_char_id) REFERENCES characters(id) ON DELETE CASCADE,
    CONSTRAINT fk_police_warrants_requester FOREIGN KEY (requested_by_char_id) REFERENCES characters(id) ON DELETE CASCADE,
    KEY idx_police_warrants_target (target_char_id),
    KEY idx_police_warrants_status (status),
    KEY idx_police_warrants_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS police_case_notes (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    officer_char_id BIGINT UNSIGNED NOT NULL,
    target_char_id BIGINT UNSIGNED NULL,
    case_type VARCHAR(64) NOT NULL,
    note TEXT NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_police_case_notes_officer FOREIGN KEY (officer_char_id) REFERENCES characters(id) ON DELETE CASCADE,
    CONSTRAINT fk_police_case_notes_target FOREIGN KEY (target_char_id) REFERENCES characters(id) ON DELETE SET NULL,
    KEY idx_police_case_notes_target (target_char_id),
    KEY idx_police_case_notes_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS police_arrests (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    officer_char_id BIGINT UNSIGNED NOT NULL,
    target_char_id BIGINT UNSIGNED NOT NULL,
    charges TEXT NOT NULL,
    jail_minutes INT NOT NULL DEFAULT 0,
    status ENUM('processed','released','transferred') NOT NULL DEFAULT 'processed',
    processed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    released_at TIMESTAMP NULL,
    CONSTRAINT fk_police_arrests_officer FOREIGN KEY (officer_char_id) REFERENCES characters(id) ON DELETE CASCADE,
    CONSTRAINT fk_police_arrests_target FOREIGN KEY (target_char_id) REFERENCES characters(id) ON DELETE CASCADE,
    KEY idx_police_arrests_target (target_char_id),
    KEY idx_police_arrests_processed_at (processed_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS evidence (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    report_id BIGINT UNSIGNED NULL,
    collected_by_char_id BIGINT UNSIGNED NULL,
    evidence_type VARCHAR(64) NOT NULL,
    storage_ref VARCHAR(128) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_evidence_report FOREIGN KEY (report_id) REFERENCES police_reports(id) ON DELETE SET NULL,
    CONSTRAINT fk_evidence_collected_char FOREIGN KEY (collected_by_char_id) REFERENCES characters(id) ON DELETE SET NULL,
    KEY idx_evidence_report_id (report_id),
    KEY idx_evidence_collected_by_char_id (collected_by_char_id),
    KEY idx_evidence_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ems_records (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    medic_char_id BIGINT UNSIGNED NOT NULL,
    patient_char_id BIGINT UNSIGNED NULL,
    diagnosis VARCHAR(255) NOT NULL,
    treatment TEXT NULL,
    incident_severity ENUM('minor','major','critical') NOT NULL DEFAULT 'minor',
    hospital_name VARCHAR(128) NULL,
    outcome VARCHAR(128) NULL,
    billing_amount BIGINT NOT NULL DEFAULT 0,
    context_json JSON NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_ems_records_medic_char FOREIGN KEY (medic_char_id) REFERENCES characters(id) ON DELETE CASCADE,
    CONSTRAINT fk_ems_records_patient_char FOREIGN KEY (patient_char_id) REFERENCES characters(id) ON DELETE SET NULL,
    KEY idx_ems_records_medic_char_id (medic_char_id),
    KEY idx_ems_records_patient_char_id (patient_char_id),
    KEY idx_ems_records_severity (incident_severity),
    KEY idx_ems_records_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS ems_billing (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    patient_char_id BIGINT UNSIGNED NOT NULL,
    medic_char_id BIGINT UNSIGNED NULL,
    amount BIGINT NOT NULL,
    insurance_reduction DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    reason VARCHAR(128) NOT NULL,
    status ENUM('pending','paid','waived') NOT NULL DEFAULT 'paid',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    paid_at TIMESTAMP NULL,
    CONSTRAINT fk_ems_billing_patient_char FOREIGN KEY (patient_char_id) REFERENCES characters(id) ON DELETE CASCADE,
    CONSTRAINT fk_ems_billing_medic_char FOREIGN KEY (medic_char_id) REFERENCES characters(id) ON DELETE SET NULL,
    KEY idx_ems_billing_patient_char (patient_char_id),
    KEY idx_ems_billing_status (status),
    KEY idx_ems_billing_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS fire_incidents (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    responder_char_id BIGINT UNSIGNED NULL,
    incident_type VARCHAR(64) NOT NULL,
    location VARCHAR(255) NULL,
    severity ENUM('low','medium','high') NOT NULL DEFAULT 'medium',
    status ENUM('open','contained','closed') NOT NULL DEFAULT 'open',
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_fire_incidents_responder_char FOREIGN KEY (responder_char_id) REFERENCES characters(id) ON DELETE SET NULL,
    KEY idx_fire_incidents_responder_char_id (responder_char_id),
    KEY idx_fire_incidents_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS crime_cases (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    suspect_char_id BIGINT UNSIGNED NULL,
    case_status ENUM('open','investigating','closed','raided') NOT NULL DEFAULT 'open',
    title VARCHAR(128) NULL,
    heat_score INT NOT NULL DEFAULT 0,
    evidence_score INT NOT NULL DEFAULT 0,
    warrant_recommended TINYINT(1) NOT NULL DEFAULT 0,
    summary TEXT NULL,
    evidence_json JSON NULL,
    last_heat_at TIMESTAMP NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_crime_cases_suspect_char FOREIGN KEY (suspect_char_id) REFERENCES characters(id) ON DELETE SET NULL,
    KEY idx_crime_cases_suspect_char_id (suspect_char_id),
    KEY idx_crime_cases_status (case_status),
    KEY idx_crime_cases_warrant_recommended (warrant_recommended),
    KEY idx_crime_cases_last_heat_at (last_heat_at),
    KEY idx_crime_cases_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS heat_events (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    char_id BIGINT UNSIGNED NULL,
    case_id BIGINT UNSIGNED NULL,
    event_type VARCHAR(64) NOT NULL,
    heat_delta INT NOT NULL,
    coords_json JSON NULL,
    meta_json JSON NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_heat_events_char FOREIGN KEY (char_id) REFERENCES characters(id) ON DELETE SET NULL,
    CONSTRAINT fk_heat_events_case FOREIGN KEY (case_id) REFERENCES crime_cases(id) ON DELETE SET NULL,
    KEY idx_heat_events_char_id (char_id),
    KEY idx_heat_events_case_id (case_id),
    KEY idx_heat_events_event_type (event_type),
    KEY idx_heat_events_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS faction_members (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    faction_name VARCHAR(64) NOT NULL,
    char_id BIGINT UNSIGNED NOT NULL,
    rank_name VARCHAR(64) NOT NULL,
    joined_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_faction_members_char FOREIGN KEY (char_id) REFERENCES characters(id) ON DELETE CASCADE,
    UNIQUE KEY uq_faction_members_faction_char (faction_name, char_id),
    KEY idx_faction_members_char_id (char_id),
    KEY idx_faction_members_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS faction_territory (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    faction_name VARCHAR(64) NOT NULL,
    territory_key VARCHAR(64) NOT NULL,
    influence INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uq_faction_territory (faction_name, territory_key),
    KEY idx_faction_territory_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS reputation (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    char_id BIGINT UNSIGNED NOT NULL,
    rep_key VARCHAR(64) NOT NULL,
    value INT NOT NULL DEFAULT 0,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT fk_reputation_char FOREIGN KEY (char_id) REFERENCES characters(id) ON DELETE CASCADE,
    UNIQUE KEY uq_reputation_char_key (char_id, rep_key),
    KEY idx_reputation_char_id (char_id),
    KEY idx_reputation_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS story_state (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    char_id BIGINT UNSIGNED NOT NULL,
    chapter_id VARCHAR(64) NOT NULL,
    state ENUM('locked','active','completed') NOT NULL DEFAULT 'locked',
    progress INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_story_state_char FOREIGN KEY (char_id) REFERENCES characters(id) ON DELETE CASCADE,
    UNIQUE KEY uq_story_state_char_chapter (char_id, chapter_id),
    KEY idx_story_state_char_id (char_id),
    KEY idx_story_state_created_at (created_at)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Starter rows (safe/idempotent)
INSERT INTO jobs (job_name, label, default_grade, enabled)
VALUES
    ('unemployed', 'Unemployed', 0, 1),
    ('police', 'Port Aurora Police Department', 0, 1),
    ('ems', 'Port Aurora EMS', 0, 1),
    ('fire', 'Port Aurora Fire & Rescue', 0, 1),
    ('tow', 'Aurora Tow Services', 0, 1)
ON DUPLICATE KEY UPDATE label = VALUES(label), default_grade = VALUES(default_grade), enabled = VALUES(enabled);

INSERT INTO staff_roles (license, role_name, granted_by, notes)
VALUES
    ('license:example_owner', 'owner', 'system', 'Starter owner role, replace in production.'),
    ('license:example_admin', 'admin', 'system', 'Starter admin role, replace in production.')
ON DUPLICATE KEY UPDATE notes = VALUES(notes);

SET FOREIGN_KEY_CHECKS = 1;
