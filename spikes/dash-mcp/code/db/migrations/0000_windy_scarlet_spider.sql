CREATE TABLE `agent` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`name` text NOT NULL,
	`host_id` integer NOT NULL,
	`first_seen` integer DEFAULT (unixepoch()) NOT NULL,
	`last_seen` integer DEFAULT (unixepoch()) NOT NULL,
	FOREIGN KEY (`host_id`) REFERENCES `host`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE UNIQUE INDEX `agent_name_host_uq` ON `agent` (`name`,`host_id`);--> statement-breakpoint
CREATE TABLE `host` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`hostname` text NOT NULL,
	`first_seen` integer DEFAULT (unixepoch()) NOT NULL,
	`last_seen` integer DEFAULT (unixepoch()) NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `host_hostname_uq` ON `host` (`hostname`);--> statement-breakpoint
CREATE TABLE `mission` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`slug` text NOT NULL,
	`project` text NOT NULL,
	`title` text NOT NULL,
	`purpose` text DEFAULT '' NOT NULL,
	`status` text DEFAULT 'proposed' NOT NULL,
	`owner_agent` text,
	`created_at` integer DEFAULT (unixepoch()) NOT NULL,
	`updated_at` integer DEFAULT (unixepoch()) NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `mission_slug_uq` ON `mission` (`slug`);--> statement-breakpoint
CREATE INDEX `mission_project_idx` ON `mission` (`project`);--> statement-breakpoint
CREATE INDEX `mission_status_idx` ON `mission` (`status`);--> statement-breakpoint
CREATE TABLE `mission_milestone` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`mission_id` integer NOT NULL,
	`title` text NOT NULL,
	`due_at` integer,
	`status` text DEFAULT 'planned' NOT NULL,
	FOREIGN KEY (`mission_id`) REFERENCES `mission`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE TABLE `mission_repo` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`mission_id` integer NOT NULL,
	`ref` text NOT NULL,
	`url` text NOT NULL,
	`label` text,
	FOREIGN KEY (`mission_id`) REFERENCES `mission`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `mission_repo_ref_idx` ON `mission_repo` (`mission_id`,`ref`);--> statement-breakpoint
CREATE TABLE `mission_report` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`mission_id` integer NOT NULL,
	`host_id` integer NOT NULL,
	`agent_id` integer NOT NULL,
	`kind` text NOT NULL,
	`summary` text NOT NULL,
	`refs` text DEFAULT '[]' NOT NULL,
	`created_at` integer DEFAULT (unixepoch()) NOT NULL,
	FOREIGN KEY (`mission_id`) REFERENCES `mission`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`host_id`) REFERENCES `host`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`agent_id`) REFERENCES `agent`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE INDEX `mission_report_mission_idx` ON `mission_report` (`mission_id`,`created_at`);--> statement-breakpoint
CREATE INDEX `mission_report_host_idx` ON `mission_report` (`host_id`,`created_at`);--> statement-breakpoint
CREATE INDEX `mission_report_agent_idx` ON `mission_report` (`agent_id`,`created_at`);--> statement-breakpoint
CREATE TABLE `mission_scope` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`mission_id` integer NOT NULL,
	`kind` text NOT NULL,
	`text` text NOT NULL,
	FOREIGN KEY (`mission_id`) REFERENCES `mission`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE TABLE `mission_value` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`mission_id` integer NOT NULL,
	`text` text NOT NULL,
	FOREIGN KEY (`mission_id`) REFERENCES `mission`(`id`) ON UPDATE no action ON DELETE cascade
);
