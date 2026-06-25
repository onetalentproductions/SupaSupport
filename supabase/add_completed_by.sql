-- Track which admin marked a ticket complete (for admin scoreboard)
ALTER TABLE tickets ADD COLUMN IF NOT EXISTS completed_by_email TEXT;
