-- PostgreSQL foundation for server-only persistence. Never expose this database to the browser.
CREATE SCHEMA IF NOT EXISTS arenaplay;
REVOKE ALL ON SCHEMA arenaplay FROM PUBLIC;
SET search_path = arenaplay, public;

CREATE TABLE users (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  nickname text NOT NULL UNIQUE CHECK (length(nickname) BETWEEN 2 AND 30),
  email_lookup_hash bytea NOT NULL UNIQUE,
  email_ciphertext bytea NOT NULL,
  phone_ciphertext bytea NOT NULL,
  status text NOT NULL DEFAULT 'active' CHECK (status IN ('active','locked','deleted')),
  created_at timestamptz NOT NULL DEFAULT now()
);

-- PII and PIX keys are encrypted by the application using a KMS-managed key.
-- The browser receives neither ciphertext nor plaintext payout keys.
CREATE TABLE payout_accounts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id),
  pix_key_ciphertext bytea NOT NULL,
  pix_key_fingerprint bytea NOT NULL,
  key_type text NOT NULL CHECK (key_type IN ('cpf','email','phone','random')),
  verified_at timestamptz,
  disabled_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE score_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id),
  round_id uuid NOT NULL,
  idempotency_key text NOT NULL,
  points_delta integer NOT NULL CHECK (points_delta BETWEEN 0 AND 10000),
  accepted_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, idempotency_key)
);
CREATE INDEX score_events_rank_idx ON score_events (accepted_at DESC, user_id);

CREATE VIEW ranking_scores AS
  SELECT u.id AS user_id, u.nickname, COALESCE(sum(s.points_delta), 0)::bigint AS points
  FROM users u LEFT JOIN score_events s ON s.user_id = u.id
  WHERE u.status = 'active'
  GROUP BY u.id, u.nickname;

CREATE TABLE wallet_ledger (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id),
  idempotency_key text NOT NULL,
  entry_type text NOT NULL CHECK (entry_type IN ('credit','withdrawal_reserve','withdrawal_release','withdrawal_paid','adjustment')),
  amount_cents bigint NOT NULL CHECK (amount_cents <> 0),
  withdrawal_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, idempotency_key)
);
CREATE INDEX wallet_ledger_user_idx ON wallet_ledger (user_id, created_at DESC);

CREATE TABLE withdrawals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES users(id),
  payout_account_id uuid NOT NULL REFERENCES payout_accounts(id),
  amount_cents bigint NOT NULL CHECK (amount_cents > 0),
  idempotency_key text NOT NULL,
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','under_review','approved','rejected','paid','failed')),
  reviewed_by uuid REFERENCES users(id),
  reviewed_at timestamptz,
  provider_reference text,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (user_id, idempotency_key)
);
CREATE INDEX withdrawals_queue_idx ON withdrawals (status, created_at);

CREATE TABLE audit_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  actor_user_id uuid REFERENCES users(id),
  action text NOT NULL,
  resource_type text NOT NULL,
  resource_id uuid,
  request_id text,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

REVOKE ALL ON ALL TABLES IN SCHEMA arenaplay FROM PUBLIC;
