-- Migration 004: Production-ready RLS
-- Re-enables RLS on all tables and fixes policy gaps for production use.
--
-- Key fixes:
--   1. Members INSERT: restrict to self-registration or admin (was: any authenticated user)
--   2. Household invites: allow claiming by any authenticated user (was: blocked by admin-only UPDATE)
--   3. Profiles: allow INSERT for new user registration
--   4. Re-enable RLS on profiles table

-- ============================================================
-- Step 1: Ensure RLS is enabled on ALL tables
-- (These are idempotent — safe to run even if already enabled)
-- ============================================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE households ENABLE ROW LEVEL SECURITY;
ALTER TABLE members ENABLE ROW LEVEL SECURITY;
ALTER TABLE bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE bill_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE bill_item_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE recurring_bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE settlements ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE device_tokens ENABLE ROW LEVEL SECURITY;
ALTER TABLE household_invites ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- Step 2: Fix profiles — allow users to create their own profile
-- ============================================================
CREATE POLICY "Users can create own profile" ON profiles FOR INSERT
  WITH CHECK (auth.uid() = id);

-- ============================================================
-- Step 3: Fix members INSERT — was too permissive
-- Old: "is_household_admin(household_id) OR auth.uid() IS NOT NULL"
--   -> Any authenticated user could add a member to ANY household
-- New: Self-registration (user_id matches auth) OR admin of the household
-- ============================================================
DROP POLICY IF EXISTS "Admins can insert members" ON members;

CREATE POLICY "Users can insert members" ON members FOR INSERT
  WITH CHECK (
    user_id = auth.uid()                    -- self-registration (creating own member record)
    OR is_household_admin(household_id)     -- admin adding members to their household
  );

-- ============================================================
-- Step 4: Fix household invites — allow claiming
-- Old "Admin can manage invites" FOR ALL blocked non-admin updates.
-- Split into granular policies for clarity and correctness.
-- ============================================================
DROP POLICY IF EXISTS "Admin can manage invites" ON household_invites;

-- Admins can create invites for their household
CREATE POLICY "Admins can create invites" ON household_invites FOR INSERT
  WITH CHECK (is_household_admin(household_id));

-- Admins can delete/manage invites for their household
CREATE POLICY "Admins can delete invites" ON household_invites FOR DELETE
  USING (is_household_admin(household_id));

-- Any authenticated user can read invites (needed to look up invite codes)
-- Note: policy "Anyone can read invite by code" from migration 003 already covers this.
-- We keep that policy and don't duplicate it.

-- Any authenticated user can claim an unclaimed invite
CREATE POLICY "Users can claim invites" ON household_invites FOR UPDATE
  USING (
    auth.uid() IS NOT NULL          -- must be authenticated
    AND claimed_by_user_id IS NULL  -- invite not yet claimed
  )
  WITH CHECK (
    claimed_by_user_id = auth.uid() -- can only claim for yourself
  );

-- Admins can also update invites (e.g., revoke)
CREATE POLICY "Admins can update invites" ON household_invites FOR UPDATE
  USING (is_household_admin(household_id));
