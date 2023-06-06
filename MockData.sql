--Create accounts
CALL public.create_account('etherman@gmail.com'::TEXT, '0x0e955494A2936501793119fFB66f901Ca2B11Aac'::TEXT, NULL);

CALL public.create_account('jacobis@gmail.com'::TEXT, '0xb849aaa6dc8bbc499c89728ce16d26e33f86ac09'::TEXT, NULL);
--

--Create tokens
INSERT INTO public.token(token_id)
VALUES (1), (2), (3), (500);

--Update token amounts
CALL public.modify_balance(1, '[{"tokenId": 1, "amount": 1000}, {"tokenId": 2, "amount": 25}, {"tokenId": 3, "amount": 22}, {"tokenId": 500, "amount": 1}]');

CALL public.modify_balance(2, '[{"tokenId": 1, "amount": 900}, {"tokenId": 2, "amount": 500}, {"tokenId": 3, "amount": 10}, {"tokenId": 500, "amount": 2}]');
--

--Create mint transaction
CALL public.mint_tokens_to_blockchain(2, '[{"tokenId": 1, "amount": -900}, {"tokenId": 500, "amount": -1}]', 18000::SMALLINT, NULL);

CALL public.confirm_transaction('0xb849aaa6dc8bbc499c89728ce16d26e33f86ac09', 0);

SELECT token_id, amount
FROM public.transaction T
JOIN public.transaction_token TT ON TT.transaction_id = T.transaction_id
WHERE T.transaction_id = 1;

SELECT token_id, amount
FROM public.token_balance
WHERE account_id = 2;
--