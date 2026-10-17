CREATE TABLE IF NOT EXISTS runs (
 id TEXT PRIMARY KEY,
 nickname TEXT NOT NULL,
 score INTEGER NOT NULL CHECK(score >= 0 AND score <= 1000000000),
 ticks INTEGER NOT NULL CHECK(ticks >= 0 AND ticks <= 36001),
 mode TEXT NOT NULL CHECK(mode IN ('solo','coop')),
 difficulty TEXT NOT NULL,
 sector TEXT NOT NULL,
 ships TEXT NOT NULL,
 rules TEXT NOT NULL,
 season TEXT NOT NULL,
 started_at TEXT NOT NULL,
 finished_at TEXT NOT NULL,
 published INTEGER NOT NULL DEFAULT 0,
 result_hash TEXT NOT NULL,
 replay TEXT NOT NULL DEFAULT '{}'
);
CREATE INDEX IF NOT EXISTS ranking_board ON runs(published,season,rules,mode,difficulty,sector,score DESC,ticks DESC,id);
