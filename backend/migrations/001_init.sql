-- Mystery Box schema (PostgreSQL). Generated from app/models.py.
-- The app also creates missing tables on start (python -m app.worker --migrate).

CREATE TABLE IF NOT EXISTS config (
	key VARCHAR(48) NOT NULL, 
	value TEXT NOT NULL, 
	PRIMARY KEY (key)
);


CREATE TABLE IF NOT EXISTS generation_log (
	id SERIAL NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	kind VARCHAR(12) NOT NULL, 
	requested INTEGER NOT NULL, 
	produced INTEGER NOT NULL, 
	failed INTEGER NOT NULL, 
	message TEXT NOT NULL, 
	PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS ix_generation_log_created_at ON generation_log (created_at);

CREATE TABLE IF NOT EXISTS missions (
	id VARCHAR(64) NOT NULL, 
	kind VARCHAR(12) NOT NULL, 
	slot VARCHAR(16) NOT NULL, 
	difficulty INTEGER NOT NULL, 
	seed BIGINT NOT NULL, 
	generator_version INTEGER NOT NULL, 
	signature VARCHAR(64) NOT NULL, 
	status VARCHAR(12) NOT NULL, 
	min_seconds INTEGER NOT NULL, 
	payload TEXT NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id)
);

CREATE INDEX IF NOT EXISTS ix_missions_difficulty ON missions (difficulty);
CREATE INDEX IF NOT EXISTS ix_missions_kind ON missions (kind);
CREATE INDEX IF NOT EXISTS ix_missions_signature ON missions (signature);
CREATE INDEX IF NOT EXISTS ix_missions_slot ON missions (slot);
CREATE INDEX IF NOT EXISTS ix_missions_status ON missions (status);

CREATE TABLE IF NOT EXISTS players (
	id VARCHAR(36) NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	last_seen TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	is_guest BOOLEAN NOT NULL, 
	email VARCHAR(254), 
	password_hash VARCHAR(200), 
	display_name VARCHAR(24) NOT NULL, 
	show_on_leaderboard BOOLEAN NOT NULL, 
	token_version INTEGER NOT NULL, 
	PRIMARY KEY (id), 
	UNIQUE (email)
);

CREATE INDEX IF NOT EXISTS ix_players_last_seen ON players (last_seen);

CREATE TABLE IF NOT EXISTS completions (
	id SERIAL NOT NULL, 
	player_id VARCHAR(36) NOT NULL, 
	mission_id VARCHAR(64) NOT NULL, 
	time_ms INTEGER NOT NULL, 
	hints INTEGER NOT NULL, 
	accepted BOOLEAN NOT NULL, 
	reject_reason VARCHAR(40) NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	CONSTRAINT uq_completion_player_mission UNIQUE (player_id, mission_id), 
	FOREIGN KEY(player_id) REFERENCES players (id) ON DELETE CASCADE, 
	FOREIGN KEY(mission_id) REFERENCES missions (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_completions_mission_id ON completions (mission_id);
CREATE INDEX IF NOT EXISTS ix_completions_player_id ON completions (player_id);

CREATE TABLE IF NOT EXISTS events (
	id SERIAL NOT NULL, 
	player_id VARCHAR(36) NOT NULL, 
	name VARCHAR(32) NOT NULL, 
	day VARCHAR(10) NOT NULL, 
	props TEXT NOT NULL, 
	created_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (id), 
	FOREIGN KEY(player_id) REFERENCES players (id) ON DELETE CASCADE
);

CREATE INDEX IF NOT EXISTS ix_events_day ON events (day);
CREATE INDEX IF NOT EXISTS ix_events_name ON events (name);
CREATE INDEX IF NOT EXISTS ix_events_player_id ON events (player_id);

CREATE TABLE IF NOT EXISTS progress (
	player_id VARCHAR(36) NOT NULL, 
	solved INTEGER NOT NULL, 
	data TEXT NOT NULL, 
	updated_at TIMESTAMP WITHOUT TIME ZONE NOT NULL, 
	PRIMARY KEY (player_id), 
	FOREIGN KEY(player_id) REFERENCES players (id) ON DELETE CASCADE
);

