// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {NFTVault} from "../src/NFTVault.sol";

contract TransferERC721 is Script {
    IERC721 public nftContract;
    NFTVault public nftVault;
    address public to;
    uint256 public constant TOKEN_ID = 311;

    function run() public {
        transferNFT();
    }

    function transferNFT() internal {
        vm.startBroadcast(getAddressFromConfig("deployer"));
        nftContract = IERC721(0xe223dF3cF0953048eb3c575abcD81818C9ea74B8);
        nftVault = NFTVault(getAddressFromConfig("NFTVault"));
        to = 0x3260e5D0a58f2e8c592AdEa06bA0100CB09f26Ea;

        // Transfer the NFT from NFTVault to the recipient
        nftVault.sendERC721(nftContract, to, TOKEN_ID);
        console.log(
            "Transferred NFT with token ID %s from NFTVault to %s",
            TOKEN_ID,
            to
        );

        vm.stopBroadcast();
    }

    function getAddressFromConfig(
        string memory key
    ) internal view returns (address) {
        string memory env = vm.envString("DEPLOY_ENV");
        require(bytes(env).length > 0, "DEPLOY_ENV must be set");
        string memory root = vm.projectRoot();
        string memory path = string.concat(
            root,
            "/config/",
            env,
            "_addresses.json"
        );
        string memory json = vm.readFile(path);
        bytes memory addressBytes = vm.parseJson(
            json,
            string.concat(".", vm.toString(block.chainid), ".", key)
        );
        return abi.decode(addressBytes, (address));
    }
}
