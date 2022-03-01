// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IERC165.sol";

interface IBDL721 is IERC165 {
		
	event Creation(address indexed to, uint256 indexed bundleId);
	event Burn(address indexed owner, uint256 indexed bundleId);
	event Insertion(address indexed registry, uint256 indexed tokenId, uint256 bundleId);
	event Removal(address indexed registry, uint256 indexed tokenId, uint256 bundleId);

	function create(
		address[] calldata nftAddresses,
		uint256[] calldata tokenIds,
		uint256[] calldata sizes
	) external returns (uint256 bundleId);


	function burn(
		uint256 bundleId
	) external;

	function insert(
		address nftAddresses,
		uint256 tokenIds,
		uint256 bundleId
	) external;

	function remove(
		address nftAddress,
		uint256 tokenId,
		uint256 bundleId
	) external;

	function check(
		uint256 tokenId
	) external returns(bool);

}

