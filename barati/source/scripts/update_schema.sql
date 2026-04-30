-- Run these commands in your Supabase SQL Editor to support the new Invitation and Status features

-- Add 'status' column to 'applications' table
ALTER TABLE applications 
ADD COLUMN IF NOT EXISTS status INTEGER DEFAULT 0;

-- Add 'is_invitation' column to 'applications' table
ALTER TABLE applications 
ADD COLUMN IF NOT EXISTS is_invitation BOOLEAN DEFAULT FALSE;

-- Optional: Add index for performance
CREATE INDEX IF NOT EXISTS idx_applications_status ON applications(status);
CREATE INDEX IF NOT EXISTS idx_applications_is_invitation ON applications(is_invitation);
