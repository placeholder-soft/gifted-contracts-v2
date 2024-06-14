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

```
forge script script/deploy.sepolia.s.sol -vvvv --rpc-url sepolia --broadcast --verify
```

## Addresses

### [Sepolia](https://sepolia.etherscan.io/)

| ContractName                      | Address                                    |
| --------------------------------- | ------------------------------------------ |
| UnifiedStore                      | 0xA436364dAFb5388f4756Cd334E41948a3F8BfF1d |
| GiftedAccountGuardian             | 0x88b4388b261B31F858A5AC5B707c4F857A9792E4 |
| GiftedAccount(IMPL)               | 0x6ac2fe2DB1aDF6Be4fE129CFB1EE17511aBf097B |
| GiftedAccount(GiftedAccountProxy) | 0x2493fFeE55B3262616461E9E72C354073dAeCDED |
| GiftedBox(IMPL)                   | 0xf28a59cB5576D404D74E779CB9CDe233cf5871B7 |
| GiftedBox                         | 0x5bf1AD25950bED502F56f61c2Fd4369c59D919A0 |
| ERC6551Registry                   | 0x20A63B1532649FE80c9Df43fb827c155447fD75E |
| Vault                             | 0xA00D0F5074e7565D5a71893396e19D19aa1f4629 |
| GasSponsorBook                    | 0x11d0E669D24F682F7690fDf5407B20287050a74A |

### [Base Sepolia](https://sepolia.basescan.org/)

| ContractName                      | Address                                    |
| --------------------------------- | ------------------------------------------ |
| UnifiedStore                      | 0x49BB830d9FD2E877Be6b4C5564bBf245F2179fD9 |
| GiftedAccountGuardian             | 0x06218F2deD0AA802001D8C93765a37Fc054eb62E |
| GiftedAccount(IMPL)               | 0x20cb3200762ddDE5c502065dF805538D707DA76c |
| GiftedAccount(GiftedAccountProxy) | 0xaC81a402efE13A12Da7421cff57c639054222126 |
| ERC6551Registry                   | 0x60f1D5BC00E85ad6bf3899A244aefe71f56a0796 |
| GiftedBox(IMPL)                   | 0x58D532e4CD220b1e5ae6f78F37731cf4632f6960 |
| GiftedBox                         | 0x3425f33402D2f5E4d276a8E8653866c8afa0B9Af |
| Vault                             | 0x91E5503C2924F0536353343f455628A18CceDC16 |
| GasSponsorBook                    | 0x5C9d46832e29b1ec5972f144773Ef13afc93eA76 |

### [Arbitrum Sepolia](https://sepolia.arbiscan.io/)

| ContractName                      | Address                                    |
| --------------------------------- | ------------------------------------------ |
| UnifiedStore                      | 0xd62Df558426c7A37DCdA006B83362B610423484b |
| GiftedAccountGuardian             | 0x7C9612ed0716CC48474AcB908B4766239709d6A0 |
| GiftedAccount(IMPL)               | 0x709c1743aaDa8657eb1928955D48684AbC1337FA |
| GiftedAccount(GiftedAccountProxy) | 0xB765c1801dB3712d0330b83585496D27Fac01420 |
| ERC6551Registry                   | 0xF0401c57Ff0Cb78Af5340dA8ABf79f7B1D9b4A50 |
| GiftedBox(IMPL)                   | 0x8431483c91C856DCe2D8e07aD5B1b587Ad5df44D |
| GiftedBox                         | 0x890f8F066b6C6946D220623d6cb36b2930B80c44 |
| Vault                             | 0xF9aE127989ec2C8d683a0605a6dEc973f4B57d9b |
| GasSponsorBook                    | 0x75260D56366fBa5933CB56efd5F671331fF9B6C5 |
