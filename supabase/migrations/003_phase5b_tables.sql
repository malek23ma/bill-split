-- Settlements (pending confirmation flow)
CREATE TABLE settlements (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  from_member_id UUID NOT NULL REFERENCES members(id),
  to_member_id UUID NOT NULL REFERENCES members(id),
  amount DOUBLE PRECISION NOT NULL,
  status TEXT NOT NULL DEFAULT 'pending',
  created_by_user_id UUID NOT NULL REFERENCES auth.users(id),
  confirmed_at TIMESTAMPTZ,
  rejected_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Notifications
CREATE TABLE notifications (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  household_id UUID REFERENCES households(id) ON DELETE CASCADE,
  recipient_user_id UUID NOT NULL REFERENCES auth.users(id),
  sender_user_id UUID REFERENCES auth.users(id),
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  data JSONB DEFAULT '{}',
  read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Device tokens for FCM push
CREATE TABLE device_tokens (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  fcm_token TEXT NOT NULL,
  device_id TEXT NOT NULL,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id, device_id)
);

-- Household invites
CREATE TABLE household_invites (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  household_id UUID NOT NULL REFERENCES households(id) ON DELETE CASCADE,
  invited_by_user_id UUID NOT NULL REFERENCES auth.users(id),
  invite_code TEXT NOT NULL UNIQUE,
  member_id UUID REFERENCES members(id),
  invited_email TEXT,
  invited_phone TEXT,
  expires_at TIMESTAMPTZ NOT NULL,
  claimed_by_user_id UUID REFERENCES auth.users(id),
  claimed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Trigger for updated_at
CREATE TRIGGER settlements_updated_at BEFORE UPDATE ON settlements FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- RLS
ALTER TABLE settlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE household_invites ENABLE ROW LEVEL SECURITY;

-- Settlements: household members can read/create/update
CREATE POLICY "Members can read settlements" ON settlements FOR SELECT USING (is_household_member(household_id));
CREATE POLICY "Members can create settlements" ON settlements FOR INSERT WITH CHECK (is_household_member(household_id));
CREATE POLICY "Members can update settlements" ON settlements FOR UPDATE USING (is_household_member(household_id));

-- Notifications: users can read/update/delete their own, anyone authenticated can insert
CREATE POLICY "Users can read own notifications" ON notifications FOR SELECT USING (auth.uid() = recipient_user_id);
CREATE POLICY "Users can insert notifications" ON notifications FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "Users can update own notifications" ON notifications FOR UPDATE USING (auth.uid() = recipient_user_id);
CREATE POLICY "Users can delete own notifications" ON notifications FOR DELETE USING (auth.uid() = recipient_user_id);

-- Device tokens: users manage their own
CREATE POLICY "Users can manage own tokens" ON device_tokens FOR ALL USING (auth.uid() = user_id);

-- Household invites: admin can manage, authenticated users can read by code
CREATE POLICY "Admin can manage invites" ON household_invites FOR ALL USING (
  is_household_admin(household_id) OR claimed_by_user_id = auth.uid()
);
CREATE POLICY "Anyone can read invite by code" ON household_invites FOR SELECT USING (auth.uid() IS NOT NULL);
