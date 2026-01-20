// SPDX-License-Identifer: MIT
pragma solidity ^0.8.24;

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {EIP712} from "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

/**
 * @title MerkleAirdrop
 * @author Samir Ben Bouker
 * @notice ERC20 airdrop contract gated by a Merkle root + EIP-712 signature
 * @dev
 *  This contract uses TWO protections for claiming:
 *   1) Merkle Proof: proves `(account, amount)` is part of the allowlist (Merkle tree).
 *   2) EIP-712 Signature: proves the claimant controls the `account` private key (authorization).
 *
 *  High-level flow:
 *   - Off-chain you generate a Merkle tree of leaves (account, amount) and publish the root.
 *   - User gets their Merkle proof + signs the typed data `{account, amount}`.
 *   - User calls `claim(...)` with: account, amount, proof, and signature.
 *   - Contract verifies:
 *       a) not already claimed
 *       b) signature matches account
 *       c) Merkle proof is valid for the published root
 *   - Transfers airdrop tokens to the account and marks as claimed.
 *
 *  Notes:
 *   - Uses `SafeERC20` for safe token transfers.
 *   - EIP-712 domain is set in the constructor via `EIP712("MerkleAirdrop", "1")`.
 */
contract MerkleAirdrop is EIP712 {
    using SafeERC20 for IERC20;

    ////////////////////
    /// ERRORS ///
    ////////////////////
    /// @notice Reverts when the Merkle proof does not validate against the stored root.
    error MerkleAirdrop__InvalidProof();
    /// @notice Reverts when an account tries to claim more than once.
    error MerkleAirdrop__AlreadyClaimed();
    /// @notice Reverts when the provided EIP-712 signature is invalid for the claim.
    error MerkleAirdrop__InvalidSignature();

    //////////////////////////
    /// STATE VARIABLES ///
    //////////////////////////

    /// @notice Optional array tracking claimers (currently unused by contract logic).
    /// @dev Keeping as-is since you asked not to remove existing pieces.
    address[] claimers;

    /// @notice Merkle root representing the allowlist of (account, amount) claims.
    bytes32 private immutable i_merkleRoot;

    /// @notice ERC20 token being distributed via this airdrop.
    IERC20 private immutable i_airdropToken;

    /// @notice Tracks whether an address has already claimed.
    /// @dev `true` means claim has been consumed.
    mapping(address claimer => bool claimed) private s_hashClaimed;

    //////////////////////////
    /// EIP-712 CONSTANTS ///
    //////////////////////////

    /// @notice Typehash for EIP-712 typed data.
    /// @dev Must match the string used off-chain when signing.
    bytes32 private constant MESSAGE_TYPEHASH = keccak256("AirdropClaim(address account, uint256 amount)");

    ////////////////////
    /// STRUCTS ///
    ////////////////////

    /// @notice Typed data struct that is signed by claimants.
    struct AirdropClaim {
        address account;
        uint256 amount;
    }

    ////////////////////
    /// EVENTS ///
    ////////////////////

    /// @notice Emitted after a successful claim.
    event Claim(address account, uint256 amount);

    ////////////////////
    /// CONSTRUCTOR ///
    ////////////////////

    /**
     * @notice Initializes the Merkle airdrop with a Merkle root and ERC20 token address.
     * @dev Sets the EIP-712 domain separator with name "MerkleAirdrop" and version "1".
     *
     * @param _merkleRoot The allowlist Merkle root.
     * @param _airdropToken The ERC20 token to distribute.
     */
    constructor(bytes32 _merkleRoot, IERC20 _airdropToken) EIP712("MerkleAirdrop", "1") {
        i_merkleRoot = _merkleRoot;
        i_airdropToken = _airdropToken;
    }

    //////////////////////////
    /// EXTERNAL FUNCTIONS ///
    //////////////////////////

    /**
     * @notice Claims tokens for an account if it is included in the Merkle tree and the signature is valid.
     * @dev Requirements:
     *  - `_account` has not claimed before
     *  - signature `(v,r,s)` is valid for the EIP-712 digest of `(account, amount)`
     *  - `_merkleProof` is a valid proof for leaf `(account, amount)` under `i_merkleRoot`
     *
     * Effects:
     *  - marks `_account` as claimed
     *  - transfers `_amount` tokens to `_account`
     *  - emits `Claim`
     *
     * @param _account The account receiving tokens (and the address expected to have signed).
     * @param _amount The claimable token amount associated with `_account`.
     * @param _merkleProof Merkle proof showing `(account, amount)` is in the tree.
     * @param v ECDSA signature `v`.
     * @param r ECDSA signature `r`.
     * @param s ECDSA signature `s`.
     */
    function claim(
        address _account,
        uint256 _amount,
        bytes32[] calldata _merkleProof,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        // @dev Prevent double-claims.
        if (s_hashClaimed[_account]) {
            revert MerkleAirdrop__AlreadyClaimed();
        }

        // check the signature
        // the singature is not valid
        // @dev Verify EIP-712 signature proves the caller controls `_account` keys.
        if (!_isValidSignature(_account, getMessageHash(_account, _amount), v, r, s)) {
            revert MerkleAirdrop__InvalidSignature();
        }

        // calculate using the account and the amount, the hash -> leaf node
        // we use double keccak for avoid colissions, its tipical using in merkle arquitecture
        // @dev Compute leaf node exactly as it was built off-chain.
        bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(_account, _amount))));

        // @dev Verify Merkle proof against stored root.
        if (!MerkleProof.verify(_merkleProof, i_merkleRoot, leaf)) {
            revert MerkleAirdrop__InvalidProof();
        }

        // @dev Mark claimed BEFORE transferring tokens to avoid re-claim via re-entrancy patterns.
        s_hashClaimed[_account] = true;

        emit Claim(_account, _amount);

        // @dev Transfer tokens using SafeERC20 to support non-standard ERC20 implementations.
        i_airdropToken.safeTransfer(_account, _amount);
    }

    ////////////////////
    /// VIEW FUNCTIONS ///
    ////////////////////

    /**
     * @notice Returns the EIP-712 digest that the claimant must sign for `(account, amount)`.
     * @dev Uses OpenZeppelin's `_hashTypedDataV4` which includes the domain separator.
     *
     * @param account Account that will claim (and must sign).
     * @param amount Amount being claimed.
     * @return digest The EIP-712 message digest to be signed.
     */
    function getMessageHash(address account, uint256 amount) public view returns (bytes32) {
        return _hashTypedDataV4(
            keccak256(abi.encode(MESSAGE_TYPEHASH, AirdropClaim({account: account, amount: amount})))
        );
    }

    /**
     * @notice Returns the stored Merkle root.
     */
    function getMerkleRoot() external view returns (bytes32) {
        return i_merkleRoot;
    }

    /**
     * @notice Returns the ERC20 token distributed by this airdrop.
     */
    function getAirdropToken() external view returns (IERC20) {
        return i_airdropToken;
    }

    //////////////////////////
    /// INTERNAL FUNCTIONS ///
    //////////////////////////

    /**
     * @notice Validates an EIP-712 signature for a given digest.
     * @dev Uses `ECDSA.tryRecover` to safely recover the signer without reverting.
     *
     * @param account Expected signer address.
     * @param digest EIP-712 digest (output of `getMessageHash`).
     * @param v ECDSA `v`.
     * @param r ECDSA `r`.
     * @param s ECDSA `s`.
     * @return True if recovered signer equals `account`.
     */
    function _isValidSignature(address account, bytes32 digest, uint8 v, bytes32 r, bytes32 s)
        internal
        pure
        returns (bool)
    {
        (address actualSigner,,) = ECDSA.tryRecover(digest, v, r, s);
        return actualSigner == account;
    }
}
