// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.19;

import "solmate/tokens/ERC20.sol";
import "evc/interfaces/IEthereumVaultConnector.sol";

/// @title LightweightOrderOperator
/// @notice This contract is used to manage orders submitted or signed by the user.
/// The operations that do not require any kind of authentication (i.e. condition checks)
/// can be submitted as non-EVC operations, while the operations that require authentication
/// (i.e. vault interactions) can be submitted as EVC operations.
/// Both the order submitter and the executor can be tipped in form of the ERC20 token
/// as per the tipReceiver value. For that, the tip amount should be transferred to this
/// contract during:
/// - the submission step (using signed calldata of the EVC permit functionality) in order to
///   tip the order submitter
/// - the execution step (either while executing non-EVC or EVC operations) in order to
///   tip the order executor
/// The OrderOperator will always use the full amount of its balance at the time for the tip payout.
/// Important: the submitter/executor must set the value of the tipReceiver variable to the address
/// where they want to receive the tip. For safety, it should happen atomically during
/// the EVC batch call, before the actual submission/execution of the order.
/// NOTE: Because the operator contract can be made to invoke any arbitrary target contract with
/// any arbitrary calldata, it should never be given any privileges, or hold any ETH or tokens.
/// Also, one should never approve this contract to spend their ERC20 tokens.
contract LightweightOrderOperator {
    enum OrderState {
        NONE,
        PENDING,
        CANCELLED,
        EXECUTED
    }

    struct Order {
        NonEVCBatchItem[] nonEVCOperations;
        IEVC.BatchItem[] EVCOperations;
        ERC20 submissionTipToken;
        ERC20 executionTipToken;
        uint256 salt;
    }

    struct NonEVCBatchItem {
        address targetContract;
        bytes data;
    }

    IEVC public immutable evc;

    mapping(bytes32 orderHash => OrderState state) public orderLookup;
    address internal tipReceiver;

    event OrderPending(Order order);
    event OrderExecuted(bytes32 indexed orderHash, address indexed caller);
    event OrderCancelled(bytes32 indexed orderHash);

    error NotAuthorized();
    error InvalidOrderState();
    error InvalidEVCOperations();
    error InvalidNonEVCOperations();
    error InvalidTip();
    error EmptyError();

    constructor(IEVC _evc) {
        evc = _evc;
    }

    /// @notice Only EVC can call a function with this modifier
    modifier onlyEVC() {
        if (msg.sender != address(evc)) {
            revert NotAuthorized();
        }

        _;
    }

    /// @notice Sets the address that will receive the tips. Anyone can set it to any address anytime.
    /// @param _tipReceiver The address that will receive the tips
    function setTipReceiver(address _tipReceiver) external {
        tipReceiver = _tipReceiver;
    }

    /// @notice Executes an order that is either new or pending
    /// @param order The order to execute
    function execute(Order calldata order) external onlyEVC {
        bytes32 orderHash = keccak256(abi.encode(order));

        if (orderLookup[orderHash] == OrderState.NONE) {
            _verifyOrder(order);
        } else if (orderLookup[orderHash] != OrderState.PENDING) {
            revert InvalidOrderState();
        }

        orderLookup[orderHash] = OrderState.EXECUTED;

        // execute non-EVC operations, i.e. check conditions
        _batch(order.nonEVCOperations);

        // execute EVC operations
        evc.batch(order.EVCOperations);

        // payout the execution tip
        _payoutTip(order.executionTipToken);

        (address caller,) = evc.getCurrentOnBehalfOfAccount(address(0));
        emit OrderExecuted(orderHash, caller);
    }

    /// @notice Submits an order so that it's publicly visible on-chain and can be executed by anyone
    /// @param order The order to submit
    function submit(Order calldata order) public onlyEVC {
        bytes32 orderHash = keccak256(abi.encode(order));

        if (orderLookup[orderHash] != OrderState.NONE) {
            revert InvalidOrderState();
        }

        orderLookup[orderHash] = OrderState.PENDING;

        _verifyOrder(order);

        // payout the submission tip
        _payoutTip(order.submissionTipToken);

        emit OrderPending(order);
    }

    /// @notice Cancels an order
    /// @param order The order to cancel
    function cancel(Order calldata order) external onlyEVC {
        bytes32 orderHash = keccak256(abi.encode(order));

        if (orderLookup[orderHash] != OrderState.PENDING) {
            revert InvalidOrderState();
        }

        orderLookup[orderHash] = OrderState.CANCELLED;

        (address onBehalfOfAccount,) = evc.getCurrentOnBehalfOfAccount(address(0));
        address owner = evc.getAccountOwner(order.EVCOperations[0].onBehalfOfAccount);

        if (owner != onBehalfOfAccount || evc.isOperatorAuthenticated()) {
            revert NotAuthorized();
        }

        emit OrderCancelled(orderHash);
    }

    /// @notice Executes a batch of non-EVC operations
    /// @param operations The operations to execute
    function _batch(NonEVCBatchItem[] calldata operations) internal {
        uint256 length = operations.length;
        for (uint256 i; i < length; ++i) {
            (bool success, bytes memory result) = operations[i].targetContract.call(operations[i].data);

            if (!success) revertBytes(result);
        }
    }

    /// @notice Pays out a tip
    /// @param tipToken The token to pay out
    function _payoutTip(ERC20 tipToken) internal {
        if (address(tipToken) != address(0)) {
            uint256 amount = tipToken.balanceOf(address(this));
            address receiver = tipReceiver;

            if (amount > 0 && receiver == address(0)) {
                revert InvalidTip();
            }

            tipToken.transfer(receiver, amount);
        }
    }

    /// @notice Verifies an order
    /// @param order The order to verify
    function _verifyOrder(Order calldata order) internal view {
        // get the account authenticated by the EVC
        (address onBehalfOfAccount,) = evc.getCurrentOnBehalfOfAccount(address(0));
        address owner = evc.getAccountOwner(onBehalfOfAccount);
        if (owner != onBehalfOfAccount || evc.isOperatorAuthenticated()) {
            revert NotAuthorized();
        }

        // verify that the non-EVC operations contain only operations that do not involve the EVC
        uint256 length = order.nonEVCOperations.length;
        for (uint256 i; i < length; ++i) {
            if (order.nonEVCOperations[i].targetContract == address(evc)) {
                revert InvalidNonEVCOperations();
            }
        }

        // verify EVC operations
        length = order.EVCOperations.length;
        if (length == 0) {
            revert InvalidEVCOperations();
        }

        // verify that the EVC operations contain only operations for the accounts belonging to the same user.
        // it's critical because if a user has authorized this operator for themselves, anyone else
        // could create a batch for their accounts and execute it
        for (uint256 i; i < length; ++i) {
            if ((uint160(order.EVCOperations[i].onBehalfOfAccount) | 0xff) != (uint160(onBehalfOfAccount) | 0xff)) {
                revert InvalidEVCOperations();
            }
        }
    }

    function revertBytes(bytes memory errMsg) internal pure {
        if (errMsg.length != 0) {
            assembly {
                revert(add(32, errMsg), mload(errMsg))
            }
        }
        revert EmptyError();
    }
}
