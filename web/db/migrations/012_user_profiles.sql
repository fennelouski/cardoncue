-- Migration 012: Add user profiles with profile picture support

-- Create user_profiles table
CREATE TABLE IF NOT EXISTS user_profiles (
    id TEXT PRIMARY KEY,  -- Clerk user ID
    email TEXT,
    display_name TEXT,
    profile_picture_url TEXT,
    preferences JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Create index for email lookups
CREATE INDEX IF NOT EXISTS idx_user_profiles_email ON user_profiles(email);

-- Comments for documentation
COMMENT ON TABLE user_profiles IS 'User profile data synced from Clerk authentication';
COMMENT ON COLUMN user_profiles.id IS 'Clerk user ID';
COMMENT ON COLUMN user_profiles.email IS 'User email address from Clerk';
COMMENT ON COLUMN user_profiles.display_name IS 'User display name';
COMMENT ON COLUMN user_profiles.profile_picture_url IS 'URL to profile picture stored in Vercel blob storage';
COMMENT ON COLUMN user_profiles.preferences IS 'User preferences stored as JSON (theme, notifications, etc.)';
