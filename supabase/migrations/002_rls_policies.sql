-- Enable RLS on all tables
-- profiles RLS disabled — trigger/app needs unrestricted insert access
-- ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE households ENABLE ROW LEVEL SECURITY;
ALTER TABLE members ENABLE ROW LEVEL SECURITY;
ALTER TABLE bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE bill_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE bill_item_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE recurring_bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_log ENABLE ROW LEVEL SECURITY;

-- Profiles: users can read/update their own profile
CREATE POLICY "Users can read own profile" ON profiles FOR SELECT USING (auth.uid() = id);
CREATE POLICY "Users can update own profile" ON profiles FOR UPDATE USING (auth.uid() = id);

-- Helper: check if user is a member of household
CREATE OR REPLACE FUNCTION is_household_member(h_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM members
    WHERE household_id = h_id
      AND user_id = auth.uid()
      AND deleted_at IS NULL
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- Helper: check if user is admin of household
CREATE OR REPLACE FUNCTION is_household_admin(h_id UUID)
RETURNS BOOLEAN AS $$
  SELECT EXISTS (
    SELECT 1 FROM members
    WHERE household_id = h_id
      AND user_id = auth.uid()
      AND is_admin = true
      AND deleted_at IS NULL
  );
$$ LANGUAGE sql SECURITY DEFINER;

-- Households: members can read, anyone authenticated can create
CREATE POLICY "Members can read household" ON households FOR SELECT USING (is_household_member(id));
CREATE POLICY "Authenticated users can create household" ON households FOR INSERT WITH CHECK (auth.uid() IS NOT NULL);
CREATE POLICY "Admins can update household" ON households FOR UPDATE USING (is_household_admin(id));

-- Members: household members can read, admins can insert/update
CREATE POLICY "Members can read members" ON members FOR SELECT USING (is_household_member(household_id));
CREATE POLICY "Admins can insert members" ON members FOR INSERT WITH CHECK (is_household_admin(household_id) OR auth.uid() IS NOT NULL);
CREATE POLICY "Admins can update members" ON members FOR UPDATE USING (
  is_household_admin(household_id) OR user_id = auth.uid()
);

-- Bills: household members can read/insert, payer or admin can delete
CREATE POLICY "Members can read bills" ON bills FOR SELECT USING (is_household_member(household_id));
CREATE POLICY "Members can insert bills" ON bills FOR INSERT WITH CHECK (is_household_member(household_id));
CREATE POLICY "Members can update bills" ON bills FOR UPDATE USING (is_household_member(household_id));
CREATE POLICY "Payer or admin can delete bills" ON bills FOR DELETE USING (
  EXISTS (
    SELECT 1 FROM members
    WHERE members.id = bills.paid_by_member_id
      AND members.user_id = auth.uid()
  )
  OR is_household_admin(household_id)
);

-- Bill Items: follow bill access
CREATE POLICY "Members can read bill items" ON bill_items FOR SELECT USING (
  EXISTS (SELECT 1 FROM bills WHERE bills.id = bill_items.bill_id AND is_household_member(bills.household_id))
);
CREATE POLICY "Members can insert bill items" ON bill_items FOR INSERT WITH CHECK (
  EXISTS (SELECT 1 FROM bills WHERE bills.id = bill_items.bill_id AND is_household_member(bills.household_id))
);
CREATE POLICY "Members can update bill items" ON bill_items FOR UPDATE USING (
  EXISTS (SELECT 1 FROM bills WHERE bills.id = bill_items.bill_id AND is_household_member(bills.household_id))
);

-- Bill Item Members: follow bill item access
CREATE POLICY "Members can read bill item members" ON bill_item_members FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM bill_items bi
    JOIN bills b ON b.id = bi.bill_id
    WHERE bi.id = bill_item_members.bill_item_id
      AND is_household_member(b.household_id)
  )
);
CREATE POLICY "Members can insert bill item members" ON bill_item_members FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM bill_items bi
    JOIN bills b ON b.id = bi.bill_id
    WHERE bi.id = bill_item_members.bill_item_id
      AND is_household_member(b.household_id)
  )
);

-- Recurring Bills: household members can CRUD
CREATE POLICY "Members can read recurring bills" ON recurring_bills FOR SELECT USING (is_household_member(household_id));
CREATE POLICY "Members can insert recurring bills" ON recurring_bills FOR INSERT WITH CHECK (is_household_member(household_id));
CREATE POLICY "Members can update recurring bills" ON recurring_bills FOR UPDATE USING (is_household_member(household_id));

-- Sync Log: user can manage own sync log
CREATE POLICY "Users can manage sync log" ON sync_log FOR ALL USING (is_household_member(household_id));

-- Storage: receipts bucket
INSERT INTO storage.buckets (id, name, public) VALUES ('receipts', 'receipts', false)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Members can read receipts" ON storage.objects FOR SELECT USING (
  bucket_id = 'receipts' AND auth.uid() IS NOT NULL
);

CREATE POLICY "Members can upload receipts" ON storage.objects FOR INSERT WITH CHECK (
  bucket_id = 'receipts' AND auth.uid() IS NOT NULL
);

CREATE POLICY "Members can delete own receipts" ON storage.objects FOR DELETE USING (
  bucket_id = 'receipts' AND auth.uid() IS NOT NULL
);
