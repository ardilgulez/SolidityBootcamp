// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

contract GasContract {
    struct Payment {
        uint256 paymentID;
        uint256 amount;
        address recipient;
        address admin; // admins address
        bytes8 recipientName; // max 8 characters
        uint8 paymentType;
        uint8 adminUpdated;
    }

    struct History {
        address updatedBy;
        uint256 lastUpdate;
        uint256 blockNumber;
    }

    struct ImportantStruct {
        uint8 a;
        uint256 b;
        uint8 c;
    }

    uint256 private immutable _totalSupply;
    uint256 private paymentCounter = 0;
    mapping(address => uint256) private balances;
    mapping(address => Payment[]) private payments;
    mapping(address => uint8) private _whitelist;
    History[] private paymentHistory; // when a payment was updated
    address[5] private _administrators;

    event AddedToWhitelist(address indexed userAddress, uint8 tier);

    event SupplyChanged(address indexed, uint256);
    event Transfer(address indexed recipient, uint256 amount);
    event PaymentUpdated(
        address indexed admin,
        uint256 ID,
        uint256 amount,
        bytes8 recipient
    );

    constructor(address[] memory _admins, uint256 _ts) {
        _totalSupply = _ts;
        uint8 ii = 0;
        for (; ii < 5; ) {
            if (_admins[ii] != address(0)) {
                _administrators[ii] = _admins[ii];
                if (_admins[ii] == msg.sender) {
                    balances[msg.sender] = _ts;
                    emit SupplyChanged(_admins[ii], _ts);
                } else {
                    balances[_admins[ii]] = 0;
                    emit SupplyChanged(_admins[ii], 0);
                }
            }
            unchecked {
                ++ii;
            }
        }
    }

    function addHistory(address _updateAddress) private returns (bool, bool) {
        History memory history = History(
            _updateAddress,
            block.timestamp,
            block.number
        );
        paymentHistory.push(history);
        return (true, true);
    }

    function transfer(
        address _recipient,
        uint256 _amount,
        string calldata _name
    ) external returns (bool) {
        require(
            balances[msg.sender] >= _amount,
            "transfer: Insufficient Balance"
        );
        require(bytes(_name).length < 9, "transfer: name too long (Max:8)"); // This statement makes the bytes 8 assignment safe
        balances[msg.sender] -= _amount;
        balances[_recipient] += _amount;
        emit Transfer(_recipient, _amount);
        unchecked {
            ++paymentCounter;
        }
        Payment memory payment = Payment(
            paymentCounter,
            _amount,
            _recipient,
            address(0),
            stringToBytes8(_name),
            1,
            0
        );
        payments[msg.sender].push(payment);
        return (true);
    }

    function updatePayment(
        address _user,
        uint256 _ID,
        uint256 _amount,
        uint8 _type
    ) external {
        checkForAdmin(msg.sender);
        require(_ID > 0, "updatePayment: ID must be > 0");
        require(_amount > 0, "updatePayment: Amount must be >0");
        require(_user != address(0), "updatePayment: zero-address");

        uint256 ii = 0;

        Payment[] storage userPayments = payments[_user];

        Payment storage userPayment;
        for (; ii < userPayments.length; ) {
            userPayment = userPayments[ii];
            if (userPayment.paymentID == _ID) {
                userPayment.adminUpdated = 1;
                userPayment.admin = _user;
                userPayment.paymentType = _type;
                userPayment.amount = _amount;
                addHistory(_user);
                emit PaymentUpdated(
                    msg.sender,
                    _ID,
                    _amount,
                    userPayment.recipientName
                );
                break;
            }

            unchecked {
                ++ii;
            }
        }
    }

    function addToWhitelist(address _userAddrs, uint8 _tier) external {
        checkForAdmin(msg.sender);
        _whitelist[_userAddrs] = _tier < 3 ? _tier : 3;
        emit AddedToWhitelist(_userAddrs, _tier);
    }

    function whiteTransfer(
        address _recipient,
        uint256 _amount,
        ImportantStruct calldata _struct // Cannot remove, cannot optimize either because we are not supposed to modify tests
    ) external {
        uint8 _tier = _whitelist[msg.sender];
        require(
            balances[msg.sender] >= _amount,
            "whiteTransfer: Balance too low"
        );
        balances[msg.sender] -= (_amount - _tier);
        balances[_recipient] += (_amount - _tier);
    }

    function stringToBytes8(string memory source)
        private
        pure
        returns (bytes8 result)
    {
        if (bytes(source).length == 0) {
            return 0x0;
        }
        assembly {
            result := mload(add(source, 8))
        }
    }

    function totalSupply() external view returns (uint256) {
        return _totalSupply;
    }

    function administrators(uint8 _index) external view returns (address) {
        return _administrators[_index];
    }

    function whitelist(address _user) external view returns (uint8) {
        return _whitelist[_user];
    }

    function balanceOf(address _user) external view returns (uint256) {
        return balances[_user];
    }

    function getTradingMode() external pure returns (bool) {
        return true;
    }

    function getPayments(address _user)
        external
        view
        returns (Payment[] memory)
    {
        return payments[_user];
    }

    function getPaymentHistory() external view returns (History[] memory) {
        return paymentHistory;
    }

    function checkForAdmin(address _user) private view {
        uint8 ii = 0;
        for (; ii < _administrators.length; ) {
            if (_administrators[ii] == _user) {
                return;
            }
            unchecked {
                ++ii;
            }
        }
        revert("Not an admin");
    }
}
