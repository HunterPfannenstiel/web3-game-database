CREATE OR REPLACE PROCEDURE public.create_account(user_name CHARACTER VARYING(30), hashed_password TEXT, user_email TEXT, user_ethereum_address CHARACTER VARYING(42), OUT new_account_id INTEGER)
SECURITY DEFINER
LANGUAGE plpgsql
AS
$$
DECLARE is_name_in_use BOOLEAN;
BEGIN
	INSERT INTO public.account(user_name, hashed_password, email, ethereum_address)
	VALUES(user_name, hashed_password, user_email, user_ethereum_address)
	RETURNING account_id INTO new_account_id;
END;
$$;

--tokens: [{tokenId: number, amount: number}]
CREATE OR REPLACE PROCEDURE public.modify_balance(user_account_id INTEGER, tokens JSON)
SECURITY DEFINER
LANGUAGE plpgsql
AS
$$
BEGIN
	MERGE INTO public.token_balance T
	USING (SELECT * FROM public.unnest_tokens(tokens)) S ON (S.token_id = T.token_id AND T.account_id = user_account_id)
	WHEN MATCHED THEN
		UPDATE SET amount = T.amount + S.amount
	WHEN NOT MATCHED THEN
		INSERT (account_id, token_id, amount)
		VALUES (user_account_id, token_id, amount);
END;
$$;

CREATE OR REPLACE PROCEDURE public.retrieve_and_increment_next_user_nonce(user_account_id INTEGER, OUT nonce INTEGER)
SECURITY DEFINER
LANGUAGE plpgsql
AS
$$
BEGIN
	SELECT next_nonce INTO nonce
	FROM public.account A
	WHERE A.account_id = user_account_id;
	
	UPDATE public.account
	SET next_nonce = next_nonce + 1;
END;
$$;

CREATE OR REPLACE PROCEDURE public.mint_tokens_to_blockchain(user_account_id INTEGER, tokens JSON, mint_valid_till INTEGER, created_date timestamp(0) with time zone, OUT next_nonce INTEGER, OUT address TEXT)
SECURITY DEFINER
LANGUAGE plpgsql
AS
$$
DECLARE new_transaction_id INTEGER;
BEGIN
	SELECT ethereum_address INTO address
	FROM public.account A
	WHERE A.account_id = user_account_id;
	
	IF address IS NULL THEN
		RAISE EXCEPTION 'Please link an ethereum address to your account before minting tokens to the blockchain';
	END IF;
	
	CALL public.modify_balance(user_account_id, tokens);
	
	CALL public.retrieve_and_increment_next_user_nonce(user_account_id, next_nonce);
	
	INSERT INTO public.transaction(account_id, valid_till, nonce, created_on)
	VALUES (user_account_id, mint_valid_till, next_nonce, created_date)
	RETURNING transaction_id INTO new_transaction_id;
	
	INSERT INTO public.transaction_token(transaction_id, token_id, amount)
	SELECT new_transaction_id, tb.token_id, tb.amount * -1
	FROM public.unnest_tokens(tokens) tb;
END;
$$;

CREATE OR REPLACE PROCEDURE public.mint_tokens_from_blockchain(transactions JSON, minted_on timestamp(0) with time zone)
SECURITY DEFINER
LANGUAGE plpgsql
AS
$$
DECLARE user_account_id INTEGER;
DECLARE request JSON;
DECLARE mint_id INTEGER;
BEGIN
	FOR request IN SELECT * FROM json_array_elements(transactions)
	LOOP
		SELECT account_id INTO user_account_id 
		FROM public.account A
		WHERE A.ethereum_address = request->>'address';

		CALL public.modify_balance(user_account_id, (request->>'tokenInfo')::JSON);
		
		INSERT INTO public.game_mint(account_id, redeemed_on)
		VALUES (user_account_id, minted_on)
		RETURNING game_mint_id INTO mint_id;
		
		INSERT INTO public.game_mint_token(game_mint_id, token_id, amount)
		SELECT mint_id, tb.token_id, tb.amount
		FROM public.unnest_tokens((request->>'tokenInfo')::JSON) tb;
	END LOOP;
END;
$$;

CALL public.mint_tokens_from_blockchain('[
        {
            "address": "0x0e955494A2936501793119fFB66f901Ca2B11Aac",
            "tokenInfo": "[{\"tokenId\": 1, \"amount\": 20}, {\"tokenId\": 2, \"amount\": 20}]"
        },
        {
            "address": "0x0e955494A2936501793119fFB66f901Ca2B11Aac",
            "tokenInfo": "[{\"tokenId\": 1, \"amount\": 20}, {\"tokenId\": 2, \"amount\": 20}]"
        }
    ]'::JSON, current_timestamp);

CREATE OR REPLACE PROCEDURE public.reclaim_pending_transaction(user_account_id INTEGER, user_transaction_id INTEGER, reclaim_date timestamp(0) with time zone)
SECURITY DEFINER
LANGUAGE plpgsql
AS
$$
DECLARE tokens JSON;
BEGIN
	SELECT json_agg(json_build_object('tokenId', TT.token_id, 'amount', TT.amount)) INTO tokens
	FROM public.transaction_token TT
	JOIN public.transaction T ON T.transaction_id = TT.transaction_id
	WHERE TT.transaction_id = user_transaction_id AND T.account_id = user_account_id AND is_pending = TRUE AND is_confirmed = FALSE;
	
	UPDATE public.transaction
	SET is_pending = FALSE, redeemed_on = reclaim_date
	WHERE transaction_id = user_transaction_id;
	
	CALL public.modify_balance(user_account_id, tokens);
END;
$$;

CREATE OR REPLACE PROCEDURE public.confirm_transaction(address TEXT, transaction_nonce INTEGER, redeem_timestamp timestamp(0) with time zone)
SECURITY DEFINER
LANGUAGE plpgsql
AS
$$
DECLARE address_account_id INTEGER;
BEGIN
	SELECT account_id INTO address_account_id
	FROM public.account A
	WHERE A.ethereum_address ILIKE address;
	
	UPDATE public.transaction
	SET is_pending = FALSE, is_confirmed = TRUE, redeemed_on = redeem_timestamp
	WHERE account_id = address_account_id AND nonce = transaction_nonce;
END;
$$;

CREATE OR REPLACE PROCEDURE public.create_session(account_id INTEGER, jwt TEXT, expire_date timestamp(0) with time zone)
SECURITY DEFINER
LANGUAGE plpgsql
AS
$$
DECLARE address_account_id INTEGER;
BEGIN
	MERGE INTO public.session T
	USING (SELECT account_id, jwt, expire_date) S ON S.account_id = T.account_id
	WHEN MATCHED THEN
		UPDATE SET jwt = S.jwt, expire_date = S.expire_date
	WHEN NOT MATCHED THEN
		INSERT (account_id, jwt, expire_date)
		VALUES(S.account_id, S.jwt, S.expire_date);
END;
$$;

CREATE OR REPLACE PROCEDURE public.delete_session(user_account_id INTEGER)
SECURITY DEFINER
LANGUAGE plpgsql
AS
$$
DECLARE address_account_id INTEGER;
BEGIN
	DELETE FROM public.session
	WHERE account_id = user_account_id; 
END;
$$;

CREATE OR REPLACE PROCEDURE public.link_ethereum_address(user_account_id INTEGER, address CHARACTER VARYING(42))
SECURITY DEFINER
LANGUAGE plpgsql
AS
$$
DECLARE address_exists BOOLEAN;
BEGIN
	SELECT CAE.does_exist INTO address_exists 
	FROM public.check_address_existence(address) CAE;
	
	IF address_exists THEN
		RAISE EXCEPTION 'Ethereum address is already linked to an account!';
	END IF;
	
	IF EXISTS (SELECT 1 FROM public.account A WHERE A.account_id = user_account_id AND A.ethereum_address IS NOT NULL) THEN
		RAISE EXCEPTION 'An ethereum address is already linked to account %!', user_account_id;
	END IF;
	
	UPDATE public.account
		SET ethereum_address = address
	WHERE account_id = user_account_id;
END;
$$;