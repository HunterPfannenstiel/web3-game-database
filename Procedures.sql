CREATE OR REPLACE PROCEDURE public.create_account(user_email TEXT, user_ethereum_address TEXT, OUT new_account_id INTEGER)
SECURITY DEFINER
LANGUAGE plpgsql
AS
$$
BEGIN
	INSERT INTO public.account(email, ethereum_address)
	VALUES(user_email, user_ethereum_address)
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

CREATE OR REPLACE PROCEDURE public.mint_tokens_to_blockchain(user_account_id INTEGER, tokens JSON, mint_valid_till SMALLINT, OUT next_nonce INTEGER)
SECURITY DEFINER
LANGUAGE plpgsql
AS
$$
DECLARE address TEXT;
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
	
	INSERT INTO public.transaction(account_id, valid_till, nonce)
	VALUES (user_account_id, mint_valid_till, next_nonce)
	RETURNING transaction_id INTO new_transaction_id;
	
	INSERT INTO public.transaction_token(transaction_id, token_id, amount)
	SELECT new_transaction_id, tb.token_id, tb.amount * -1
	FROM public.unnest_tokens(tokens) tb;
END;
$$;