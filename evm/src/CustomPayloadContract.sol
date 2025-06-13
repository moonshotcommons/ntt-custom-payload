// SPDX-License-Identifier: Apache 2
pragma solidity >=0.8.8 <0.9.0;

import "./libraries/TrimmedAmount.sol";

/// @title CustomPayloadContract
/// @notice Contract for managing blessing messages across chains
contract CustomPayloadContract {
    // Custom errors
    error NoBlessMessageFound();
    error NoPendingBlessMessage();

    /// @notice Structure for storing blessing message details
    struct BlessMessage {
        uint16 sourceChainId;
        uint16 targetChainId;
        address sender;
        address recipient;
        TrimmedAmount amount;
        uint8 status;      // 0: pending, 1: completed
        uint48 timestamp;
        string blessing;
    }

    /// @notice Mapping of user addresses to their blessing messages
    mapping(address => BlessMessage[]) public blessMessages;

    /// @notice Event emitted when a blessing message is received
    /// @param receiver The address receiving the blessing
    /// @param sender The address sending the blessing
    /// @param amount The amount associated with the blessing
    /// @param blessing The blessing message
    /// @param timestamp The timestamp of the blessing
    event ReceivedBlessMessages(
        address indexed receiver,
        address indexed sender,
        TrimmedAmount amount,
        string blessing,
        uint48 timestamp
    );

    /// @notice Sets a new bless message for the sender
    /// @param blessing The blessing message to set
    function setBlessMessage(string memory blessing) public {
        blessMessages[msg.sender].push(BlessMessage({
            sourceChainId: 0,
            targetChainId: 0,
            sender: address(0),
            recipient: address(0),
            amount: TrimmedAmount.wrap(0),
            status: 0,
            timestamp: 0,
            blessing: blessing
        }));
    }

    /// @notice Sends a blessing message to another chain
    /// @param sourceChainId The source chain ID
    /// @param sender The sender's address
    /// @param amount The amount associated with the blessing
    /// @param targetChainId The target chain ID
    /// @param recipient The recipient's address
    /// @return The encoded blessing message
    function sendBlessMessage(
        uint16 sourceChainId,
        address sender,
        TrimmedAmount amount,
        uint16 targetChainId,
        address recipient
    ) public returns (bytes memory) {
        BlessMessage[] storage messages = blessMessages[sender];
        uint len = messages.length;
        if (len == 0) revert NoBlessMessageFound();
        
        BlessMessage storage message = messages[len - 1];
        if (message.status != 0) revert NoPendingBlessMessage();
        
        message.status = 1;
        message.sourceChainId = sourceChainId;
        message.targetChainId = targetChainId;
        message.sender = sender;
        message.recipient = recipient;
        message.amount = amount;
        message.timestamp = uint48(block.timestamp);

        return abi.encode(message);
    }

    /// @notice Receives a blessing message from another chain
    /// @param blessing The encoded blessing message
    function receiveBlessMessage(bytes memory blessing) public {
        BlessMessage memory receivedMessage = abi.decode(blessing, (BlessMessage));
        blessMessages[receivedMessage.recipient].push(receivedMessage);

        emit ReceivedBlessMessages(
            receivedMessage.recipient,
            receivedMessage.sender,
            receivedMessage.amount,
            receivedMessage.blessing,
            receivedMessage.timestamp
        );
    }
}