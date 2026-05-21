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
CREATE TABLE `milestone` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`project_id` integer NOT NULL,
	`title` text NOT NULL,
	`due_at` integer,
	`status` text DEFAULT 'planned' NOT NULL,
	FOREIGN KEY (`project_id`) REFERENCES `project`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE TABLE `project` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`slug` text NOT NULL,
	`title` text NOT NULL,
	`purpose` text DEFAULT '' NOT NULL,
	`status` text DEFAULT 'proposed' NOT NULL,
	`owner_agent` text,
	`mission_md_path` text,
	`created_at` integer DEFAULT (unixepoch()) NOT NULL,
	`updated_at` integer DEFAULT (unixepoch()) NOT NULL
);
--> statement-breakpoint
CREATE UNIQUE INDEX `project_slug_uq` ON `project` (`slug`);--> statement-breakpoint
CREATE INDEX `project_status_idx` ON `project` (`status`);--> statement-breakpoint
CREATE TABLE `project_repo` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`project_id` integer NOT NULL,
	`ref` text NOT NULL,
	`url` text NOT NULL,
	`label` text,
	FOREIGN KEY (`project_id`) REFERENCES `project`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE INDEX `project_repo_ref_idx` ON `project_repo` (`project_id`,`ref`);--> statement-breakpoint
CREATE TABLE `project_report` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`project_id` integer NOT NULL,
	`host_id` integer NOT NULL,
	`agent_id` integer NOT NULL,
	`kind` text NOT NULL,
	`summary` text NOT NULL,
	`refs` text DEFAULT '[]' NOT NULL,
	`created_at` integer DEFAULT (unixepoch()) NOT NULL,
	FOREIGN KEY (`project_id`) REFERENCES `project`(`id`) ON UPDATE no action ON DELETE cascade,
	FOREIGN KEY (`host_id`) REFERENCES `host`(`id`) ON UPDATE no action ON DELETE no action,
	FOREIGN KEY (`agent_id`) REFERENCES `agent`(`id`) ON UPDATE no action ON DELETE no action
);
--> statement-breakpoint
CREATE INDEX `project_report_project_idx` ON `project_report` (`project_id`,`created_at`);--> statement-breakpoint
CREATE INDEX `project_report_host_idx` ON `project_report` (`host_id`,`created_at`);--> statement-breakpoint
CREATE INDEX `project_report_agent_idx` ON `project_report` (`agent_id`,`created_at`);--> statement-breakpoint
CREATE TABLE `project_scope` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`project_id` integer NOT NULL,
	`kind` text NOT NULL,
	`text` text NOT NULL,
	FOREIGN KEY (`project_id`) REFERENCES `project`(`id`) ON UPDATE no action ON DELETE cascade
);
--> statement-breakpoint
CREATE TABLE `project_value` (
	`id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
	`project_id` integer NOT NULL,
	`text` text NOT NULL,
	FOREIGN KEY (`project_id`) REFERENCES `project`(`id`) ON UPDATE no action ON DELETE cascade
);
