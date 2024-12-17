// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/NFTVault.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract MockERC721 is ERC721 {
  constructor() ERC721("MockERC721", "M721") { }

  function mint(address to, uint256 tokenId) public {
    _mint(to, tokenId);
  }
}

contract MockERC1155 is ERC1155 {
  constructor() ERC1155("") { }

  function mint(address to, uint256 id, uint256 amount) public {
    _mint(to, id, amount, "");
  }
}

contract NFTVaultTest is Test {
  NFTVault public vault;
  MockERC721 public mockERC721;
  MockERC1155 public mockERC1155;
  address public admin;
  address public manager;
  address public user;

  function setUp() public {
    admin = address(this);
    manager = address(0x1);
    user = address(0x2);

    vault = new NFTVault();
    mockERC721 = new MockERC721();
    mockERC1155 = new MockERC1155();

    vm.prank(manager);
    vault.grantRole(vault.MANAGER_ROLE(), manager);
  }

  function testConstructor() public view {
    assertTrue(vault.hasRole(vault.DEFAULT_ADMIN_ROLE(), admin));
    assertTrue(vault.hasRole(vault.MANAGER_ROLE(), admin));
  }

  function testGrantAndRevokeManagerRole() public {
    address newManager = address(0x3);

    vault.grantManagerRole(newManager);
    assertTrue(vault.hasRole(vault.MANAGER_ROLE(), newManager));

    vault.revokeManagerRole(newManager);
    assertFalse(vault.hasRole(vault.MANAGER_ROLE(), newManager));
  }

  function testSendERC721() public {
    uint256 tokenId = 1;
    mockERC721.mint(address(vault), tokenId);

    vm.prank(manager);
    vault.sendERC721(IERC721(address(mockERC721)), user, tokenId);

    assertEq(mockERC721.ownerOf(tokenId), user);
  }

  function testSendERC1155() public {
    uint256 tokenId = 1;
    uint256 amount = 10;
    mockERC1155.mint(address(vault), tokenId, amount);

    vm.prank(manager);
    vault.sendERC1155(IERC1155(address(mockERC1155)), user, tokenId, amount, "");

    assertEq(mockERC1155.balanceOf(user, tokenId), amount);
  }

  function testBatchSendERC1155() public {
    uint256[] memory ids = new uint256[](2);
    uint256[] memory amounts = new uint256[](2);
    ids[0] = 1;
    ids[1] = 2;
    amounts[0] = 10;
    amounts[1] = 20;

    mockERC1155.mint(address(vault), ids[0], amounts[0]);
    mockERC1155.mint(address(vault), ids[1], amounts[1]);

    vm.prank(manager);
    vault.batchSendERC1155(IERC1155(address(mockERC1155)), user, ids, amounts, "");

    assertEq(mockERC1155.balanceOf(user, ids[0]), amounts[0]);
    assertEq(mockERC1155.balanceOf(user, ids[1]), amounts[1]);
  }

  function testOnERC721Received() public {
    uint256 tokenId = 1;
    mockERC721.mint(user, tokenId);

    vm.prank(user);
    mockERC721.safeTransferFrom(user, address(vault), tokenId);

    assertEq(mockERC721.ownerOf(tokenId), address(vault));
  }

  function testOnERC1155Received() public {
    uint256 tokenId = 1;
    uint256 amount = 10;
    mockERC1155.mint(user, tokenId, amount);

    vm.prank(user);
    mockERC1155.safeTransferFrom(user, address(vault), tokenId, amount, "");

    assertEq(mockERC1155.balanceOf(address(vault), tokenId), amount);
  }

  function testOnERC1155BatchReceived() public {
    uint256[] memory ids = new uint256[](2);
    uint256[] memory amounts = new uint256[](2);
    ids[0] = 1;
    ids[1] = 2;
    amounts[0] = 10;
    amounts[1] = 20;

    mockERC1155.mint(user, ids[0], amounts[0]);
    mockERC1155.mint(user, ids[1], amounts[1]);

    vm.prank(user);
    mockERC1155.safeBatchTransferFrom(user, address(vault), ids, amounts, "");

    assertEq(mockERC1155.balanceOf(address(vault), ids[0]), amounts[0]);
    assertEq(mockERC1155.balanceOf(address(vault), ids[1]), amounts[1]);
  }

  function testSupportsInterface() public view {
    assertTrue(vault.supportsInterface(type(IERC721Receiver).interfaceId));
    assertTrue(vault.supportsInterface(type(IERC1155Receiver).interfaceId));
    assertTrue(vault.supportsInterface(type(IERC165).interfaceId));
  }
}
