// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {CrowdFunding} from "../src/CrowdFunding.sol";
import {MockToken} from "../src/MockToken.sol";

contract CrowdFundingScript is Script {
    function run() external returns (CrowdFunding cf) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);

        // 1. Always deploy MockToken first for testing on Sepolia
        MockToken mock = new MockToken();
        address tokenAddress = address(mock);
        console.log("MockToken deployed at:", tokenAddress);

        // 2. Deploy CrowdFunding with the valid MockToken address
        cf = new CrowdFunding(tokenAddress);
        console.log("CrowdFunding deployed at:", address(cf));

        vm.stopBroadcast();
    }
}