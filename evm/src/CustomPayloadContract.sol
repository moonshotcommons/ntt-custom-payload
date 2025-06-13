// SPDX-License-Identifier: Apache 2
pragma solidity >=0.8.8 <0.9.0;

import "./libraries/TrimmedAmount.sol";
contract CustomPayloadContract {

    struct BlessMessage {
        uint16 sourceChainId;
        address sender;
        TrimmedAmount amount;
        uint16 targetChainId;
        address recipient;
        string blessing;
        // 0: pending, 1: completed
        uint8 status;
        uint48 timestamp;   
    }

    event ReceivedBlessMessages(address indexed receiver, address indexed sender,  
        TrimmedAmount amount, string blessing, uint48 timestamp);


    mapping(address => BlessMessage[]) public blessMessages;

    function setBlessMessage(string memory blessing) public {
        blessMessages[msg.sender].push(BlessMessage({
            sourceChainId: 0,
            sender: address(0),
            amount: TrimmedAmount.wrap(0),
            targetChainId: 0,
            recipient: address(0),
            blessing: blessing,
            status: 0,
            timestamp: 0
        }));
    }

    function sendBlessMessage(uint16 sourceChainId, address sender, TrimmedAmount amount,
        uint16 targetChainId, address recipient) public returns (bytes memory) {
        
        uint len = blessMessages[sender].length;
        if (len == 0) {
            revert("No bless message found");
        }
        BlessMessage memory message = blessMessages[sender][len - 1];
        if (message.status != 0) {
            revert("There isn't any pending bless message");
        }
        message.status = 1;
        message.sourceChainId = sourceChainId;
        message.sender = sender;
        message.amount = amount;
        message.targetChainId = targetChainId;
        message.recipient = recipient;
        message.timestamp = uint48(block.timestamp);
        blessMessages[sender][len - 1] = message;

        return abi.encode(message);
    }

    function receiveBlessMessage(bytes memory blessing) public {
        BlessMessage memory receivedMessage = abi.decode(blessing, (BlessMessage));
        blessMessages[receivedMessage.recipient].push(receivedMessage);

        emit ReceivedBlessMessages(receivedMessage.recipient, receivedMessage.sender, 
            receivedMessage.amount, receivedMessage.blessing, receivedMessage.timestamp);
    }
}