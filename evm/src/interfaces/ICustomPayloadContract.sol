// SPDX-License-Identifier: Apache 2
pragma solidity >=0.8.8 <0.9.0;

import "../libraries/TrimmedAmount.sol";

interface ICustomPayloadContract {
    function sendBlessMessage(
        uint16 sourceChainId,
        address sender,
        TrimmedAmount amount,
        uint16 targetChainId,
        address recipient
    ) external returns (bytes memory);

    function receiveBlessMessage(bytes memory blessing) external;   
} 