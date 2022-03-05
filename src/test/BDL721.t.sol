// SPDX-License-Identifier: Unlicense
pragma solidity 0.8.10;

import "ds-test/test.sol";
import "../BDL721.sol";
import {TestERC721} from "./mock/TestERC721.sol";

contract BundlerTest is DSTest {
    TestERC721 sand;
    TestERC721 dcl;
    BDL721 bdl;
    uint256 bundleId;

    //setup and mint land, instantiate bundler contract
    function setUp() public {
        sand = new TestERC721();
        dcl = new TestERC721();
        bdl = new BDL721();
        
        sand.safeMint(address(this), 1);
        sand.safeMint(address(this), 2);
        dcl.safeMint(address(this), 1);
        dcl.safeMint(address(this), 2);
        
    }

    function test_createdBundle() public {
        assertEq(address(bdl.ownerOf(bundleId)), address(this));
    }

    function test_transferBundle() public {
        bdl.transfer(address(0x29D7d1dd5B6f9C864d9db560D72a247c178aE86B));
        assertEq(address(bdl.ownerOf(bundleId)), address(0x29D7d1dd5B6f9C864d9db560D72a247c178aE86B));
        assertEq(bool(bdl.check(bundleId)), bool(true));
    }

    function test_burnBundle() public {

    }

    function test_insertBundle() public {


    }

    function test_removeBundle() public {

    }

}


