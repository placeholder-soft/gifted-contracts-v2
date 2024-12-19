// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

contract UnifiedStore is Ownable {
  mapping(string => string) public configString;
  mapping(string => address) public configAddress;
  mapping(string => bool) public configBool;
  mapping(string => uint256) public configUint256;

  event UpdateString(string key, string value);
  event DeleteString(string key);

  event UpdateAddress(string key, address value);
  event DeleteAddress(string key);

  event UpdateBool(string key, bool value);
  event DeleteBool(string key);

  event UpdateUint256(string key, uint256 value);
  event DeleteUint256(string key);

  constructor() Ownable(msg.sender) { }

  /// string
  function setStrings(string[] calldata keys, string[] calldata values) public onlyOwner {
    for (uint256 i = 0; i < keys.length; ++i) {
      configString[keys[i]] = values[i];
      emit UpdateString(keys[i], values[i]);
    }
  }

  function deleteStrings(string[] calldata keys) public onlyOwner {
    for (uint256 i = 0; i < keys.length; ++i) {
      delete configString[keys[i]];
      emit DeleteString(keys[i]);
    }
  }

  function setString(string calldata key, string calldata value) public onlyOwner {
    configString[key] = value;
    emit UpdateString(key, value);
  }

  function deleteString(string calldata key) public onlyOwner {
    delete configString[key];
    emit DeleteString(key);
  }

  function getStrings(string[] calldata keys) public view returns (string[] memory) {
    string[] memory values = new string[](keys.length);
    for (uint256 i = 0; i < keys.length; ++i) {
      values[i] = configString[keys[i]];
    }
    return values;
  }

  function getString(string calldata key) public view returns (string memory) {
    return configString[key];
  }

  /// address

  function setAddress(string calldata key, address value) public onlyOwner {
    configAddress[key] = value;
    emit UpdateAddress(key, value);
  }

  function deleteAddress(string calldata key) public onlyOwner {
    delete configAddress[key];
    emit DeleteAddress(key);
  }

  function getAddress(string calldata key) public view returns (address) {
    return configAddress[key];
  }

  function setAddresses(string[] calldata keys, address[] calldata values) public onlyOwner {
    for (uint256 i = 0; i < keys.length; ++i) {
      configAddress[keys[i]] = values[i];
      emit UpdateAddress(keys[i], values[i]);
    }
  }

  function getAddresses(string[] calldata keys) public view returns (address[] memory) {
    address[] memory values = new address[](keys.length);
    for (uint256 i = 0; i < keys.length; ++i) {
      values[i] = configAddress[keys[i]];
    }
    return values;
  }

  function deleteAddresses(string[] calldata keys) public onlyOwner {
    for (uint256 i = 0; i < keys.length; ++i) {
      delete configAddress[keys[i]];
      emit DeleteAddress(keys[i]);
    }
  }

  /// bool
  function setBool(string calldata key, bool value) public onlyOwner {
    configBool[key] = value;
    emit UpdateBool(key, value);
  }

  function deleteBool(string calldata key) public onlyOwner {
    delete configBool[key];
    emit DeleteBool(key);
  }

  function getBool(string calldata key) public view returns (bool) {
    return configBool[key];
  }

  function setBools(string[] calldata keys, bool[] calldata values) public onlyOwner {
    for (uint256 i = 0; i < keys.length; ++i) {
      configBool[keys[i]] = values[i];
      emit UpdateBool(keys[i], values[i]);
    }
  }

  function getBools(string[] calldata keys) public view returns (bool[] memory) {
    bool[] memory values = new bool[](keys.length);
    for (uint256 i = 0; i < keys.length; ++i) {
      values[i] = configBool[keys[i]];
    }
    return values;
  }

  function deleteBools(string[] calldata keys) public onlyOwner {
    for (uint256 i = 0; i < keys.length; ++i) {
      delete configBool[keys[i]];
      emit DeleteBool(keys[i]);
    }
  }

  // uint256
  function setUint256(string calldata key, uint256 value) public onlyOwner {
    configUint256[key] = value;
    emit UpdateUint256(key, value);
  }

  function deleteUint256(string calldata key) public onlyOwner {
    delete configUint256[key];
    emit DeleteUint256(key);
  }

  function getUint256(string calldata key) public view returns (uint256) {
    return configUint256[key];
  }

  function setUint256s(string[] calldata keys, uint256[] calldata values) public onlyOwner {
    for (uint256 i = 0; i < keys.length; ++i) {
      configUint256[keys[i]] = values[i];
      emit UpdateUint256(keys[i], values[i]);
    }
  }

  function getUint256s(string[] calldata keys) public view returns (uint256[] memory) {
    uint256[] memory values = new uint256[](keys.length);
    for (uint256 i = 0; i < keys.length; ++i) {
      values[i] = configUint256[keys[i]];
    }
    return values;
  }

  function deleteUint256s(string[] calldata keys) public onlyOwner {
    for (uint256 i = 0; i < keys.length; ++i) {
      delete configUint256[keys[i]];
      emit DeleteUint256(keys[i]);
    }
  }
}
