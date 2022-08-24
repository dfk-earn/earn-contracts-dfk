// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";

contract Beneficial is Ownable {
    address public beneficiary;
    uint public unlockedAfter;

    event BeneficiaryChanged(address newBeneficiary, address oldBeneficiary);

    constructor() {
        beneficiary = owner();
        emit BeneficiaryChanged(beneficiary, address(0));
    }

    function setBeneficiary(address _beneficiary, uint lockTime) external onlyOwner {
        require(_beneficiary != beneficiary, "Beneficial: old beneficiary");
        require(block.timestamp > unlockedAfter, "Beneficial: locked");
        address oldBeneficiary = beneficiary;
        beneficiary = _beneficiary;
        unlockedAfter = block.timestamp + lockTime;
        emit BeneficiaryChanged(beneficiary, oldBeneficiary);
    }
}
