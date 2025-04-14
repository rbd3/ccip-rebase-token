//SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {TokenPool} from "lib/ccip/contracts/src/v0.8/ccip/pools/TokenPool.sol";

contract RebaseTokenPool is TokenPool {
    constructor(
        IERC20 _token,
        address[] memory _allowlist,
        address _rnmProxy,
        address _router
    ) TokenPool(_token, 18, _allowlist, _rnmProxy, _router) {}
}
