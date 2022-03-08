// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "../BDL721.sol";
import {TestERC721} from "./mock/TestERC721.sol";
import {Utilities} from "./utils/Utilities.sol";
import {console} from "./utils/Console.sol";
import {Vm} from "forge-std/Vm.sol";


contract BundlerTest is DSTest {

    Vm internal immutable vm = Vm(HEVM_ADDRESS); // setup interface for calling cheat codes on the HEVM

    Utilities internal utils;
    address payable[] internal users;

    TestERC721 sand;
    TestERC721 dcl;
    uint256 bundleId;
    BDL721 bdl;


    //setup and mint land, instantiate bundler contract
    function setUp() public {
        
        utils = new Utilities();
        users = utils.createUsers(5);

        sand = new TestERC721();
        dcl = new TestERC721();
        bdl = new BDL721("Bundle", "BDL");
        
        sand.safeMint(users[1], 1);
        sand.safeMint(users[1], 2);
        dcl.safeMint(users[1], 1);
        dcl.safeMint(users[1], 2);
        sand.safeMint(users[1], 69); // asset to be inserted
    
        address[] memory nftAddresses = new address[](2);
        nftAddresses[0] = address(sand);
        nftAddresses[1] = address(dcl);
        require(nftAddresses.length==2, "wrong length");

        uint256[] memory tokenIds = new uint256[](4);
        tokenIds[0] = 1;
        tokenIds[1] = 2;
        tokenIds[2] = 1;
        tokenIds[3] = 2;

        uint256[] memory sizes = new uint256[](2);
        sizes[0] = 2;
        sizes[1] = 2;

        require(sand.ownerOf(1)==users[1], "Owner issue");

        vm.startPrank(users[1]);

        sand.setApprovalForAll(address(bdl), true);
        require(sand.isApprovedForAll(users[1], address(bdl)), "approval issue");
        dcl.setApprovalForAll(address(bdl), true);
        require(dcl.isApprovedForAll(users[1], address(bdl)), "approval issue");
        bundleId = bdl.create(nftAddresses, tokenIds, sizes);

        vm.stopPrank();

        console.log("bundleID", bundleId);
    }

    function test_mintedAssets() public {
        assertEq(address(sand.ownerOf(1)), users[1]);
        assertEq(address(sand.ownerOf(2)), users[1]);
        assertEq(address(dcl.ownerOf(1)), users[1]);
        assertEq(address(dcl.ownerOf(2)), users[1]);
    }


    function test_createdBundle() public {
        assertEq(address(bdl.ownerOf(bundleId)), users[1]);
    }




    function test_transferBundle() public {
        address payable alice = users[1];
        address payable bob = users[3];

        vm.startPrank(alice);

        bdl.transferFrom(alice, bob, bundleId);

        vm.stopPrank();


        assertEq(address(bdl.ownerOf(bundleId)), bob);

        assertEq(address(sand.ownerOf(1)), bob);
        assertEq(address(dcl.ownerOf(1)), bob);
        assertEq(address(sand.ownerOf(2)), bob);
        assertEq(address(dcl.ownerOf(2)), bob);
    }
    
    function test_transferApprovalBundle() public {
        address payable alice = users[1];
        address payable michael = users[2];

        vm.prank(alice);
        bdl.approve(michael, bundleId);

        vm.prank(michael);
        bdl.transferFrom(alice, michael, bundleId);
        
        assertEq(address(bdl.ownerOf(bundleId)), michael);

        assertEq(address(sand.ownerOf(1)), michael);
        assertEq(address(dcl.ownerOf(1)), michael);
        assertEq(address(sand.ownerOf(2)), michael);
        assertEq(address(dcl.ownerOf(2)), michael);
    }

    function test_checkValidBundle() public {

    }

    /**
    function test_burnBundle() public {
    }

    function test_insertBundle() public {
    }

    function test_removeBundle() public {
    }
    **/


}


