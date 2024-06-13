# Gifted.art Contracts v2

## env explanation

```
# env switching is using forge wallet to deploy contracts
use [dev|local|prod]

# create key file
cast wallet i dev --private-key 0x000 --keystore-dir keystores/keys
```

`ETH_KEYSTORE` and `ETH_PASSWORD` is set by each `env/.env.[dev|local|prod]` to pick up correct key file and password file.

## Deploy

### sepolia

specify `--chain` to pickup etherscan key setting in `foundry.toml`

```
forge script --chain sepolia script/deploy.sepolia.s.sol -vvvv --rpc-url $SEPOLIA_RPC_URL --broadcast --verify
```

## Addresses

### [Sepolia](https://sepolia.etherscan.io/)

| ContractName                      | Address                                    |
| --------------------------------- | ------------------------------------------ |
| GiftedAccountGuardian             | 0x88b4388b261B31F858A5AC5B707c4F857A9792E4 |
| GiftedAccount(IMPL)               | 0x6ac2fe2DB1aDF6Be4fE129CFB1EE17511aBf097B |
| GiftedAccount(GiftedAccountProxy) | 0x2493fFeE55B3262616461E9E72C354073dAeCDED |
| GiftedBox(IMPL)                   | 0xf28a59cB5576D404D74E779CB9CDe233cf5871B7 |
| GiftedBox                         | 0x5bf1AD25950bED502F56f61c2Fd4369c59D919A0 |
| ERC6551Registry                   | 0x20A63B1532649FE80c9Df43fb827c155447fD75E |
| Vault                             | 0xA00D0F5074e7565D5a71893396e19D19aa1f4629 |
| GasSponsorBook                    | 0x11d0E669D24F682F7690fDf5407B20287050a74A |
