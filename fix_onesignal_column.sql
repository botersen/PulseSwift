-- Quick fix for missing onesignal_player_id column
-- Run this in your Supabase SQL editor

-- Add the missing column to the users table
ALTER TABLE users ADD COLUMN IF NOT EXISTS onesignal_player_id TEXT;

-- Create the index for the new column
CREATE INDEX IF NOT EXISTS idx_users_onesignal ON users(onesignal_player_id);

-- Now run the storage policies (these were failing before)
-- Drop existing storage policies if they exist
DROP POLICY IF EXISTS "Users can upload their own media" ON storage.objects;
DROP POLICY IF EXISTS "Anyone can view pulse media" ON storage.objects;
DROP POLICY IF EXISTS "Users can update their own media" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete their own media" ON storage.objects;

-- Storage policies
CREATE POLICY "Users can upload their own media" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'pulse-media' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Anyone can view pulse media" ON storage.objects
    FOR SELECT USING (bucket_id = 'pulse-media');

CREATE POLICY "Users can update their own media" ON storage.objects
    FOR UPDATE USING (bucket_id = 'pulse-media' AND auth.uid()::text = (storage.foldername(name))[1]);

CREATE POLICY "Users can delete their own media" ON storage.objects
    FOR DELETE USING (bucket_id = 'pulse-media' AND auth.uid()::text = (storage.foldername(name))[1]); 