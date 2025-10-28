// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title BookClubDAO
 * @dev Decentralized Book Club with staking, voting, and NFT chapters
 */
contract Project {
    
    // State Variables
    address public owner;
    uint256 public stakingAmount = 0.01 ether;
    uint256 public bookProposalCount;
    uint256 public chapterNFTCount;
    
    struct Member {
        bool isActive;
        uint256 stakedAmount;
        uint256 rewardTokens;
        uint256 joinedAt;
    }
    
    struct BookProposal {
        uint256 id;
        string title;
        string author;
        address proposer;
        uint256 voteCount;
        bool isActive;
    }
    
    struct ChapterNFT {
        uint256 id;
        string bookTitle;
        string chapterTitle;
        address author;
        uint256 price;
        uint256 royaltyPercent; // Author's share (e.g., 70 = 70%)
    }
    
    mapping(address => Member) public members;
    mapping(uint256 => BookProposal) public bookProposals;
    mapping(uint256 => mapping(address => bool)) public hasVoted;
    mapping(uint256 => ChapterNFT) public chapterNFTs;
    mapping(uint256 => mapping(address => bool)) public chapterOwners;
    
    uint256 public treasuryBalance;
    
    // Events
    event MemberJoined(address indexed member, uint256 amount);
    event BookProposed(uint256 indexed proposalId, string title, address proposer);
    event VoteCast(uint256 indexed proposalId, address voter);
    event ChapterMinted(uint256 indexed chapterId, string title, address author);
    event ChapterPurchased(uint256 indexed chapterId, address buyer, uint256 price);
    event RewardGranted(address indexed member, uint256 amount);
    
    modifier onlyMember() {
        require(members[msg.sender].isActive, "Not an active member");
        _;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    // ==================== CORE FUNCTION 1: JOIN BOOK CLUB ====================
    /**
     * @dev Members stake tokens to join the book club
     * @notice Requires sending exactly the staking amount
     */
    function joinBookClub() external payable {
        require(!members[msg.sender].isActive, "Already a member");
        require(msg.value >= stakingAmount, "Insufficient stake");
        
        members[msg.sender] = Member({
            isActive: true,
            stakedAmount: msg.value,
            rewardTokens: 0,
            joinedAt: block.timestamp
        });
        
        emit MemberJoined(msg.sender, msg.value);
    }
    
    // ==================== CORE FUNCTION 2: VOTE ON BOOKS ====================
    /**
     * @dev Propose a new book for the club to read
     */
    function proposeBook(string memory _title, string memory _author) 
        external 
        onlyMember 
        returns (uint256) 
    {
        bookProposalCount++;
        
        bookProposals[bookProposalCount] = BookProposal({
            id: bookProposalCount,
            title: _title,
            author: _author,
            proposer: msg.sender,
            voteCount: 0,
            isActive: true
        });
        
        emit BookProposed(bookProposalCount, _title, msg.sender);
        return bookProposalCount;
    }
    
    /**
     * @dev Vote for a proposed book
     */
    function voteForBook(uint256 _proposalId) external onlyMember {
        require(bookProposals[_proposalId].isActive, "Proposal not active");
        require(!hasVoted[_proposalId][msg.sender], "Already voted");
        
        hasVoted[_proposalId][msg.sender] = true;
        bookProposals[_proposalId].voteCount++;
        
        emit VoteCast(_proposalId, msg.sender);
    }
    
    // ==================== CORE FUNCTION 3: MINT CHAPTER NFTs ====================
    /**
     * @dev Authors mint chapters as NFTs with royalty split
     */
    function mintChapterNFT(
        string memory _bookTitle,
        string memory _chapterTitle,
        uint256 _price,
        uint256 _royaltyPercent
    ) external returns (uint256) {
        require(_royaltyPercent <= 100, "Invalid royalty percentage");
        require(_price > 0, "Price must be positive");
        
        chapterNFTCount++;
        
        chapterNFTs[chapterNFTCount] = ChapterNFT({
            id: chapterNFTCount,
            bookTitle: _bookTitle,
            chapterTitle: _chapterTitle,
            author: msg.sender,
            price: _price,
            royaltyPercent: _royaltyPercent
        });
        
        emit ChapterMinted(chapterNFTCount, _chapterTitle, msg.sender);
        return chapterNFTCount;
    }
    
    /**
     * @dev Members purchase chapter NFTs
     */
    function purchaseChapter(uint256 _chapterId) external payable onlyMember {
        ChapterNFT memory chapter = chapterNFTs[_chapterId];
        require(msg.value >= chapter.price, "Insufficient payment");
        require(!chapterOwners[_chapterId][msg.sender], "Already own this chapter");
        
        // Calculate royalty split
        uint256 authorShare = (msg.value * chapter.royaltyPercent) / 100;
        uint256 daoShare = msg.value - authorShare;
        
        // Transfer royalty to author
        payable(chapter.author).transfer(authorShare);
        
        // Add DAO share to treasury
        treasuryBalance += daoShare;
        
        // Mark ownership
        chapterOwners[_chapterId][msg.sender] = true;
        
        emit ChapterPurchased(_chapterId, msg.sender, msg.value);
    }
    
    // ==================== ADDITIONAL FUNCTIONS ====================
    
    /**
     * @dev Reward active participants with tokens
     */
    function grantReward(address _member, uint256 _amount) external onlyOwner {
        require(members[_member].isActive, "Not an active member");
        members[_member].rewardTokens += _amount;
        emit RewardGranted(_member, _amount);
    }
    
    /**
     * @dev Leave book club and get stake back
     */
    function leaveBookClub() external onlyMember {
        uint256 refund = members[msg.sender].stakedAmount;
        members[msg.sender].isActive = false;
        members[msg.sender].stakedAmount = 0;
        
        payable(msg.sender).transfer(refund);
    }
    
    /**
     * @dev Get member information
     */
    function getMemberInfo(address _member) 
        external 
        view 
        returns (bool, uint256, uint256) 
    {
        Member memory m = members[_member];
        return (m.isActive, m.stakedAmount, m.rewardTokens);
    }
    
    /**
     * @dev Get book proposal details
     */
    function getProposal(uint256 _proposalId) 
        external 
        view 
        returns (string memory, string memory, uint256, bool) 
    {
        BookProposal memory p = bookProposals[_proposalId];
        return (p.title, p.author, p.voteCount, p.isActive);
    }
    
    /**
     * @dev Check if user owns a specific chapter
     */
    function ownsChapter(uint256 _chapterId, address _user) 
        external 
        view 
        returns (bool) 
    {
        return chapterOwners[_chapterId][_user];
    }
}
