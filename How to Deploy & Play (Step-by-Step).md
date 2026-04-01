1/ Install Aptos CLI → curl -fsSL https://aptos.dev/install-cli.sh | sh
2/ aptos move init --name shelby_warrior
3/ Publish (on testnet) :
aptos move publish --named-addresses shelby_warrior=<YOUR_PUBLISHER_ADDRESS> --url https://api.testnet.aptoslabs.com
4/ Mint a warrior (costs 1 APT):
aptos move run --function-id <YOUR_ADDRESS>::shelby_warrior::warrior_game::mint_warrior --args string:"ShadowBlade" u64:85 u64:70 u64:100 string:"https://api.shelbynet.shelby.xyz/..." --private-key <YOUR_KEY>
5/ Battle:
aptos move run --function-id <YOUR_ADDRESS>::shelby_warrior::warrior_game::battle --args address:<DEFENDER_ADDRESS>

