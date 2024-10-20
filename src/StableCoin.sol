// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC20Burnable, ERC20} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title a Decentralize stableCoin
/// @author MojtabaWeb3
/// @notice collateral => exogenous(wETH & wBTC)
/// @notice minting => Algorithmic (decentralized)
/// @notice realative stability => pegged to usd 1.00$
/// @dev this contract is erc20 implementation of our sable coin system.

contract StableCoin is ERC20Burnable, Ownable {
    error StableCoin__notEnoughAsset();
    error StableCoin__MoreThanZeroNeeds();
    error StableCoin__ZeroAddress();

    constructor() ERC20("Stable Coin", "STC") Ownable(msg.sender) {}

    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);
        if (balance <= 0) {
            revert StableCoin__MoreThanZeroNeeds();
        }
        if (balance < _amount) {
            revert StableCoin__notEnoughAsset();
        }

        super.burn(_amount);
    }

    function mint(address _to, uint256 _amount) external onlyOwner returns (bool) {
        if (_to == address(0)) {
            revert StableCoin__ZeroAddress();
        }
        if (_amount <= 0) {
            revert StableCoin__MoreThanZeroNeeds();
        }

        _mint(_to, _amount);

        return true;
    }
}
