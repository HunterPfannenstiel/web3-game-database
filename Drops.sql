DROP TABLE IF EXISTS public.transaction_token;
DROP TABLE IF EXISTS public.transaction;
DROP TABLE IF EXISTS public.token_balance;
DROP TABLE IF EXISTS public.token;
DROP TABLE IF EXISTS public.account;

DROP PROCEDURE IF EXISTS public.create_account;
DROP PROCEDURE IF EXISTS public.modify_balance;
DROP PROCEDURE IF EXISTS public.retrieve_and_increment_next_user_nonce;
DROP PROCEDURE IF EXISTS public.mint_tokens_to_blockchain;
DROP PROCEDURE IF EXISTS public.reclaim_pending_transaction;
DROP PROCEDURE IF EXISTS public.confirm_transaction;

DROP FUNCTION IF EXISTS public.unnest_tokens;
DROP FUNCTION IF EXISTS public.get_signature_data;
DROP FUNCTION IF EXISTS public.view_successful_transactions;
DROP FUNCTION IF EXISTS public.view_pending_transactions;
DROP FUNCTION IF EXISTS public.view_user_tokens;