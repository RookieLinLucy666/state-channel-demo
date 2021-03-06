pragma solidity ^0.5.0;


contract Channel {

	address payable public channelSender;
	address payable public channelRecipient;
	uint public startDate;
	uint public channelTimeout;
	
	uint public balance;
	uint public funds;
	uint public senderSerial;
	uint public recipientSerial;
	bool public senderOK;
	bool public recipientOK;
	
	constructor(address payable sender, address payable recipient, uint timeout) public payable {
		require(sender != recipient);
		channelRecipient = recipient;
		channelSender = sender;
		startDate = now;
		channelTimeout = timeout;
		funds = msg.value;
	}
	
	function() external payable {
		funds += msg.value;
	}

	function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
		if (_i == 0) {
			return "0";
		}
		uint j = _i;
		uint len;
		while (j != 0) {
			len++;
			j /= 10;
		}
		bytes memory bstr = new bytes(len);
		uint k = len - 1;
		while (_i != 0) {
			bstr[k--] = byte(uint8(48 + _i % 10));
			_i /= 10;
		}
		return string(bstr);
	}
	
	function UpdateChannel(uint nBalance, uint nSenderSerial, uint nRecipientSerial, uint8 signature_v, bytes32 signature_r, bytes32 signature_s) public {
		require(msg.sender == channelRecipient || msg.sender == channelSender);									// only channel endpoints may modify it
		require(startDate + channelTimeout > now);																// timeout?
		require(nRecipientSerial >= recipientSerial && nSenderSerial >= senderSerial);							// counters must go up
		require(nBalance <= funds);																				// balance must not exceed deposited funds
		
		bytes memory prefix = "\x19Ethereum Signed Message:\n";
		bytes memory message = abi.encode(address(this), nBalance, nSenderSerial, nRecipientSerial);
		bytes32 msghash = keccak256(abi.encodePacked(prefix, uint2str(message.length), message));				// message hash
		address signer = ecrecover(msghash, signature_v, signature_r, signature_s); 							// message signer
		
		require(signer == channelRecipient || signer == channelSender);											// signer must be one of the channel endpoints
		require(msg.sender != signer);																			// you may not sign a transfer to yourself
		
		if(nBalance != balance) {																				// if balance changed, remove aprovals
			senderOK = false;
			recipientOK = false;
			balance = nBalance;
		}
		recipientSerial = nRecipientSerial;
		senderSerial = nSenderSerial;
		
		if (signer == channelRecipient)			 																// transfer from channel recipient to channel sender
			recipientOK = true;																					// set recipient aproval
		else if (signer == channelSender)								 										// transfer from channel sender to channel recipient
			senderOK = true;																					// set sender aproval
	}

	function CloseChannel() public {
		require((startDate + channelTimeout <= now) || (senderOK && recipientOK)); 								// timeout passed or approvals OK
		if(!channelRecipient.send(balance)) { /* ignore transfer error */ }										// clear balance
		selfdestruct(channelSender);																			// close channel

	}

}

