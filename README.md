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

### Zora

zora is using routescan for contract verification. official blockscout using instruction [here](https://docs.zora.co/zora-network/contracts) does not work yet.

```
forge script script/deploy.sepolia.s.sol -vvvv --rpc-url zora_sepolia --broadcast --verify --slow
```

## Addresses

The contract addresses for different environments and networks are defined in the following JSON configuration files:

- Development: [`config/dev_addresses.json`](./config/dev_addresses.json)
- Staging: [`config/staging_addresses.json`](./config/staging_addresses.json)
- Production: [`config/prod_addresses.json`](./config/prod_addresses.json)

Please refer to these files for the most up-to-date contract addresses for each network.