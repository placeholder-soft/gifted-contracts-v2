// curl --request GET \
//      --url 'https://api.simplehash.com/api/v0/nfts/owners?chains=polygon,ethereum&wallet_addresses=0xfa6E0aDDF68267b8b6fF2dA55Ce01a53Fad6D8e2&limit=50' \
//      --header 'X-API-KEY: sh_sk1_Z4jhWXXBE09em' \
//      --header 'accept: application/json'

/*
resposne
{
  "next_cursor": "ZXZtLXBnLjB4NTM5YjQ2MjVmNWY0NTQ5OGI2ODk2OTYzMjRkNzI0NjM5NWY2MWY5Yy4wMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDE1ODJfMjAyMy0wNy0xNiAxMzo1MTo0NCswMDowMF9fbmV4dA",
  "next": "https://api.simplehash.com/api/v0/nfts/owners?chains=polygon%2Cethereum&chains=polygon%2Cethereum&cursor=ZXZtLXBnLjB4NTM5YjQ2MjVmNWY0NTQ5OGI2ODk2OTYzMjRkNzI0NjM5NWY2MWY5Yy4wMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDAwMDE1ODJfMjAyMy0wNy0xNiAxMzo1MTo0NCswMDowMF9fbmV4dA&limit=50&wallet_addresses=0xfa6E0aDDF68267b8b6fF2dA55Ce01a53Fad6D8e2&wallet_addresses=0xfa6E0aDDF68267b8b6fF2dA55Ce01a53Fad6D8e2",
  "previous": null,
  "nfts": [
    {
      "nft_id": "ethereum.0x5e5038c9f9a225a793a283c50ba8ba3300095561.0",
      "chain": "ethereum",
      "contract_address": "0x5e5038c9F9a225A793A283C50ba8Ba3300095561",
      "token_id": "0",
      "name": "Visit get-ens.org to claim rewards",
      "description": "Visit get-ens.org to claim rewards",
      "previews": {
        "image_small_url": "https://lh3.googleusercontent.com/oO1cKTQog3txc7k8bEVPXP1Oi-NWyuY0DSdpXu5en_GKYTIb4DJBgYq-glrkO715QmckQkpoguRgV_8bGUfUWE4tBJsyBdL8uRE=s250",
        "image_medium_url": "https://lh3.googleusercontent.com/oO1cKTQog3txc7k8bEVPXP1Oi-NWyuY0DSdpXu5en_GKYTIb4DJBgYq-glrkO715QmckQkpoguRgV_8bGUfUWE4tBJsyBdL8uRE",
        "image_large_url": "https://lh3.googleusercontent.com/oO1cKTQog3txc7k8bEVPXP1Oi-NWyuY0DSdpXu5en_GKYTIb4DJBgYq-glrkO715QmckQkpoguRgV_8bGUfUWE4tBJsyBdL8uRE=s1000",
        "image_opengraph_url": "https://lh3.googleusercontent.com/oO1cKTQog3txc7k8bEVPXP1Oi-NWyuY0DSdpXu5en_GKYTIb4DJBgYq-glrkO715QmckQkpoguRgV_8bGUfUWE4tBJsyBdL8uRE=k-w1200-s2400-rj",
        "blurhash": "Uc9Rq+ohMbbaRhtSkDV?I7W9tTe-t8acj=W?",
        "predominant_color": "#3b7cd0"
      },
      "image_url": "https://cdn.simplehash.com/assets/5c00b8ba2a00e7d40c5aad97be7730c99010cfe6810d78aa1dc73830455aae4f.png",
      "image_properties": {
        "width": 450,
        "height": 450,
        "size": 201934,
        "mime_type": "image/png",
        "exif_orientation": null
      },
      "video_url": null,
      "video_properties": null,
      "audio_url": null,
      "audio_properties": null,
      "model_url": null,
      "model_properties": null,
      "other_url": null,
      "other_properties": null,
      "background_color": null,
      "external_url": null,
      "created_date": "2024-06-11T06:10:59",
      "status": "minted",
      "token_count": 19976,
      "owner_count": 19976,
    }
  ]
}

*/

interface NFT {
  nft_id: string;
  chain: string;
  contract_address: string;
  token_id: string;
  name: string;
  description: string;
  image_url: string;
}

interface SimpleHashResponse {
  nfts: NFT[];
  next_cursor: string;
  next: string;
  previous: string;
}

async function getNFTsByOwner(
  ownerAddress: string,
  chains: string[]
): Promise<NFT[]> {
  const apiKey = process.env.API_KEY_SIMPLE_HASH!;
  const url = "https://api.simplehash.com/api/v0/nfts/owners";
  let allNFTs: NFT[] = [];
  let nextCursor: string | null = null;

  do {
    const params = new URLSearchParams({
      chains: chains.join(","),
      wallet_addresses: ownerAddress,
      limit: "50",
    });

    if (nextCursor) {
      params.append("cursor", nextCursor);
    }

    try {
      console.log(`Fetching NFTs... (Total fetched so far: ${allNFTs.length})`);
      const response = await fetch(`${url}?${params}`, {
        headers: {
          "X-API-KEY": apiKey,
          accept: "application/json",
        },
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const data: SimpleHashResponse =
        (await response.json()) as SimpleHashResponse;
      allNFTs = allNFTs.concat(data.nfts);
      nextCursor = data.next_cursor;
    } catch (error) {
      console.error("Error fetching NFTs:", error);
      throw error;
    }
  } while (nextCursor);

  console.log(`Finished fetching NFTs. Total fetched: ${allNFTs.length}`);
  return allNFTs;
}

getNFTsByOwner("0xe335Cf211aA52f3a84257F61dde34C3BDFced560", ["base"])
  .then((nfts) => {
    const ids = nfts
      .filter(
        (nft) =>
          nft.contract_address === "0x2D37C6bfcb5CDD2cDb5c48C107B56a85B77d62e8"
      )
      .map((nft) => Number(nft.token_id));

    console.log(ids);
    console.log(ids.length);
  })
  .catch((error) => console.error(error));
