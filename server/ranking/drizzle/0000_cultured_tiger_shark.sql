CREATE TABLE `runs` (
	`id` text PRIMARY KEY NOT NULL,
	`nickname` text NOT NULL,
	`score` integer NOT NULL,
	`ticks` integer NOT NULL,
	`mode` text NOT NULL,
	`difficulty` text NOT NULL,
	`sector` text NOT NULL,
	`ships` text NOT NULL,
	`rules` text NOT NULL,
	`season` text NOT NULL,
	`started_at` text NOT NULL,
	`finished_at` text NOT NULL,
	`published` integer DEFAULT 0 NOT NULL,
	`result_hash` text NOT NULL,
	`replay` text DEFAULT '{}' NOT NULL
);
--> statement-breakpoint
CREATE INDEX `ranking_board` ON `runs` (`published`,`season`,`rules`,`mode`,`difficulty`,`sector`,`score`,`ticks`);