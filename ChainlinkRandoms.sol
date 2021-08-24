pragma solidity ^0.6.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@chainlink/contracts/src/v0.6/VRFConsumerBase.sol";
import "./interfaces/IRandoms.sol";

struct SeedState {
    bytes32 requestId;
    uint256 seed;
    bool isAvailable;
}

contract ChainlinkRandoms is IRandoms, Pausable, AccessControl, VRFConsumerBase {
    using SafeERC20 for IERC20;

    uint256 constant VRF_MAGIC_SEED = uint256(keccak256("PolyBlades"));

    bytes32 public constant RANDOMNESS_REQUESTER = keccak256("RANDOMNESS_REQUESTER");

    bytes32 private keyHash;
    uint256 private fee;

    uint256 private seed;

    

    constructor(address _vrfCoordinator, address _link, bytes32 _keyHash, uint256 _fee)
        VRFConsumerBase(
            _vrfCoordinator, // VRF Coordinator
            _link  // LINK Token
        ) public
    {
        keyHash = _keyHash;
        fee = _fee;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    // Views
    function getRandomSeed(address user) external override view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(user, seed, blockhash(block.number - 1))));
    }

    // Mutative

    /**
     * Requests randomness from a user-provided seed
     */
    function requestRandomNumber() external whenNotPaused {
        require(hasRole(RANDOMNESS_REQUESTER, msg.sender), "Sender cannot request seed");
        require(LINK.balanceOf(address(this)) >= fee, "Not enough LINK");

        // the user-provided seed is not necessary, as per the docs
        // hence we set it to an arbitrary constant
        requestRandomness(keyHash, fee, VRF_MAGIC_SEED);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * Callback function used by VRF Coordinator
     */
    function fulfillRandomness(bytes32 /* requestId */, uint256 randomness) internal override {
        seed = randomness;
    }

    function withdrawLink(uint256 tokenAmount) external onlyOwner {
        // very awkward - but should be safe given that the LINK token is ERC20-compatible
        IERC20(address(LINK)).safeTransfer(msg.sender, tokenAmount);
    }

    // Modifiers
    modifier onlyOwner() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Not admin");
        _;
    }
}
