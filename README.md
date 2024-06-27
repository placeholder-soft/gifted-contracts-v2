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

## Addresses - Dev

### [Sepolia - Dev](https://sepolia.etherscan.io/)

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

### [Base Sepolia - Dev](https://sepolia.basescan.org/)

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

### [Arbitrum Sepolia - Dev](https://sepolia.arbiscan.io/)

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

## Address - Staging

### [Sepolia - Staging](https://sepolia.etherscan.io/)

| ContractName                      | Address                                    |
| --------------------------------- | ------------------------------------------ |
| MockERC721                        | 0x9C8Ceb75b4657DAa931fb1b0D8EC9800155C5f7f |
| MockERC1155                       | 0x60f33F5C9A0E02491aA7b5b35E0ffdeE073D1e6A |
| GiftedAccountGuardian             | 0xfe4BCdbDC3fd3Db643c4acB2b9d4A4d34354f623 |
| GiftedAccount(IMPL)               | 0xD685C8d9D48e65311Af1c2cAE6d40367b834a94E |
| GiftedAccount(GiftedAccountProxy) | 0xB34927f8EF1C2E70aAE0b59477cBc9C52c3f959A |
| ERC6551Registry                   | 0xcE59CEedFa2F96069F46e7cE1A0652C9268fB24a |
| GiftedBox(IMPL)                   | 0x42575CA286C036A32B378ee80F186dFE4b8f63af |
| GiftedBox                         | 0xeaAE38B765c5509132c9B3c4a757bBd857fe3536 |
| Vault                             | 0xe6121F29A58f235c1c12837fACE0f9419411F402 |
| GasSponsorBook                    | 0x01b793FDf3d21d8C9cD52De3aD5B50c5c95009A3 |
| UnifiedStore                      | 0x09748F6411a4D1A84a87645A3E406dCb3c31Fc73 |

### [Arbitrum Sepolia - Staging](https://sepolia.arbiscan.io/)

| ContractName                      | Address                                    |
| --------------------------------- | ------------------------------------------ |
| MockERC721                        | 0x0CBaFa7D94f7b7DB447BBD45E23eC12e177F14e9 |
| MockERC1155                       | 0x6b5AB9FfC094EC74121424Ca3d9bE848cC8d4Eb0 |
| GiftedAccountGuardian             | 0xB4Bb45Fe7595105fdB425A9e024CfDEADF321EF6 |
| GiftedAccount(IMPL)               | 0x01342877506d721765E918dc25DfC7201AF02001 |
| GiftedAccount(GiftedAccountProxy) | 0xFD52a038021976e84564C78EB5d2b0B8a4509333 |
| GiftedBox(IMPL)                   | 0x23Fd4D02E3e0b3cDFb2e851aE42Fd8bebE2EB7E9 |
| GiftedBox                         | 0x8f0ad7Db5be7ad0ab5A4F9BC08Fc8FBAa4952773 |
| Vault                             | 0xEdc199d7a4de25511C44aA85f6E5B794A21c1704 |
| GasSponsorBook                    | 0xfaA1e72f8609A86F7cEbbaDa0719FaC617D67e18 |
| ERC6551Registry                   | 0xF54930B90b5844fD976eE6EFE1cc3640c0742863 |
| UnifiedStore                      | 0x9Ce09649451616733844b77a5d67FF2E467d2A14 |

### [Base Sepolia - Staging](https://sepolia.basescan.org)

| ContractName                      | Address                                    |
| --------------------------------- | ------------------------------------------ |
| MockERC721                        | 0x44d0600DA8f30716001cb2233d39B01a346Cc6Ea |
| MockERC1155                       | 0xBA10494cF2d2293774603bfD882c30A12E5c0511 |
| GiftedAccountGuardian             | 0x40Dba44E7d95affF4BC8afa349393f26c8f61da6 |
| GiftedAccount(IMPL)               | 0xE9E578157dD683B0A2C0De91A1DBCcb792F8E82E |
| GiftedAccount(GiftedAccountProxy) | 0xeDc1452817e8bDAe482D6D026c07C77f2053b693 |
| ERC6551Registry                   | 0x1ffdaf9a2561c0CbCC13F3fca6381A0E060Af66E |
| GiftedBox(IMPL)                   | 0xC3fe2527373f42cB089CCB4Bb3a3B20ad6dBD6a7 |
| GiftedBox                         | 0x384C26db13269BB3215482F9B932371e4803B29f |
| Vault                             | 0x95c566AB7A776314424364D1e2476399167b916c |
| GasSponsorBook                    | 0xa80F5B8d1126D7A2eB1cE271483cF70bBb4e6e0A |
| UnifiedStore                      | 0x6ac2fe2DB1aDF6Be4fE129CFB1EE17511aBf097B |

## Address - Prod

### [Base](https://basescan.org)

| ContractName                      | Address                                    |
| --------------------------------- | ------------------------------------------ |
| UnifiedStore                      | 0xc45f19217e064EcE272e55EE7aAD36cc91e7ADA3 |
| GiftedAccountGuardian             | 0x1fee122930BB09D400FeF0f0Fb9d1BDBbce14268 |
| GiftedAccount(GiftedAccountProxy) | 0x07Ed52c878BaBDC959DcbADa1731925fE0b55Af6 |
| GiftedBox(ERC1967Proxy)           | 0xe52a9CeCdCE5e66e283D355491c12166c3aD6d7d |
| Vault                             | 0xA473098eD8d7f94A18E0B7A0d0C15b6750b4dbDe |
| GasSponsorBook                    | 0xbec73A3ed80216efbc5203DC014F183F582E97c0 |
| ERC6551Registry                   | 0x44E106e4860DFA345D4D45997124019696fDA44f |
