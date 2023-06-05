DROP TABLE IF EXISTS public.transaction_token;
DROP TABLE IF EXISTS public.transaction;
DROP TABLE IF EXISTS public.token_balance;
DROP TABLE IF EXISTS public.token;
DROP TABLE IF EXISTS public.account;

DROP PROCEDURE IF EXISTS public.create_account;
DROP PROCEDURE IF EXISTS public.modify_balance;
DROP PROCEDURE IF EXISTS public.retrieve_and_increment_next_user_nonce;
DROP PROCEDURE IF EXISTS public.mint_tokens_to_blockchain;

DROP FUNCTION IF EXISTS public.unnest_tokens;
DROP FUNCTION IF EXISTS public.get_signature_data;