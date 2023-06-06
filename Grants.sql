GRANT EXECUTE ON FUNCTION public.get_transaction_data(user_account_id integer, sig_transaction_id integer) TO web3_api;

GRANT EXECUTE ON FUNCTION public.view_pending_transactions(user_account_id integer) TO web3_api;

GRANT EXECUTE ON FUNCTION public.view_successful_transactions(user_account_id integer) TO web3_api;

GRANT EXECUTE ON FUNCTION public.view_user_tokens(user_account_id integer) TO web3_api;

GRANT EXECUTE ON PROCEDURE public.confirm_transaction(IN address text, IN transaction_nonce integer) TO web3_api;

GRANT EXECUTE ON PROCEDURE public.create_account(IN user_email text, IN user_ethereum_address text, OUT new_account_id integer) TO web3_api;

GRANT EXECUTE ON PROCEDURE public.mint_tokens_to_blockchain(IN user_account_id integer, IN tokens json, IN mint_valid_till integer, OUT next_nonce integer, OUT address text) TO web3_api;

GRANT EXECUTE ON PROCEDURE public.reclaim_pending_transaction(IN user_account_id integer, IN user_transaction_id integer) TO web3_api;

GRANT EXECUTE ON PROCEDURE public.modify_balance(IN user_account_id integer, IN tokens json) TO web3_api;