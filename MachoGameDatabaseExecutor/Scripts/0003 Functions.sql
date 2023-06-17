CREATE OR REPLACE FUNCTION public.unnest_tokens(tokens JSON)
RETURNS TABLE (token_id INTEGER, amount INTEGER)
SECURITY DEFINER
LANGUAGE plpgsql
AS
$func$
BEGIN
	RETURN QUERY
	SELECT (details->>'tokenId')::INTEGER AS token_id, (details->>'amount')::INTEGER AS amount
	FROM json_array_elements(tokens) details;
END;
$func$;

CREATE OR REPLACE FUNCTION public.get_transaction_data(user_account_id INTEGER, sig_transaction_id INTEGER)
RETURNS TABLE (ethereum_address TEXT, valid_till INTEGER, nonce INTEGER, tokens JSON[])
SECURITY DEFINER
LANGUAGE plpgsql
AS
$func$
BEGIN
	RETURN QUERY
	SELECT A.ethereum_address, T.valid_till, T.nonce, array_agg(json_build_object('tokenId', TT.token_id, 'amount', TT.amount)) AS tokens
	FROM public.transaction T
	JOIN public.account A ON A.account_id = T.account_id
	JOIN public.transaction_token TT ON TT.transaction_id = T.transaction_id
	WHERE T.transaction_id = sig_transaction_id AND T.account_id = user_account_id
	GROUP BY A.ethereum_address, T.nonce, T.valid_till;
END;
$func$;

CREATE OR REPLACE FUNCTION public.view_successful_transactions(user_account_id INTEGER)
RETURNS TABLE (created_on timestamp(0) with time zone, redeemed_on timestamp(0) with time zone, tokens INTEGER[][])
SECURITY DEFINER
LANGUAGE plpgsql
AS
$func$
BEGIN
	RETURN QUERY
	SELECT T.created_on, T.redeemed_on, array_agg(ARRAY[TT.token_id, TT.amount]) AS tokens
	FROM public.transaction T
	JOIN public.transaction_token TT ON TT.transaction_id = T.transaction_id
	WHERE T.account_id = user_account_id AND T.is_confirmed = TRUE
	GROUP BY T.created_on, T.redeemed_on;
END;
$func$;

CREATE OR REPLACE FUNCTION public.view_pending_transactions(user_account_id INTEGER)
RETURNS TABLE (created_on timestamp(0) with time zone, tokens INTEGER[][])
SECURITY DEFINER
LANGUAGE plpgsql
AS
$func$
BEGIN
	RETURN QUERY
	SELECT T.created_on, array_agg(ARRAY[TT.token_id, TT.amount]) AS tokens
	FROM public.transaction T
	JOIN public.transaction_token TT ON TT.transaction_id = T.transaction_id
	WHERE T.account_id = user_account_id AND T.is_pending = TRUE
	GROUP BY T.created_on, T.redeemed_on;
END;
$func$;

CREATE OR REPLACE FUNCTION public.view_user_tokens(user_account_id INTEGER)
RETURNS TABLE ("tokenId" INTEGER, amount INTEGER)
SECURITY DEFINER
LANGUAGE plpgsql
AS
$func$
BEGIN
	RETURN QUERY
	SELECT TB.token_id AS "tokenId", TB.amount
	FROM public.token_balance TB
	WHERE account_id = user_account_id;
END;
$func$;

CREATE OR REPLACE FUNCTION public.get_reclaim_info(reclaim_transaction_id INTEGER)
RETURNS TABLE (valid_till INTEGER, account_id INTEGER, account_address TEXT, is_pending BOOLEAN, nonce INTEGER)
SECURITY DEFINER
LANGUAGE plpgsql
AS
$func$
BEGIN
	RETURN QUERY
	SELECT T.valid_till, T.account_id, A.ethereum_address, T.is_pending, T.nonce
	FROM public.transaction T
	JOIN public.account A ON A.account_id = T.account_id
	WHERE T.transaction_id = reclaim_transaction_id;
END;
$func$;