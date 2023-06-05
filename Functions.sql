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

CREATE OR REPLACE FUNCTION public.get_signature_data(user_account_id INTEGER, sig_transaction_id INTEGER)
RETURNS TABLE (ethereum_address TEXT, valid_till SMALLINT, nonce INTEGER, tokens INTEGER[][])
SECURITY DEFINER
LANGUAGE plpgsql
AS
$func$
BEGIN
	RETURN QUERY
	SELECT A.ethereum_address, T.valid_till, T.nonce, array_agg(ARRAY[TT.token_id, TT.amount]) AS tokens
	FROM public.transaction T
	JOIN public.account A ON A.account_id = T.account_id
	JOIN public.transaction_token TT ON TT.transaction_id = T.transaction_id
	WHERE T.transaction_id = sig_transaction_id AND T.account_id = user_account_id
	GROUP BY A.ethereum_address, T.nonce, T.valid_till;
END;
$func$;