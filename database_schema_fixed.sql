-- Pulse App Database Schema (FIXED)
-- Run this in your Supabase SQL editor

-- Enable PostGIS for geospatial queries
CREATE EXTENSION IF NOT EXISTS postgis;

-- Users table
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    username TEXT UNIQUE NOT NULL,
    email TEXT UNIQUE,
    subscription_tier TEXT DEFAULT 'free' CHECK (subscription_tier IN ('free', 'premium')),
    
    -- Location data
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    city TEXT,
    country TEXT,
    location_updated_at TIMESTAMPTZ,
    
    -- Profile data
    profile_image_url TEXT,
    onesignal_player_id TEXT,  -- This was missing in the original!
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_active_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Pulses table
CREATE TABLE IF NOT EXISTS pulses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sender_id UUID REFERENCES users(id) ON DELETE CASCADE,
    recipient_id UUID REFERENCES users(id) ON DELETE CASCADE,
    
    -- Media content
    media_url TEXT NOT NULL,
    media_type TEXT NOT NULL CHECK (media_type IN ('photo', 'video')),
    caption TEXT,
    
    -- Location and targeting
    sender_latitude DECIMAL(10, 8) NOT NULL,
    sender_longitude DECIMAL(11, 8) NOT NULL,
    sender_city TEXT,
    sender_country TEXT,
    target_radius DECIMAL NOT NULL, -- in meters
    
    -- Timing
    created_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    opened_at TIMESTAMPTZ,
    responded_at TIMESTAMPTZ,
    
    -- Status and matching
    status TEXT DEFAULT 'searching' CHECK (status IN ('searching', 'delivered', 'opened', 'responded', 'expired', 'rejected', 'failed')),
    attempt_number INTEGER DEFAULT 1 CHECK (attempt_number BETWEEN 1 AND 5),
    
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Pulse matches (conversations)
CREATE TABLE IF NOT EXISTS pulse_matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pulse_id UUID REFERENCES pulses(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES users(id) ON DELETE CASCADE,
    recipient_id UUID REFERENCES users(id) ON DELETE CASCADE,
    
    -- Match details
    matched_at TIMESTAMPTZ DEFAULT NOW(),
    last_activity_at TIMESTAMPTZ DEFAULT NOW(),
    status TEXT DEFAULT 'active' CHECK (status IN ('active', 'expired', 'completed')),
    
    -- Location where match occurred
    match_latitude DECIMAL(10, 8),
    match_longitude DECIMAL(11, 8),
    match_city TEXT,
    match_country TEXT,
    
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Pulse messages (for 3-minute conversations)
CREATE TABLE IF NOT EXISTS pulse_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pulse_match_id UUID REFERENCES pulse_matches(id) ON DELETE CASCADE,
    sender_id UUID REFERENCES users(id) ON DELETE CASCADE,
    
    -- Message content
    media_url TEXT NOT NULL,
    media_type TEXT NOT NULL CHECK (media_type IN ('photo', 'video')),
    caption TEXT,
    
    -- Translation
    original_language TEXT DEFAULT 'en',
    translated_caption TEXT,
    target_language TEXT,
    
    -- Timing
    sent_at TIMESTAMPTZ DEFAULT NOW(),
    expires_at TIMESTAMPTZ NOT NULL,
    opened_at TIMESTAMPTZ,
    
    status TEXT DEFAULT 'sent' CHECK (status IN ('sent', 'delivered', 'opened', 'expired')),
    
    created_at TIMESTAMPTZ DEFAULT NOW()
);

-- User statistics
CREATE TABLE IF NOT EXISTS user_stats (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    total_pulses_sent INTEGER DEFAULT 0,
    total_pulses_received INTEGER DEFAULT 0,
    total_matches INTEGER DEFAULT 0,
    translations_used_today INTEGER DEFAULT 0,
    last_translation_reset DATE DEFAULT CURRENT_DATE,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_users_location ON users USING GIST (ST_Point(longitude, latitude));
CREATE INDEX IF NOT EXISTS idx_users_last_active ON users(last_active_at);
CREATE INDEX IF NOT EXISTS idx_users_onesignal ON users(onesignal_player_id);

CREATE INDEX IF NOT EXISTS idx_pulses_sender ON pulses(sender_id);
CREATE INDEX IF NOT EXISTS idx_pulses_recipient ON pulses(recipient_id);
CREATE INDEX IF NOT EXISTS idx_pulses_status ON pulses(status);
CREATE INDEX IF NOT EXISTS idx_pulses_location ON pulses USING GIST (ST_Point(sender_longitude, sender_latitude));
CREATE INDEX IF NOT EXISTS idx_pulses_expires ON pulses(expires_at);

CREATE INDEX IF NOT EXISTS idx_matches_pulse ON pulse_matches(pulse_id);
CREATE INDEX IF NOT EXISTS idx_matches_participants ON pulse_matches(sender_id, recipient_id);
CREATE INDEX IF NOT EXISTS idx_matches_activity ON pulse_matches(last_activity_at);

CREATE INDEX IF NOT EXISTS idx_messages_match ON pulse_messages(pulse_match_id);
CREATE INDEX IF NOT EXISTS idx_messages_sender ON pulse_messages(sender_id);
CREATE INDEX IF NOT EXISTS idx_messages_expires ON pulse_messages(expires_at);

-- Geospatial function to find users within radius
CREATE OR REPLACE FUNCTION find_users_within_radius(
    lat DECIMAL,
    lng DECIMAL, 
    radius_meters DECIMAL
)
RETURNS SETOF users AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM users 
    WHERE latitude IS NOT NULL 
      AND longitude IS NOT NULL
      AND ST_DWithin(
          ST_Point(longitude, latitude)::geography,
          ST_Point(lng, lat)::geography,
          radius_meters
      )
      AND last_active_at > NOW() - INTERVAL '24 hours'; -- Only active users
END;
$$ LANGUAGE plpgsql;

-- Function to clean up expired pulses
CREATE OR REPLACE FUNCTION cleanup_expired_pulses()
RETURNS INTEGER AS $$
DECLARE
    expired_count INTEGER;
BEGIN
    UPDATE pulses 
    SET status = 'expired'
    WHERE expires_at < NOW() 
      AND status IN ('searching', 'delivered');
    
    GET DIAGNOSTICS expired_count = ROW_COUNT;
    RETURN expired_count;
END;
$$ LANGUAGE plpgsql;

-- Function to clean up expired messages
CREATE OR REPLACE FUNCTION cleanup_expired_messages()
RETURNS INTEGER AS $$
DECLARE
    expired_count INTEGER;
BEGIN
    UPDATE pulse_messages 
    SET status = 'expired'
    WHERE expires_at < NOW() 
      AND status IN ('sent', 'delivered');
    
    GET DIAGNOSTICS expired_count = ROW_COUNT;
    RETURN expired_count;
END;
$$ LANGUAGE plpgsql;

-- Function to reset daily translation counts
CREATE OR REPLACE FUNCTION reset_daily_translations()
RETURNS INTEGER AS $$
DECLARE
    reset_count INTEGER;
BEGIN
    UPDATE user_stats 
    SET translations_used_today = 0,
        last_translation_reset = CURRENT_DATE
    WHERE last_translation_reset < CURRENT_DATE;
    
    GET DIAGNOSTICS reset_count = ROW_COUNT;
    RETURN reset_count;
END;
$$ LANGUAGE plpgsql;

-- Update timestamps trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply timestamp triggers
DROP TRIGGER IF EXISTS update_users_updated_at ON users;
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_pulses_updated_at ON pulses;
CREATE TRIGGER update_pulses_updated_at 
    BEFORE UPDATE ON pulses 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_matches_updated_at ON pulse_matches;
CREATE TRIGGER update_matches_updated_at 
    BEFORE UPDATE ON pulse_matches 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

DROP TRIGGER IF EXISTS update_stats_updated_at ON user_stats;
CREATE TRIGGER update_stats_updated_at 
    BEFORE UPDATE ON user_stats 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE pulses ENABLE ROW LEVEL SECURITY;
ALTER TABLE pulse_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE pulse_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_stats ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if they exist
DROP POLICY IF EXISTS "Users can view their own profile" ON users;
DROP POLICY IF EXISTS "Users can update their own profile" ON users;
DROP POLICY IF EXISTS "Users can insert their own profile" ON users;

DROP POLICY IF EXISTS "Users can view their own pulses" ON pulses;
DROP POLICY IF EXISTS "Users can insert their own pulses" ON pulses;
DROP POLICY IF EXISTS "Users can update their own pulses" ON pulses;

DROP POLICY IF EXISTS "Users can view their own matches" ON pulse_matches;
DROP POLICY IF EXISTS "System can insert matches" ON pulse_matches;
DROP POLICY IF EXISTS "Users can update their own matches" ON pulse_matches;

DROP POLICY IF EXISTS "Users can view messages in their matches" ON pulse_messages;
DROP POLICY IF EXISTS "Users can send messages in their matches" ON pulse_messages;

DROP POLICY IF EXISTS "Users can view their own stats" ON user_stats;
DROP POLICY IF EXISTS "Users can insert their own stats" ON user_stats;
DROP POLICY IF EXISTS "Users can update their own stats" ON user_stats;

-- RLS Policies for users table
CREATE POLICY "Users can view their own profile" ON users
    FOR SELECT USING (auth.uid() = id);

CREATE POLICY "Users can update their own profile" ON users
    FOR UPDATE USING (auth.uid() = id);

CREATE POLICY "Users can insert their own profile" ON users
    FOR INSERT WITH CHECK (auth.uid() = id);

-- RLS Policies for pulses table  
CREATE POLICY "Users can view their own pulses" ON pulses
    FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

CREATE POLICY "Users can insert their own pulses" ON pulses
    FOR INSERT WITH CHECK (auth.uid() = sender_id);

CREATE POLICY "Users can update their own pulses" ON pulses
    FOR UPDATE USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

-- RLS Policies for pulse_matches table
CREATE POLICY "Users can view their own matches" ON pulse_matches
    FOR SELECT USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

CREATE POLICY "System can insert matches" ON pulse_matches
    FOR INSERT WITH CHECK (true); -- System inserts matches

CREATE POLICY "Users can update their own matches" ON pulse_matches
    FOR UPDATE USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

-- RLS Policies for pulse_messages table
CREATE POLICY "Users can view messages in their matches" ON pulse_messages
    FOR SELECT USING (
        pulse_match_id IN (
            SELECT id FROM pulse_matches 
            WHERE sender_id = auth.uid() OR recipient_id = auth.uid()
        )
    );

CREATE POLICY "Users can send messages in their matches" ON pulse_messages
    FOR INSERT WITH CHECK (
        auth.uid() = sender_id AND
        pulse_match_id IN (
            SELECT id FROM pulse_matches 
            WHERE sender_id = auth.uid() OR recipient_id = auth.uid()
        )
    );

-- RLS Policies for user_stats table
CREATE POLICY "Users can view their own stats" ON user_stats
    FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own stats" ON user_stats
    FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own stats" ON user_stats
    FOR UPDATE USING (auth.uid() = user_id);

-- Create storage bucket for pulse media
INSERT INTO storage.buckets (id, name, public)
VALUES ('pulse-media', 'pulse-media', true)
ON CONFLICT (id) DO NOTHING;

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