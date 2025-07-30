-- Globe Feature Database Schema for Supabase
-- Requires PostGIS extension for geography support

-- Enable PostGIS extension
CREATE EXTENSION IF NOT EXISTS postgis;

-- Table for storing pulse matches with geographic data
CREATE TABLE IF NOT EXISTS pulse_matches (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    partner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Geographic locations using PostGIS
    user_location GEOGRAPHY(POINT, 4326) NOT NULL,
    partner_location GEOGRAPHY(POINT, 4326) NOT NULL,
    
    -- Pulse session data
    pulse_duration INTERVAL DEFAULT INTERVAL '0 seconds',
    photo_count INTEGER DEFAULT 0,
    session_started_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    session_ended_at TIMESTAMP WITH TIME ZONE,
    
    -- Metadata
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Ensure users can't pulse themselves
    CONSTRAINT different_users CHECK (user_id != partner_id)
);

-- Table for real-time location tracking
CREATE TABLE IF NOT EXISTS user_locations (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    current_location GEOGRAPHY(POINT, 4326) NOT NULL,
    location_accuracy FLOAT,
    is_actively_pulsing BOOLEAN DEFAULT FALSE,
    current_pulse_partner_id UUID REFERENCES auth.users(id),
    last_updated TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Table for pulse session history (for globe stars)
CREATE TABLE IF NOT EXISTS pulse_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    pulse_match_id UUID REFERENCES pulse_matches(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    partner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    
    -- Location where the pulse occurred
    pulse_location GEOGRAPHY(POINT, 4326) NOT NULL,
    pulse_timestamp TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Visual data for globe
    star_size_multiplier FLOAT DEFAULT 1.0,
    total_pulse_duration INTERVAL DEFAULT INTERVAL '0 seconds',
    
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_pulse_matches_user_id ON pulse_matches(user_id);
CREATE INDEX IF NOT EXISTS idx_pulse_matches_partner_id ON pulse_matches(partner_id);
CREATE INDEX IF NOT EXISTS idx_pulse_matches_created_at ON pulse_matches(created_at);

-- Geographic indexes for spatial queries
CREATE INDEX IF NOT EXISTS idx_pulse_matches_user_location ON pulse_matches USING GIST(user_location);
CREATE INDEX IF NOT EXISTS idx_pulse_matches_partner_location ON pulse_matches USING GIST(partner_location);
CREATE INDEX IF NOT EXISTS idx_user_locations_current ON user_locations USING GIST(current_location);
CREATE INDEX IF NOT EXISTS idx_pulse_history_location ON pulse_history USING GIST(pulse_location);

-- RLS (Row Level Security) policies
ALTER TABLE pulse_matches ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_locations ENABLE ROW LEVEL SECURITY;
ALTER TABLE pulse_history ENABLE ROW LEVEL SECURITY;

-- Users can only see their own pulse matches
CREATE POLICY "Users can view their own pulse matches" ON pulse_matches
    FOR SELECT USING (user_id = auth.uid() OR partner_id = auth.uid());

CREATE POLICY "Users can insert their own pulse matches" ON pulse_matches
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users can update their own pulse matches" ON pulse_matches
    FOR UPDATE USING (user_id = auth.uid());

-- Users can manage their own location
CREATE POLICY "Users can manage their own location" ON user_locations
    FOR ALL USING (user_id = auth.uid());

-- Users can view pulse history they participated in
CREATE POLICY "Users can view their pulse history" ON pulse_history
    FOR SELECT USING (user_id = auth.uid() OR partner_id = auth.uid());

-- Functions for globe feature
CREATE OR REPLACE FUNCTION get_nearby_pulse_matches(
    center_lat FLOAT,
    center_lng FLOAT,
    radius_meters FLOAT DEFAULT 50000000 -- 50,000km default (global view)
)
RETURNS TABLE(
    id UUID,
    user_id UUID,
    partner_id UUID,
    user_lat FLOAT,
    user_lng FLOAT,
    partner_lat FLOAT,
    partner_lng FLOAT,
    pulse_duration INTERVAL,
    photo_count INTEGER,
    created_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pm.id,
        pm.user_id,
        pm.partner_id,
        ST_Y(pm.user_location::geometry) as user_lat,
        ST_X(pm.user_location::geometry) as user_lng,
        ST_Y(pm.partner_location::geometry) as partner_lat,
        ST_X(pm.partner_location::geometry) as partner_lng,
        pm.pulse_duration,
        pm.photo_count,
        pm.created_at
    FROM pulse_matches pm
    WHERE ST_DWithin(
        pm.user_location,
        ST_Point(center_lng, center_lat)::geography,
        radius_meters
    ) OR ST_DWithin(
        pm.partner_location,
        ST_Point(center_lng, center_lat)::geography,
        radius_meters
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to update user location
CREATE OR REPLACE FUNCTION update_user_location(
    lat FLOAT,
    lng FLOAT,
    accuracy FLOAT DEFAULT NULL
)
RETURNS VOID AS $$
BEGIN
    INSERT INTO user_locations (user_id, current_location, location_accuracy, last_updated)
    VALUES (
        auth.uid(),
        ST_Point(lng, lat)::geography,
        accuracy,
        NOW()
    )
    ON CONFLICT (user_id)
    DO UPDATE SET
        current_location = ST_Point(lng, lat)::geography,
        location_accuracy = COALESCE(accuracy, user_locations.location_accuracy),
        last_updated = NOW();
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create pulse match with locations
CREATE OR REPLACE FUNCTION create_pulse_match(
    partner_user_id UUID,
    user_lat FLOAT,
    user_lng FLOAT,
    partner_lat FLOAT,
    partner_lng FLOAT
)
RETURNS UUID AS $$
DECLARE
    new_match_id UUID;
BEGIN
    INSERT INTO pulse_matches (
        user_id,
        partner_id,
        user_location,
        partner_location
    ) VALUES (
        auth.uid(),
        partner_user_id,
        ST_Point(user_lng, user_lat)::geography,
        ST_Point(partner_lng, partner_lat)::geography
    ) RETURNING id INTO new_match_id;
    
    RETURN new_match_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to update the updated_at column
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_pulse_matches_updated_at
    BEFORE UPDATE ON pulse_matches
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Real-time subscriptions setup
-- Enable real-time for the tables
ALTER PUBLICATION supabase_realtime ADD TABLE pulse_matches;
ALTER PUBLICATION supabase_realtime ADD TABLE user_locations;
ALTER PUBLICATION supabase_realtime ADD TABLE pulse_history; 