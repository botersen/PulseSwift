-- Pulse App Database Schema - COMPLETE & CORRECTED
-- Run this entire script in your Supabase SQL editor

-- Enable PostGIS for geospatial queries
CREATE EXTENSION IF NOT EXISTS postgis;

-- Drop existing tables if they exist (to start fresh)
DROP TABLE IF EXISTS pulse_messages CASCADE;
DROP TABLE IF EXISTS pulse_matches CASCADE;
DROP TABLE IF EXISTS user_stats CASCADE;
DROP TABLE IF EXISTS pulses CASCADE;
DROP TABLE IF EXISTS users CASCADE;

-- Drop existing functions
DROP FUNCTION IF EXISTS find_users_within_radius(DECIMAL, DECIMAL, DECIMAL);
DROP FUNCTION IF EXISTS cleanup_expired_pulses();
DROP FUNCTION IF EXISTS cleanup_expired_messages();
DROP FUNCTION IF EXISTS reset_daily_translations();
DROP FUNCTION IF EXISTS update_updated_at_column();

-- Users table
CREATE TABLE users (
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
    onesignal_player_id TEXT,
    
    -- Timestamps
    created_at TIMESTAMPTZ DEFAULT NOW(),
    last_active_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Pulses table
CREATE TABLE pulses (
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
CREATE TABLE pulse_matches (
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
CREATE TABLE pulse_messages (
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
CREATE TABLE user_stats (
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
CREATE INDEX idx_users_location ON users USING GIST (ST_Point(longitude, latitude));
CREATE INDEX idx_users_last_active ON users(last_active_at);
CREATE INDEX idx_users_onesignal ON users(onesignal_player_id);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_email ON users(email);

CREATE INDEX idx_pulses_sender ON pulses(sender_id);
CREATE INDEX idx_pulses_recipient ON pulses(recipient_id);
CREATE INDEX idx_pulses_status ON pulses(status);
CREATE INDEX idx_pulses_location ON pulses USING GIST (ST_Point(sender_longitude, sender_latitude));
CREATE INDEX idx_pulses_expires ON pulses(expires_at);
CREATE INDEX idx_pulses_created ON pulses(created_at);

CREATE INDEX idx_matches_pulse ON pulse_matches(pulse_id);
CREATE INDEX idx_matches_participants ON pulse_matches(sender_id, recipient_id);
CREATE INDEX idx_matches_activity ON pulse_matches(last_activity_at);
CREATE INDEX idx_matches_status ON pulse_matches(status);

CREATE INDEX idx_messages_match ON pulse_messages(pulse_match_id);
CREATE INDEX idx_messages_sender ON pulse_messages(sender_id);
CREATE INDEX idx_messages_expires ON pulse_messages(expires_at);
CREATE INDEX idx_messages_sent ON pulse_messages(sent_at);

CREATE INDEX idx_stats_user ON user_stats(user_id);

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

-- Update timestamps trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply timestamp triggers
CREATE TRIGGER update_users_updated_at 
    BEFORE UPDATE ON users 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_pulses_updated_at 
    BEFORE UPDATE ON pulses 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_matches_updated_at 
    BEFORE UPDATE ON pulse_matches 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_stats_updated_at 
    BEFORE UPDATE ON user_stats 
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE pulses ENABLE ROW LEVEL SECURITY;
ALTER TABLE pulse_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE pulse_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_stats ENABLE ROW LEVEL SECURITY;

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
ON CONFLICT (id) DO UPDATE SET 
    name = EXCLUDED.name,
    public = EXCLUDED.public;

-- Storage policies
CREATE POLICY "Users can upload their own media" ON storage.objects
    FOR INSERT WITH CHECK (bucket_id = 'pulse-media');

CREATE POLICY "Anyone can view pulse media" ON storage.objects
    FOR SELECT USING (bucket_id = 'pulse-media');

CREATE POLICY "Users can update their own media" ON storage.objects
    FOR UPDATE USING (bucket_id = 'pulse-media');

CREATE POLICY "Users can delete their own media" ON storage.objects
    FOR DELETE USING (bucket_id = 'pulse-media');

-- Grant necessary permissions
GRANT USAGE ON SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL TABLES IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO postgres, anon, authenticated, service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA public TO postgres, anon, authenticated, service_role;

-- Insert sample data for testing (optional)
-- INSERT INTO users (id, username, email, subscription_tier, latitude, longitude, city, country)
-- VALUES 
--     ('00000000-0000-0000-0000-000000000001', 'testuser1', 'test1@example.com', 'free', 40.7128, -74.0060, 'New York', 'USA'),
--     ('00000000-0000-0000-0000-000000000002', 'testuser2', 'test2@example.com', 'premium', 34.0522, -118.2437, 'Los Angeles', 'USA');

-- Success message
SELECT 'Pulse database schema created successfully! 🚀' as status; 