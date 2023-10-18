// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import { IUUPS } from "../../lib/interfaces/IUUPS.sol";
import { IERC721Votes } from "../../lib/interfaces/IERC721Votes.sol";
import { IManager } from "../../manager/IManager.sol";
import { IMirrorToken } from "../interfaces/IMirrorToken.sol";
import { PartialMirrorTokenTypesV1 } from "./types/PartialMirrorTokenTypesV1.sol";

/// @title IToken
/// @author Neokry
/// @notice The external Token events, errors and functions
interface IPartialMirrorToken is IUUPS, IERC721Votes, IMirrorToken, PartialMirrorTokenTypesV1 {
    ///                                                          ///
    ///                            EVENTS                        ///
    ///                                                          ///

    /// @notice Emitted when a token is scheduled to be allocated
    /// @param baseTokenId The
    /// @param founderId The founder's id
    /// @param founder The founder's vesting details
    event MintScheduled(uint256 baseTokenId, uint256 founderId, Founder founder);

    /// @notice Emitted when a token allocation is unscheduled (removed)
    /// @param baseTokenId The token ID % 100
    /// @param founderId The founder's id
    /// @param founder The founder's vesting details
    event MintUnscheduled(uint256 baseTokenId, uint256 founderId, Founder founder);

    /// @notice Emitted when a tokens founders are deleted from storage
    /// @param newFounders the list of founders
    event FounderAllocationsCleared(IManager.FounderParams[] newFounders);

    /// @notice Emitted when minters are updated
    /// @param minter Address of added or removed minter
    /// @param allowed Whether address is allowed to mint
    event MinterUpdated(address minter, bool allowed);

    ///                                                          ///
    ///                            ERRORS                        ///
    ///                                                          ///

    /// @dev Reverts if the founder ownership exceeds 100 percent
    error INVALID_FOUNDER_OWNERSHIP();

    /// @dev Reverts if the caller was not the auction contract
    error ONLY_AUCTION();

    /// @dev Reverts if the caller was not a minter
    error ONLY_AUCTION_OR_MINTER();

    /// @dev Reverts if the caller was not the token owner
    error ONLY_TOKEN_OWNER();

    /// @dev Reverts if no metadata was generated upon mint
    error NO_METADATA_GENERATED();

    /// @dev Reverts if the caller was not the contract manager
    error ONLY_MANAGER();

    /// @dev Reverts if the token is not reserved
    error TOKEN_NOT_RESERVED();

    /// @dev Reverts if the token is already mirrored
    error ALREADY_MIRRORED();

    /// @dev Reverts if an approval function for a reserved token has been called
    error NO_APPROVALS();

    ///                                                          ///
    ///                           FUNCTIONS                      ///
    ///                                                          ///

    /// @notice Initializes a DAO's ERC-721 token contract
    /// @param founders The DAO founders
    /// @param initStrings The encoded token and metadata initialization strings
    /// @param reservedUntilTokenId The tokenId that a DAO's auctions will start at
    /// @param metadataRenderer The token's metadata renderer
    /// @param auction The token's auction house
    /// @param initialOwner The initial owner of the token
    function initialize(
        IManager.FounderParams[] calldata founders,
        bytes calldata initStrings,
        uint256 reservedUntilTokenId,
        address tokenToMirror,
        address metadataRenderer,
        address auction,
        address initialOwner
    ) external;

    /// @notice Mirrors the ownership of a given tokenId from the mirrored token
    /// @param _tokenId The ERC-721 token to mirror
    function mirror(uint256 _tokenId) external;

    /// @notice The number of founders
    function totalFounders() external view returns (uint256);

    /// @notice The founders total percent ownership
    function totalFounderOwnership() external view returns (uint256);

    /// @notice The vesting details of a founder
    /// @param founderId The founder id
    function getFounder(uint256 founderId) external view returns (Founder memory);

    /// @notice The vesting details of all founders
    function getFounders() external view returns (Founder[] memory);

    /// @notice Update the list of allocation owners
    /// @param newFounders the full list of FounderParam structs
    function updateFounders(IManager.FounderParams[] calldata newFounders) external;

    /// @notice The founder scheduled to receive the given token id
    /// NOTE: If a founder is returned, there's no guarantee they'll receive the token as vesting expiration is not considered
    /// @param tokenId The ERC-721 token id
    function getScheduledRecipient(uint256 tokenId) external view returns (Founder memory);

    /// @notice Update minters
    /// @param _minters Array of structs containing address status as a minter
    function updateMinters(MinterParams[] calldata _minters) external;

    /// @notice Check if an address is a minter
    /// @param _minter Address to check
    function isMinter(address _minter) external view returns (bool);

    /// @notice Callback called by auction on first auction started to transfer ownership to treasury from founder
    function onFirstAuctionStarted() external;
}
