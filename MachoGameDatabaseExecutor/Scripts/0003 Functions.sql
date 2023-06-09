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
RETURNS TABLE (ethereum_address CHARACTER VARYING(42), valid_till INTEGER, nonce INTEGER, tokens JSON[])
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

SELECT * FROM public.get_transaction_data(1, 3);

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

CREATE OR REPLACE FUNCTION public.view_transactions(user_account_id INTEGER, date timestamp(0) with time zone, page SMALLINT, page_size SMALLINT, filter_pending BOOLEAN, filter_confirmed BOOLEAN)
RETURNS TABLE (created_on timestamp(0) with time zone, completed_on timestamp(0) with time zone, tokens JSON[], pending BOOLEAN, confirmed BOOLEAN, transaction_id INTEGER)
SECURITY DEFINER
LANGUAGE plpgsql
AS
$func$
BEGIN
	RETURN QUERY
	SELECT T.created_on, T.redeemed_on, array_agg(json_build_object('tokenId', TT.token_id, 'amount', TT.amount)) AS tokens, T.is_pending, T.is_confirmed, T.transaction_id
	FROM public.transaction T
	JOIN public.transaction_token TT ON TT.transaction_id = T.transaction_id
	WHERE T.account_id = user_account_id AND (filter_pending IS NULL OR T.is_pending = filter_pending) 
	AND (filter_confirmed IS NULL OR filter_confirmed = T.is_confirmed) AND T.created_on <= date
	GROUP BY T.created_on, T.redeemed_on, T.is_pending, T.is_confirmed, T.transaction_id
	ORDER BY T.created_on DESC
	OFFSET (page * page_size) ROWS
	FETCH FIRST page_size ROW ONLY;
END;
$func$;

SELECT * FROM public.view_transactions(1, current_timestamp, 0::SMALLINT, 20::SMALLINT, NULL::BOOLEAN, NULL::BOOLEAN);

CREATE OR REPLACE FUNCTION public.view_pending_transactions(user_account_id INTEGER)
RETURNS TABLE (created_on timestamp(0) with time zone, tokens INTEGER[][], transaction_id INTEGER)
SECURITY DEFINER
LANGUAGE plpgsql
AS
$func$
BEGIN
	RETURN QUERY
	SELECT T.created_on, array_agg(ARRAY[TT.token_id, TT.amount]) AS tokens, T.transaction_id
	FROM public.transaction T
	JOIN public.transaction_token TT ON TT.transaction_id = T.transaction_id
	WHERE T.account_id = 1 AND T.is_pending = TRUE
	GROUP BY T.created_on, T.redeemed_on,  T.transaction_id;
END;
$func$;

SELECT * FROM public.view_pending_transactions(1);

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

SELECT * FROM public.view_user_tokens(1);

CREATE OR REPLACE FUNCTION public.view_token_metadata()
RETURNS TABLE (tokens JSON)
SECURITY DEFINER
LANGUAGE plpgsql
AS
$func$
BEGIN
	RETURN QUERY
	SELECT json_object_agg(T.token_id, json_build_object('name', T.name, 'image', T.image, 'type', TT.type, 'colors', json_build_object('borderColor', CC.border_color, 'fillColor', CC.fill_color)))
	FROM public.token T
	JOIN public.token_type TT ON TT.token_type_id = T.token_type_id
	LEFT JOIN public.coin_colors CC ON CC.coin_colors_id = T.coin_colors_id;
END;
$func$;

SELECT * FROM public.view_token_metadata();

CREATE OR REPLACE FUNCTION public.get_reclaim_info(reclaim_transaction_id INTEGER)
RETURNS TABLE (valid_till INTEGER, account_id INTEGER, account_address CHARACTER VARYING(42), is_pending BOOLEAN, nonce INTEGER)
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

CREATE OR REPLACE FUNCTION public.get_user_details("name" CHARACTER VARYING(30))
RETURNS TABLE (account_id INTEGER, hashed_password TEXT, jwt TEXT, expire_date timestamp(0) with time zone, address CHARACTER VARYING(42))
SECURITY DEFINER
LANGUAGE plpgsql
AS
$func$
BEGIN
	RETURN QUERY
	SELECT A.account_id, A.hashed_password, S.jwt, S.expire_date, A.ethereum_address
	FROM public.account A
	LEFT JOIN public.session S ON S.account_id = A.account_id
	WHERE A.user_name = "name";
END;
$func$;

SELECT * FROM public.get_user_details('MachoKat');

CREATE OR REPLACE FUNCTION public.check_address_existence(address CHARACTER VARYING(42))
RETURNS TABLE (does_exist BOOLEAN)
SECURITY DEFINER
LANGUAGE plpgsql
AS
$func$
BEGIN
	IF EXISTS (SELECT 1 FROM public.account A WHERE A.ethereum_address ILIKE address) THEN
		RETURN QUERY
		SELECT true;
	ELSE
		RETURN QUERY
		SELECT false;
	END IF;
END;
$func$;

CREATE OR REPLACE FUNCTION public.get_ethereum_account(address CHARACTER VARYING(42))
RETURNS TABLE (account_id INTEGER, user_name CHARACTER VARYING(30))
SECURITY DEFINER
LANGUAGE plpgsql
AS
$func$
BEGIN
	RETURN QUERY
	SELECT A.account_id, A.user_name
	FROM public.account A
	WHERE A.ethereum_address ILIKE address;
END;
$func$;

SELECT * FROM public.get_ethereum_account('0x0e955494A2936501793119fFB66f901Ca2B11Aac');

CREATE OR REPLACE FUNCTION public.get_account_info(user_account_id INTEGER)
RETURNS TABLE (user_name CHARACTER VARYING(30), address CHARACTER VARYING(42), expire_date timestamp(0) with time zone)
SECURITY DEFINER
LANGUAGE plpgsql
AS
$func$
BEGIN
	RETURN QUERY
	SELECT A.user_name, A.ethereum_address, S.expire_date
	FROM public.account A
	LEFT JOIN public.session S ON S.account_id = A.account_id
	WHERE A.account_id = user_account_id;
END
$func$;

SELECT * FROM public.get_account_info(1);

CREATE OR REPLACE FUNCTION public.is_active_user_name("name" CHARACTER VARYING(30))
RETURNS TABLE (is_active BOOLEAN)
SECURITY DEFINER
LANGUAGE plpgsql
AS
$func$
BEGIN
	IF EXISTS (SELECT 1 FROM public.account A WHERE A.user_name = "name") THEN
		RETURN QUERY
		SELECT true;
	ELSE
		RETURN QUERY
		SELECT false;
	END IF;
END
$func$;

SELECT * FROM public.is_active_user_name('MachoKa');