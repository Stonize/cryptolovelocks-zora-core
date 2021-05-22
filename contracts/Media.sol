// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.6.8;
pragma experimental ABIEncoderV2;

import {ERC721Burnable} from "./ERC721Burnable.sol";
import {ERC721} from "./ERC721.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/EnumerableSet.sol";
import {Counters} from "@openzeppelin/contracts/utils/Counters.sol";
import {SafeMath} from "@openzeppelin/contracts/math/SafeMath.sol";
import {Math} from "@openzeppelin/contracts/math/Math.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    ReentrancyGuard
} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Decimal} from "./Decimal.sol";
import {IMarket} from "./IMarket.sol";
import "./IMedia.sol";

/**
 * @title A media value system, with perpetual equity to creators
 * @notice This contract provides an interface to mint media with a market
 * owned by the creator.
 */
contract Media is IMedia, ERC721Burnable, ReentrancyGuard {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    // mapping(address => mapping(uint256 => bool)) canSetMessage_;

    event CurrentPriceChanged(
        uint256 _currentPrice        
    );

    event SetMessage(
        address indexed _from,
        uint256 _token,
        string _msg
    );

    modifier isOwner(uint256 tokenId) {
        address owner = ownerOf(tokenId);
        require(
            tokenContentHashes[tokenId] != 0,
            "Media: token does not have hash of created content"
        );
        _;
    }

    /* *******
     * Globals
     * *******
     */
    EnumerableSet.UintSet private reserved;

    uint256 public constant TOTAL_SUPPLY = 10380;

    uint256 public constant STONIZE_RESERVED = 1089;

    // Address for the market
    address public marketContract;

    address public developer;

    // Current price for Cryptolovelock
    uint256 public crytolovelockPrice;

    // Flag for each token: when true the owner can set the message
    // We reset this flag when token is transferred 
    mapping(uint256 => bool) public _canSetMessage;

    // Mapping from token to previous owner of the token
    mapping(uint256 => address) public previousTokenOwners;

    // Mapping from token id to creator address
    mapping(uint256 => address) public tokenCreators;

    // Mapping from creator address to their (enumerable) set of created tokens
    mapping(address => EnumerableSet.UintSet) private _creatorTokens;

    // Mapping from token id to sha256 hash of content
    mapping(uint256 => bytes32) public tokenContentHashes;

    // Mapping from token id to sha256 hash of metadata
    mapping(uint256 => bytes32) public tokenMetadataHashes;

    // Mapping from token id to metadataURI
    mapping(uint256 => string) private _tokenMetadataURIs;

    // Mapping from contentHash to bool
    mapping(bytes32 => bool) private _contentHashes;

    //keccak256("Permit(address spender,uint256 tokenId,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH =
        0x49ecf333e5b8c95c40fdafc95c1ad136e8914a8fb55e9dc8bb01eaa83a2df9ad;

    //keccak256("MintWithSig(bytes32 contentHash,bytes32 metadataHash,uint256 creatorShare,uint256 nonce,uint256 deadline)");
    bytes32 public constant MINT_WITH_SIG_TYPEHASH =
        0x2952e482b8e2b192305f87374d7af45dc2eafafe4f50d26a0c02e90f2fdbe14b;

    // Mapping from address to token id to permit nonce
    mapping(address => mapping(uint256 => uint256)) public permitNonces;

    // Mapping from address to mint with sig nonce
    mapping(address => uint256) public mintWithSigNonces;

    /*
     *     bytes4(keccak256('name()')) == 0x06fdde03
     *     bytes4(keccak256('symbol()')) == 0x95d89b41
     *     bytes4(keccak256('tokenURI(uint256)')) == 0xc87b56dd
     *     bytes4(keccak256('tokenMetadataURI(uint256)')) == 0x157c3df9
     *
     *     => 0x06fdde03 ^ 0x95d89b41 ^ 0xc87b56dd ^ 0x157c3df9 == 0x4e222e66
     */
    bytes4 private constant _INTERFACE_ID_ERC721_METADATA = 0x4e222e66;

    // Counters.Counter private _tokenIdTracker;

    /* *********
     * Modifiers
     * *********
     */

    modifier onlyDeveloper() {
        require(developer == msg.sender, "Media: only developer");
        _;
    }

    /**
     * @notice Require that the token has not been burned and has been minted
     */
    modifier onlyExistingToken(uint256 tokenId) {
        require(_exists(tokenId), "Media: nonexistent token");
        _;
    }

    /**
     * @notice Require that the token has had a content hash set
     */
    modifier onlyTokenWithContentHash(uint256 tokenId) {
        require(
            tokenContentHashes[tokenId] != 0,
            "Media: token does not have hash of created content"
        );
        _;
    }

    /**
     * @notice Require that the token has had a metadata hash set
     */
    modifier onlyTokenWithMetadataHash(uint256 tokenId) {
        require(
            tokenMetadataHashes[tokenId] != 0,
            "Media: token does not have hash of its metadata"
        );
        _;
    }

    /**
     * @notice Ensure that the provided spender is the approved or the owner of
     * the media for the specified tokenId
     */
    modifier onlyApprovedOrOwner(address spender, uint256 tokenId) {
        require(
            _isApprovedOrOwner(spender, tokenId),
            "Media: Only approved or owner"
        );
        _;
    }

    /**
     * @notice Ensure the token has been created (even if it has been burned)
     */
    modifier onlyTokenCreated(uint256 tokenId) {
        require (tokenCreators[tokenId] != address(0x0), "Media: token with that id does not exist");
        /*
        require(
            _tokenIdTracker.current() > tokenId,
            "Media: token with that id does not exist"
        );
        */
        _;
    }

    /**
     * @notice Ensure that the provided URI is not empty
     */
    modifier onlyValidURI(string memory uri) {
        require(
            bytes(uri).length != 0,
            "Media: specified uri must be non-empty"
        );
        _;
    }

    /**
     * @notice On deployment, set the market contract address and register the
     * ERC721 metadata interface
     */
    constructor(address marketContractAddr, uint256 _crytolovelockPrice, address _developer) public ERC721("Cryptolovelock", "LOVE") {
        marketContract = marketContractAddr;
        crytolovelockPrice = _crytolovelockPrice;
        developer = _developer;
        _registerInterface(_INTERFACE_ID_ERC721_METADATA);

        uint16[1089] memory _reserved = [2670,8207,10017,9299,9444,3770,7574,2957,7853,5632,3279,55,9086,7816,2988,6325,8787,5922,6700,9830,8022,1433,7883,1223,6015,5958,1956,7905,6094,8165,8253,3604,6634,4882,3729,8544,879,187,3837,1448,3922,9644,10374,103,8201,1262,91,7538,9672,9918,8988,2716,9474,8040,6759,1810,2174,8244,5158,6397,9303,10794,6437,8876,1522,3991,6220,5106,4094,7730,4603,9460,6465,10265,5403,231,10353,8065,7255,5234,5408,1745,792,3908,6127,3451,1512,1904,8681,4587,9421,6607,5340,9532,242,5664,10224,5655,7654,7441,9725,8085,3983,772,3643,10197,2863,3841,6296,1486,10769,97,9483,779,8466,10861,5243,7302,10247,554,9410,9714,5488,5947,9328,4837,7345,7827,5483,4243,9560,9476,8020,10879,5841,9840,8534,5915,8831,1249,3448,2105,6669,9279,6645,3320,8448,324,7725,3888,6676,1048,6105,9031,442,4128,6725,10532,503,6222,8663,666,3712,8458,905,3020,2100,1293,1500,3152,1806,130,4906,239,102,1013,8664,9687,4514,3319,6459,3144,3703,7673,6111,1105,7942,6846,4774,3244,10310,4745,6140,3366,6383,1568,6967,98,1268,3825,1573,5453,2731,7900,1224,4510,9800,3408,5484,712,3510,10788,10676,1146,1171,662,2941,7596,1052,6177,185,2842,6635,6341,4921,3449,4336,3903,6401,3392,1728,6550,9293,6442,8353,6167,8942,842,3512,4720,3848,5206,3332,7571,5009,649,5008,1389,9561,2685,9517,3694,2220,9235,741,6649,10060,140,7312,2954,6754,6299,2642,9194,5161,8291,5697,7688,4797,7715,10476,2182,8884,10242,6933,7916,1164,3311,7333,7895,3623,4372,1271,6900,3639,4754,4244,5311,224,8268,10457,2917,1091,2615,8313,3975,682,613,4662,5465,2675,3133,6276,2661,6982,3901,9437,7903,9480,3157,9924,7059,7988,6767,2904,5249,2774,6829,492,714,10439,7874,339,5617,764,4184,3976,4614,7116,3658,6387,6332,9812,10822,1704,5388,2072,7266,4237,253,4970,10003,9315,7639,10328,3480,9626,1595,9612,8821,5634,6233,9240,1303,8036,6772,4430,2761,9859,8904,5746,967,3977,2309,7936,1427,8102,5844,10420,762,2129,3914,2004,6393,5128,6818,5222,7168,42,821,10627,7211,8409,7123,2614,9000,6083,7111,2949,8157,7438,3250,8134,3620,578,5705,10061,5882,7356,1373,9087,7292,8665,1326,2995,10491,1869,6313,9692,6861,10527,3120,8748,2120,1735,2034,5282,262,9998,3446,7114,2759,10117,10118,6891,3016,2986,10813,7355,370,10168,1975,1895,9728,5831,7078,9267,4598,3666,1547,1780,1204,4211,9631,5259,8143,157,6750,4819,2277,1525,4809,2069,7458,2194,6364,5774,8708,3996,9229,5588,6191,6302,10014,5438,5352,2788,5478,4773,2639,9181,6008,8401,7048,9488,7539,8161,4364,4015,9994,9092,4680,5439,9990,6395,9505,6049,8332,1189,691,1020,2665,1955,8605,10551,9559,9159,5482,8086,10634,10564,9828,7125,3390,3503,4167,2317,4460,8367,7081,4490,8473,7021,3684,2722,3054,2196,3091,7245,6666,8400,2275,8961,8820,4020,1265,5093,8266,9127,6748,7030,7374,6240,10229,2273,767,10317,10646,5850,4417,6269,9957,7643,8519,2741,7750,2474,4204,1274,6646,4072,4952,673,7525,6780,5217,3890,3601,6826,4303,7946,261,7670,4335,1934,1746,2746,4465,10368,7159,1483,6321,1023,2764,7260,1086,10179,5590,10674,10407,10827,3043,6742,8152,8196,5064,1320,10716,4764,8656,4262,5228,1808,220,1847,1040,1047,283,6454,10319,316,5205,7859,5538,8721,361,336,5933,2178,5859,331,6972,5303,9538,197,5624,10175,6027,8906,416,3049,2012,2408,4785,10681,9214,4909,164,4218,4476,2777,755,10857,4337,4272,8363,10607,8893,10337,7943,7776,2229,7519,9825,9836,200,5152,10100,10390,2432,6444,3341,6868,2433,2427,10057,575,707,4612,6272,2334,6050,9369,7034,9742,5954,4481,9634,510,3284,415,6230,10358,5450,6195,643,1382,10699,1181,4719,2445,9619,8826,5575,5032,5407,4176,4441,1796,1387,1701,60,6638,9101,606,9407,1018,6789,5191,10584,1297,9693,3182,5113,3237,1151,499,10173,1831,9760,4891,4178,6799,9260,4104,3203,7487,1034,661,1502,10621,8958,8640,3773,2468,8369,6192,2983,7739,7271,5239,9885,8759,9752,884,10645,9463,7370,820,10007,2562,4516,1678,4450,4423,10712,8662,3455,3357,2512,10436,8753,1961,1247,1212,2684,7040,2368,9539,2063,6927,440,1918,5444,9103,3815,9040,5830,111,7188,9892,4304,6534,1938,8803,7431,9317,4482,4666,4376,7826,5626,10619,7384,4601,2213,2384,2889,3068,6739,2516,3413,4824,3165,9779,3521,237,6079,5121,844,5013,8711,10884,2186,8357,8063,1843,2240,882,10434,10387,5070,3723,2331,1215,4331,6205,10625,10714,6655,6978,4011,207,8421,3772,406,36,5345,10155,1688,4498,1947,9085,6740,6640,7050,1971,8492,10651,10329,1520,6320,2190,8923,3310,4661,6095,529,482,1786,7570,9843,3174,8642,2095,6368,304,8398,2379,9029,9669,2631,6953,8864,4676,5907,2228,10186,10393,10811,5168,1601,3094,173,9219,10072,3291,1187,4725,9462,5683,3552,7286,9596,10081,8477,7426,1437,1634,7405,1660,64,8081,9780,6965,6021,9536,4345,6092,3719,9567,9917,10266,2596,6283,7080,4789,5973,9978,5313,8967,1622,7930,6062,10801,8351,598,9324,2232,10522,2392,2493,4793,1073,7854,9516,8261,10049,80,3208,9820,5965,10198,9366,2244,10359,1186,7490,8647,4571,400,301,203,5475,7577,2026,8461,1077,1792,6942,7352,6456,3705,6301,2733,6990,10211,8597,2279,9417,2973,2483,9264,9445,6986,10864,1152,2311,10797,4848,7452,5409,2444,1552,7979,6425,65,9896,536,5828,4814,3560,7140,4864,6879,8628,5855,8952,8916,7351,4034,1556,689,3312,10559,4593,3025,3356,7288,8933,9708,2858,6213,6481,3490,6952,8016,7980,686,3791,4851,4999,2698,332,7228,7027,1592,676,7589,10193,8754,10206,4964,10535,7891,5236,6582,3755,7866,2880,10578,10418,6793,5346,3850,4937,87,2802,2786,8365,4071,2911,10215,8578,3239,8504,7633,9209,10244,9956,1201,5503,8034,2339,1366,9110,10454,3700,201,6929,717,9801,4379,5284,2710,9228,826,1350,7404,10717,9361,10332,7728,582,10829,2805,1322,7024,2176,5377,6427,10132,1833,8030,1043,3953,8139,5086,5226];
        for (uint16 i = 0; i < 1089; i ++) {
            EnumerableSet.add(reserved, _reserved[i]);
        }

    }

    /* **************
     * View Functions
     * **************
     */

    function initialBidShares() public pure returns (IMarket.BidShares memory) {
        return IMarket.BidShares({
            creator: Decimal.D256(5 * Decimal.BASE),
            prevOwner: Decimal.D256(0),
            owner: Decimal.D256(95 * Decimal.BASE)
        });
    }

    function currentPrice() public view returns (uint256) {
        return crytolovelockPrice;
    }

    function setCurrentPrice(uint256 _crytolovelockPrice) public {
        crytolovelockPrice = _crytolovelockPrice;
        emit CurrentPriceChanged(_crytolovelockPrice);
    }

    /**
     * @notice return the URI for a particular piece of media with the specified tokenId
     * @dev This function is an override of the base OZ implementation because we
     * will return the tokenURI even if the media has been burned. In addition, this
     * protocol does not support a base URI, so relevant conditionals are removed.
     * @return the URI for a token
     */
    function tokenURI(uint256 tokenId)
        public
        view
        override
        onlyTokenCreated(tokenId)
        returns (string memory)
    {
        string memory _tokenURI = _tokenURIs[tokenId];

        return _tokenURI;
    }

    /**
     * @notice Return the metadata URI for a piece of media given the token URI
     * @return the metadata URI for the token
     */
    function tokenMetadataURI(uint256 tokenId)
        external
        view
        override
        onlyTokenCreated(tokenId)
        returns (string memory)
    {
        return _tokenMetadataURIs[tokenId];
    }

    /* ****************
     * Public Functions
     * ****************
     */

    /**
     * Set your love message
     */
    function setLoveMessage(uint256 _tokenId, string memory _msg) public {
        require(ownerOf(_tokenId) == msg.sender, "Cryptolovelock: Only owner can set love note");        
        require(_canSetMessage[_tokenId], "Cryptolovelock: You already chosen your love note");
        _canSetMessage[_tokenId] = false;
        emit SetMessage(msg.sender, _tokenId, _msg);
    }

    /**
     * @notice see IMedia
     */
    function mint(uint256 tokenId, MediaData memory data)
        public
        override
        payable
        nonReentrant
    {
        require(msg.value >= crytolovelockPrice, "Media: price not payed");
        require((msg.sender == developer && tokenId < STONIZE_RESERVED) || (tokenId >= STONIZE_RESERVED), "Cryptolovelocks: this token was reserved by STONIZE");
        address payable _developer = payable(developer);
        _mintForCreator(tokenId, msg.sender, data, initialBidShares());
        _developer.transfer(msg.value);
    }

    /**
     * @notice see IMedia
     */
    function mintWithSig(
        uint256 tokenId,
        address creator,
        MediaData memory data,
        EIP712Signature memory sig
    ) public override payable nonReentrant {

        /*
        IMarket.BidShares memory bidShares = IMarket.BidShares({
            creator: Decimal.D256(5), 
            prevOwner: Decimal.D256(0),
            owner: Decimal.D256(95)
        });
        */

        require(
            sig.deadline == 0 || sig.deadline >= block.timestamp,
            "Media: mintWithSig expired"
        );

        bytes32 domainSeparator = _calculateDomainSeparator();

        bytes32 digest =
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    domainSeparator,
                    keccak256(
                        abi.encode(
                            MINT_WITH_SIG_TYPEHASH,
                            data.contentHash,
                            data.metadataHash,
                            initialBidShares().creator.value,
                            mintWithSigNonces[creator]++,
                            sig.deadline
                        )
                    )
                )
            );

        address recoveredAddress = ecrecover(digest, sig.v, sig.r, sig.s);

        require(
            recoveredAddress != address(0) && creator == recoveredAddress,
            "Media: Signature invalid"
        );

        require(msg.value >= crytolovelockPrice, "Media: price not payed");
        address payable _developer = payable(developer);
        _mintForCreator(tokenId, recoveredAddress, data, initialBidShares());
        _developer.transfer(msg.value);
    }

    /**
     * @notice see IMedia
     */
    function auctionTransfer(uint256 tokenId, address recipient)
        external
        override
    {
        require(msg.sender == marketContract, "Media: only market contract");
        previousTokenOwners[tokenId] = ownerOf(tokenId);
        _safeTransfer(ownerOf(tokenId), recipient, tokenId, "");
    }

    /**
     * @notice see IMedia
     */
    function setAsk(uint256 tokenId, IMarket.Ask memory ask)
        public
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        IMarket(marketContract).setAsk(tokenId, ask);
    }

    /**
     * @notice see IMedia
     */
    function removeAsk(uint256 tokenId)
        external
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        IMarket(marketContract).removeAsk(tokenId);
    }

    /**
     * @notice see IMedia
     */
    function setBid(uint256 tokenId, IMarket.Bid memory bid)
        public
        override
        nonReentrant
        onlyExistingToken(tokenId)
    {
        require(msg.sender == bid.bidder, "Market: Bidder must be msg sender");
        IMarket(marketContract).setBid(tokenId, bid, msg.sender);
    }

    /**
     * @notice see IMedia
     */
    function removeBid(uint256 tokenId)
        external
        override
        nonReentrant
        onlyTokenCreated(tokenId)
    {
        IMarket(marketContract).removeBid(tokenId, msg.sender);
    }

    /**
     * @notice see IMedia
     */
    function acceptBid(uint256 tokenId, IMarket.Bid memory bid)
        public
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        IMarket(marketContract).acceptBid(tokenId, bid);
    }

    /**
     * @notice Burn a token.
     * @dev Only callable if the media owner is also the creator.
     */
    function burn(uint256 tokenId)
        public
        override
        nonReentrant
        onlyExistingToken(tokenId)
        onlyApprovedOrOwner(msg.sender, tokenId)
    {
        address owner = ownerOf(tokenId);

        require(
            tokenCreators[tokenId] == owner,
            "Media: owner is not creator of media"
        );

        _burn(tokenId);
    }

    /**
     * @notice Revoke the approvals for a token. The provided `approve` function is not sufficient
     * for this protocol, as it does not allow an approved address to revoke it's own approval.
     * In instances where a 3rd party is interacting on a user's behalf via `permit`, they should
     * revoke their approval once their task is complete as a best practice.
     */
    function revokeApproval(uint256 tokenId) external override nonReentrant {
        require(
            msg.sender == getApproved(tokenId),
            "Media: caller not approved address"
        );
        _approve(address(0), tokenId);
    }

    /**
     * @notice see IMedia
     * @dev only callable by approved or owner
     */
    function updateTokenURI(uint256 tokenId, string calldata _tokenURI)
        external
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
        onlyTokenWithContentHash(tokenId)
        onlyValidURI(_tokenURI)
    {
        _setTokenURI(tokenId, _tokenURI);
        emit TokenURIUpdated(tokenId, msg.sender, _tokenURI);
    }

    /**
     * @notice see IMedia
     * @dev only callable by approved or owner
     */
    function updateTokenMetadataURI(
        uint256 tokenId,
        string calldata metadataURI
    )
        external
        override
        nonReentrant
        onlyApprovedOrOwner(msg.sender, tokenId)
        onlyTokenWithMetadataHash(tokenId)
        onlyValidURI(metadataURI)
    {
        _setTokenMetadataURI(tokenId, metadataURI);
        emit TokenMetadataURIUpdated(tokenId, msg.sender, metadataURI);
    }

    /**
     * @notice See IMedia
     * @dev This method is loosely based on the permit for ERC-20 tokens in  EIP-2612, but modified
     * for ERC-721.
     */
    function permit(
        address spender,
        uint256 tokenId,
        EIP712Signature memory sig
    ) public override nonReentrant onlyExistingToken(tokenId) {
        require(
            sig.deadline == 0 || sig.deadline >= block.timestamp,
            "Media: Permit expired"
        );
        require(spender != address(0), "Media: spender cannot be 0x0");
        bytes32 domainSeparator = _calculateDomainSeparator();

        bytes32 digest =
            keccak256(
                abi.encodePacked(
                    "\x19\x01",
                    domainSeparator,
                    keccak256(
                        abi.encode(
                            PERMIT_TYPEHASH,
                            spender,
                            tokenId,
                            permitNonces[ownerOf(tokenId)][tokenId]++,
                            sig.deadline
                        )
                    )
                )
            );

        address recoveredAddress = ecrecover(digest, sig.v, sig.r, sig.s);

        require(
            recoveredAddress != address(0) &&
                ownerOf(tokenId) == recoveredAddress,
            "Media: Signature invalid"
        );

        _approve(spender, tokenId);
    }

    /* *****************
     * Private Functions
     * *****************
     */

    /**
     * @notice Creates a new token for `creator`. Its token ID will be automatically
     * assigned (and available on the emitted {IERC721-Transfer} event), and the token
     * URI autogenerated based on the base URI passed at construction.
     *
     * See {ERC721-_safeMint}.
     *
     * On mint, also set the sha256 hashes of the content and its metadata for integrity
     * checks, along with the initial URIs to point to the content and metadata. Attribute
     * the token ID to the creator, mark the content hash as used, and set the bid shares for
     * the media's market.
     *
     * Note that although the content hash must be unique for future mints to prevent duplicate media,
     * metadata has no such requirement.
     */
    function _mintForCreator(
        uint256 tokenId,
        address creator,
        MediaData memory data,
        IMarket.BidShares memory bidShares
    ) internal onlyValidURI(data.tokenURI) onlyValidURI(data.metadataURI) {
        require(data.contentHash != 0, "Media: content hash must be non-zero");
        require(EnumerableSet.contains(reserved, tokenId) && creator == developer, "Media: this token is left for future sales");
        require(!EnumerableSet.contains(reserved, tokenId) && creator != developer, "Media: this token is left for future sales");
        require(
            _contentHashes[data.contentHash] == false,
            "Media: a token has already been created with this content hash"
        );
        require(
            data.metadataHash != 0,
            "Media: metadata hash must be non-zero"
        );
        require(!_exists(tokenId), "Media: token already exists");

        // uint256 tokenId = _tokenIdTracker.current();

        require(tokenId < TOTAL_SUPPLY, "Media: max supply reached");

        _safeMint(creator, tokenId);
        // _tokenIdTracker.increment();
        _setTokenContentHash(tokenId, data.contentHash);
        _setTokenMetadataHash(tokenId, data.metadataHash);
        _setTokenMetadataURI(tokenId, data.metadataURI);
        _setTokenURI(tokenId, data.tokenURI);
        _canSetMessage[tokenId] = true;
        _creatorTokens[creator].add(tokenId);
        _contentHashes[data.contentHash] = true;

        tokenCreators[tokenId] = creator;
        previousTokenOwners[tokenId] = creator;
        IMarket(marketContract).setBidShares(tokenId, bidShares);
    }

    function _setTokenContentHash(uint256 tokenId, bytes32 contentHash)
        internal
        virtual
        onlyExistingToken(tokenId)
    {
        tokenContentHashes[tokenId] = contentHash;
    }

    function _setTokenMetadataHash(uint256 tokenId, bytes32 metadataHash)
        internal
        virtual
        onlyExistingToken(tokenId)
    {
        tokenMetadataHashes[tokenId] = metadataHash;
    }

    function _setTokenMetadataURI(uint256 tokenId, string memory metadataURI)
        internal
        virtual
        onlyExistingToken(tokenId)
    {
        _tokenMetadataURIs[tokenId] = metadataURI;
    }

    /**
     * @notice Destroys `tokenId`.
     * @dev We modify the OZ _burn implementation to
     * maintain metadata and to remove the
     * previous token owner from the piece
     */
    function _burn(uint256 tokenId) internal override {
        string memory _tokenURI = _tokenURIs[tokenId];

        super._burn(tokenId);

        if (bytes(_tokenURI).length != 0) {
            _tokenURIs[tokenId] = _tokenURI;
        }

        delete previousTokenOwners[tokenId];
    }

    /**
     * @notice transfer a token and remove the ask for it.
     */
    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override {
        IMarket(marketContract).removeAsk(tokenId);
        _canSetMessage[tokenId] = true;
        super._transfer(from, to, tokenId);
    }

    /**
     * @dev Calculates EIP712 DOMAIN_SEPARATOR based on the current contract and chain ID.
     */
    function _calculateDomainSeparator() internal view returns (bytes32) {
        uint256 chainID;
        /* solium-disable-next-line */
        assembly {
            chainID := chainid()
        }

        return
            keccak256(
                abi.encode(
                    keccak256(
                        "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                    ),
                    keccak256(bytes("Zora")),
                    keccak256(bytes("1")),
                    chainID,
                    address(this)
                )
            );
    }
}
