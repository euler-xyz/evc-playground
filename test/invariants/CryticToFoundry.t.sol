// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// Libraries
import "forge-std/Test.sol";
import "forge-std/console.sol";

// Test Contracts
import {Invariants} from "./Invariants.t.sol";
import {Setup} from "./Setup.t.sol";

/// @title CryticToFoundry
/// @notice Foundry wrapper for fuzzer failed call sequences
/// @dev Regression testing for failed call sequences
contract CryticToFoundry is Invariants, Setup {
    modifier setup() override {
        _;
    }

    /// @dev Foundry compatibility faster setup debugging
    function setUp() public {
        // Deploy protocol contracts and protocol actors
        _setUp();

        // Deploy actors
        _setUpActors();

        // Initialize handler contracts
        _setUpHandlers();

        actor = actors[USER1];
    }

    function test_hooks() public {
        assert_VaultBase_invariantA(vaults[0]);
    }

    /*     function test_VaultSimpleBorrowable_invariantA() public {
        this.transferFrom(
            512000000,
            98486275380736287597876803469925129194975432820152697795013895226765300128,
            0x0000000000000000000000000000000000000041,
            115792089237316195423546560861005357749589898509895355986843660353153328480272
        );
        assert(echidna_invariant_VaultSimpleBorrowable_invariantA());
    } */

    function test_setCollateralFactor() public {
        this.setCollateralFactor(2, 100);
    }

    function test_brokenMedusaInvariant() public {
        actor = actors[USER2];

        vm.warp(45348);
        this.setInterestRate(99999999999999999999999635);

        vm.warp(45355);
        this.deposit(
            3671743063080802746815416825491118336290905145409708398004109081935346,
            0x0000000000000000000000000000000001ffc9a7,
            256
        );

        vm.warp(104869);
        this.mintToActor(
            584007913129639936,
            1461501637330902918203684832716283019655932542975,
            30362808798281246480524449931024234919661350613807169413187594475717001416407
        );

        this.enableController(
            6252581806732826542102055870773261469164455618509096943616, 100000000000000000000000000000
        );

        vm.warp(110626);
        this.borrowTo(
            131072,
            14246703677440183165141387562015842214396964696556621053914374877048747707402,
            113045367814223527155374216513980611294147760687180486228232781248365040559413
        );

        vm.warp(110637);
        this.mint(
            125,
            0xCC9A31701696B32582CE8fAB30B0dF273632BA39,
            30659301841701235528704831814079863282139560059745002970586078399931117454890
        );

        echidna_invariant_VaultSimple_invariantABCD();
    }
}
