import {sqliteTable,text,integer,index} from 'drizzle-orm/sqlite-core';

export const runs=sqliteTable('runs',{
 id:text('id').primaryKey(),nickname:text('nickname').notNull(),score:integer('score').notNull(),ticks:integer('ticks').notNull(),mode:text('mode').notNull(),difficulty:text('difficulty').notNull(),sector:text('sector').notNull(),ships:text('ships').notNull(),rules:text('rules').notNull(),season:text('season').notNull(),started_at:text('started_at').notNull(),finished_at:text('finished_at').notNull(),published:integer('published').notNull().default(0),result_hash:text('result_hash').notNull(),replay:text('replay').notNull().default('{}')
},table=>[index('ranking_board').on(table.published,table.season,table.rules,table.mode,table.difficulty,table.sector,table.score,table.ticks)]);
