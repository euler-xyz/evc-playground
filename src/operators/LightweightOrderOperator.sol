// SPDX-License-Identifier: GPL-2.0-or-later

pragma solidity ^0.8.0;

import "solmate/tokens/ERC20.sol";
import "euler-cvc/interfaces/ICreditVaultConnector.sol";

/// @title LightweightOrderOperator
/// @notice This contract is used to manage orders submitted or signed by the user.
/// The operations that do not require any kind of authentication (i.e. condition checks)
/// can be submitted as non-CVC operations, while the operations that require authentication
/// (i.e. vault interactions) can be submitted as CVC operations.
/// Both the order submitter and the executor can be tipped in form of the ERC20 token
/// as per the tipReceiver value. For that, the tip amount should be transferred to this
/// contract during:
/// - the submission step (using signed calldata of the CVC permit functionality) in order to
///   tip the order submitter
/// - the execution step (either while executing non-CVC or CVC operations) in order to
///   tip the order executor
/// The OrderOperator will always use the full amount of its balance at the time for the tip payout.
/// Important: the submitter/executor must set the value of the tipReceiver variable to the address
/// where they want to receive the tip. For safety, it should happen atomicaly during
/// the CVC batch call, before the actual sumission/execution of the order.
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
        NonCVCBatchItem[] nonCVCOperations;
        ICVC.BatchItem[] CVCOperations;
        Tip submissionTip;
        Tip executionTip;
        uint salt;
    }

    struct NonCVCBatchItem {
        address targetContract;
        bytes data;
    }

    struct Tip {
        ERC20 token;
        uint minAmount;
        uint maxAmount;
    }

    ICVC public immutable cvc;

    mapping(bytes32 orderHash => OrderState state) public orderLookup;
    address internal tipReceiver;

    event OrderPending(Order order);
    event OrderExecuted(bytes32 indexed orderHash, address indexed caller);
    event OrderCancelled(bytes32 indexed orderHash);

    error NotAuthorized();
    error InvalidOrderState();
    error InvalidCVCOperations();
    error InvalidNonCVCOperations();
    error InvalidTip();
    error EmptyError();

    constructor(ICVC _cvc) {
        cvc = _cvc;
    }

    /// @notice Only CVC can call a function with this modifier
    modifier onlyCVC() {
        if (msg.sender != address(cvc)) {
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
    function execute(Order calldata order) external onlyCVC {
        bytes32 orderHash = keccak256(abi.encode(order));

        if (orderLookup[orderHash] == OrderState.NONE) {
            _verifyOrder(order);
        } else if (orderLookup[orderHash] != OrderState.PENDING) {
            revert InvalidOrderState();
        }

        orderLookup[orderHash] = OrderState.EXECUTED;

        // execute non-CVC operations, i.e. check conditions
        _batch(order.nonCVCOperations);

        // execute CVC operations
        cvc.batch(order.CVCOperations);

        // payout the execution tip
        _payoutTip(order.executionTip);

        (address caller, ) = cvc.getExecutionContext(address(0));
        emit OrderExecuted(orderHash, caller);
    }

    /// @notice Submits an order so that it's publicly visible on-chain and can be executed by anyone
    /// @param order The order to submit
    function submit(Order calldata order) public onlyCVC {
        bytes32 orderHash = keccak256(abi.encode(order));

        if (orderLookup[orderHash] != OrderState.NONE) {
            revert InvalidOrderState();
        }

        orderLookup[orderHash] = OrderState.PENDING;

        _verifyOrder(order);

        // payout the submission tip
        _payoutTip(order.submissionTip);

        emit OrderPending(order);
    }

    /// @notice Cancels an order
    /// @param order The order to cancel
    function cancel(Order calldata order) external onlyCVC {
        bytes32 orderHash = keccak256(abi.encode(order));

        if (orderLookup[orderHash] != OrderState.PENDING) {
            revert InvalidOrderState();
        }

        orderLookup[orderHash] = OrderState.CANCELLED;

        (address onBehalfOfAccount, ) = cvc.getExecutionContext(address(0));
        address owner = cvc.getAccountOwner(
            order.CVCOperations[0].onBehalfOfAccount
        );

        // NOTE: it would be safer to prevent an operator calling through the CVC. otherwise, an operator 
        // authorized for an owner can cancel any order, also for a sub-account of the owner for which it
        // might not be authorized

        if (owner != onBehalfOfAccount) {
            revert NotAuthorized();
        }

        emit OrderCancelled(orderHash);
    }

    /// @notice Executes a batch of non-CVC operations
    /// @param operations The operations to execute
    function _batch(NonCVCBatchItem[] calldata operations) internal {
        uint length = operations.length;
        for (uint i; i < length; ++i) {
            (bool success, bytes memory result) = operations[i]
                .targetContract
                .call(operations[i].data);

            if (!success) revertBytes(result);
        }
    }

    /// @notice Pays out a tip
    /// @param tip The tip to pay out
    function _payoutTip(Tip calldata tip) internal {
        if (address(tip.token) != address(0)) {
            uint amount = tip.token.balanceOf(address(this));
            address receiver = tipReceiver;

            if (amount > 0 && receiver == address(0)) {
                revert InvalidTip();
            }

            if (amount < tip.minAmount || amount > tip.maxAmount) {
                revert InvalidTip();
            }

            tip.token.transfer(receiver, amount);
        }
    }

    /// @notice Verifies an order
    /// @param order The order to verify
    function _verifyOrder(Order calldata order) internal view {
        // get the account authenticated by the CVC
        (address onBehalfOfAccount, ) = cvc.getExecutionContext(address(0));
        address owner = cvc.getAccountOwner(onBehalfOfAccount);
        if (owner != onBehalfOfAccount) {
            revert NotAuthorized();
        }

        // NOTE: it would be better to prevent an operator calling through the CVC. even without it, the code is still safe
        // as the CVC will take care of the authentication of this operator when the order is executed. however, without 
        // that prevention, an operator that is authorized for an owner can create an order for any sub-account of the
        // owner for which it might not be authorized. whether it's valid will will only be checked at the execution time

        // verify that the non-CVC operations contain only operations that do not involve the CVC
        uint length = order.nonCVCOperations.length;
        for (uint i; i < length; ++i) {
            if (order.nonCVCOperations[i].targetContract == address(cvc)) {
                revert InvalidNonCVCOperations();
            }
        }

        // verify CVC operations
        length = order.CVCOperations.length;
        if (length == 0) {
            revert InvalidCVCOperations();
        }

        // verify that the CVC operations contain only operations for the accounts belonging to the same user.
        // it's critical because if a user has authorized this operator for themselves, anyone else 
        // could create a batch for their accounts and execute it
        for (uint i; i < length; ++i) {
            if (
                (uint160(order.CVCOperations[i].onBehalfOfAccount) | 0xff) !=
                (uint160(onBehalfOfAccount) | 0xff)
            ) {
                revert InvalidCVCOperations();
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
